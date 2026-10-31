#include "account.h"

#include <QBuffer>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>
#include <algorithm>

#include "backend_config.h"
#include "playlists.h"

namespace {

QString isoUtc(qint64 ms) { return QDateTime::fromMSecsSinceEpoch(ms).toUTC().toString(Qt::ISODate); }

qint64 parseIso(const QString &s)
{
    QString t = s;
    t.remove(QRegularExpression(QStringLiteral("\\.\\d+")));
    return QDateTime::fromString(t, Qt::ISODate).toMSecsSinceEpoch();
}

QString apiError(const QJsonDocument &d, int status)
{
    const QJsonObject o = d.object();
    for (const char *k : {"msg", "message", "error_description", "error"}) {
        const QString s = o.value(QLatin1String(k)).toString();
        if (!s.isEmpty()) return s;
    }
    return status == 0 ? QStringLiteral("Can't reach the server. Check your connection.")
                       : QStringLiteral("Something went wrong (code %1).").arg(status);
}

bool validUsername(const QString &u)
{
    static const QRegularExpression re(QStringLiteral("^[a-z0-9_]{3,20}$"));
    return re.match(u).hasMatch();
}

QString friendly(const QString &raw, bool signingUp)
{
    const QString r = raw.toLower();
    if (r.contains("already registered") || r.contains("already been registered")) return QStringLiteral("That username is taken.");
    if (r.contains("invalid login")) return QStringLiteral("Wrong username or password.");
    if (signingUp && (r.contains("database error") || r.contains("violates")))
        return QStringLiteral("That username can't be used. Use 3 to 20 letters, numbers or _ (some names are reserved).");
    if (r.contains("rate limit")) return QStringLiteral("Too many tries. Wait a few minutes and try again.");
    return raw;
}

constexpr qint64 kMaxPickBytes = 40LL * 1024 * 1024;   // don't even open anything bigger
constexpr qint64 kAvatarMax = 1900LL * 1024;             // bucket limit is 2 MB
constexpr qint64 kBannerMax = 3LL * 1024 * 1024;         // bucket limit is 3 MB
constexpr int kGifMaxW = 1200, kGifMaxH = 600;

// A pasted path can come with quotes, a file:// prefix or a leading ~.
QString cleanPath(QString s)
{
    s = s.trimmed();
    if (s.size() >= 2 && ((s.startsWith(QLatin1Char('"')) && s.endsWith(QLatin1Char('"')))
                          || (s.startsWith(QLatin1Char('\'')) && s.endsWith(QLatin1Char('\''))))) s = s.mid(1, s.size() - 2).trimmed();
    if (s.startsWith(QLatin1String("file://"))) s = QUrl(s).toLocalFile();
    else if (s == QLatin1String("~") || s.startsWith(QLatin1String("~/"))) s = QDir::homePath() + s.mid(1);
    return s;
}

QImage readPicture(const QString &path)
{
    QImageReader rd(path);
    rd.setAutoTransform(true);
    const QSize sz = rd.size();
    if (sz.isValid()) {
        if (sz.width() > 12000 || sz.height() > 12000) return QImage();          // absurdly large
        if (sz.width() > 3000 || sz.height() > 3000) rd.setScaledSize(sz.scaled(3000, 3000, Qt::KeepAspectRatio));
    }
    return rd.read();
}

// JPEG (PNG if the picture has transparency), shrunk step by step until it fits under `limit`.
bool encodePicture(QImage img, qint64 limit, QByteArray &out, QByteArray &mime, QString &ext)
{
    for (int attempt = 0; attempt < 6; ++attempt) {
        const QList<QByteArray> formats = img.hasAlphaChannel() ? QList<QByteArray>{"PNG"} : QList<QByteArray>{"JPEG", "PNG"};
        for (const QByteArray &f : formats) {
            QByteArray data;
            QBuffer buf(&data);
            buf.open(QIODevice::WriteOnly);
            if (!img.save(&buf, f.constData(), f == "JPEG" ? 86 : -1)) continue;   // plugin missing: try the next
            if (data.size() <= limit) {
                out = data;
                mime = f == "JPEG" ? QByteArray("image/jpeg") : QByteArray("image/png");
                ext = f == "JPEG" ? QStringLiteral("jpg") : QStringLiteral("png");
                return true;
            }
            break;                                                                  // saved, but too big: shrink
        }
        img = img.scaled(img.size() * 0.75, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        if (img.width() < 64 || img.height() < 64) break;
    }
    return false;
}

// Reads the chosen file and gets it ready to upload. Avatars become a 512 px square.
// Banners keep their shape (shown centre-cropped); GIF banners are sent untouched.
bool preparePicture(bool avatar, const QString &path, QByteArray &data, QByteArray &mime, QString &ext, QString &err)
{
    const QFileInfo fi(path);
    if (path.isEmpty() || !fi.isFile()) { err = QStringLiteral("Couldn't find that file."); return false; }
    if (fi.size() > kMaxPickBytes) { err = QStringLiteral("That file is too big. Pick a smaller picture."); return false; }

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) { err = QStringLiteral("Couldn't open that file."); return false; }
    const QByteArray head = f.read(6);
    f.close();

    if (!avatar && (head == "GIF87a" || head == "GIF89a")) {
        if (fi.size() > kBannerMax) {
            err = QStringLiteral("That GIF is %1 MB. The limit is 3 MB. Try a shorter clip, fewer colours or a smaller size.")
                      .arg(QString::number(fi.size() / 1048576.0, 'f', 1));
            return false;
        }
        const QSize sz = QImageReader(path).size();
        if (!sz.isValid()) { err = QStringLiteral("Couldn't read that GIF."); return false; }
        if (sz.width() > kGifMaxW || sz.height() > kGifMaxH) {
            err = QStringLiteral("That GIF is %1 x %2. The most allowed is %3 x %4.").arg(sz.width()).arg(sz.height()).arg(kGifMaxW).arg(kGifMaxH);
            return false;
        }
        QFile g(path);
        if (!g.open(QIODevice::ReadOnly)) { err = QStringLiteral("Couldn't open that file."); return false; }
        data = g.readAll();
        mime = "image/gif";
        ext = QStringLiteral("gif");
        return true;
    }

    QImage img = readPicture(path);
    if (img.isNull()) { err = QStringLiteral("I can't open that as a picture. Use a PNG, JPEG, WebP or GIF."); return false; }
    if (avatar) {
        const int s = std::min(img.width(), img.height());
        img = img.copy((img.width() - s) / 2, (img.height() - s) / 2, s, s);
        if (s > 512) img = img.scaled(512, 512, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    } else if (img.width() > 1600 || img.height() > 800) {
        img = img.scaled(1600, 800, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (!encodePicture(img, avatar ? kAvatarMax : kBannerMax, data, mime, ext)) {
        err = QStringLiteral("Couldn't make that picture small enough. Try a different one.");
        return false;
    }
    return true;
}

} // namespace

Account::Account(Playlists *pl, QObject *parent) : QObject(parent), m_playlists(pl)
{
    QSettings st;
    m_refresh = st.value("account/refresh").toString();
    m_uid = st.value("account/uid").toString();
    m_username = st.value("account/username").toString();
    m_syncPlaylists = st.value("account/syncPlaylists", true).toBool();
    m_lastSync = st.value("account/lastSync").toString();
    m_avatarPath = st.value("account/avatarPath").toString();
    m_bannerPath = st.value("account/bannerPath").toString();
    m_syncTimer.setSingleShot(true);
    m_syncTimer.setInterval(4000);
    connect(&m_syncTimer, &QTimer::timeout, this, [this]() { if (signedIn() && m_syncPlaylists) syncNow(); });
    connect(pl, &Playlists::revisionChanged, this, [this]() {
        if (!m_syncing && signedIn() && m_syncPlaylists) m_syncTimer.start();     // sync shortly after a change
    });
    if (signedIn()) {
        loadImage(QStringLiteral("avatar"));
        loadImage(QStringLiteral("banner"));
        QTimer::singleShot(0, this, &Account::afterSignIn);
    }
}

void Account::setSyncPlaylists(bool on)
{
    m_syncPlaylists = on;
    QSettings().setValue("account/syncPlaylists", on);
    emit changed();
}

void Account::setMessage(const QString &m) { m_message = m; emit changed(); }
void Account::fail(const QString &m) { m_busy = false; m_syncing = false; setMessage(m); }

void Account::request(const QByteArray &verb, const QString &path, const QJsonDocument &body, const Done &done,
                      bool auth, const Extra &extra)
{
    auto send = [this, verb, path, body, done, auth, extra]() {
        QNetworkRequest rq{QUrl(QString::fromLatin1(kSupabaseUrl) + path)};
        rq.setRawHeader("apikey", kSupabaseKey);
        if (auth && !m_access.isEmpty()) rq.setRawHeader("Authorization", "Bearer " + m_access.toUtf8());
        rq.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        rq.setTransferTimeout(20000);
        for (const auto &h : extra) rq.setRawHeader(h.first, h.second);
        const QByteArray data = body.isNull() ? QByteArray() : body.toJson(QJsonDocument::Compact);
        QNetworkReply *r = verb == "GET" ? m_net.get(rq)
                         : (verb == "DELETE" && data.isEmpty()) ? m_net.deleteResource(rq)
                         : m_net.sendCustomRequest(rq, verb, data);
        connect(r, &QNetworkReply::finished, this, [r, done]() {
            r->deleteLater();
            const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QJsonDocument d = QJsonDocument::fromJson(r->readAll());
            done(status >= 200 && status < 300, d, status);
        });
    };
    if (!auth) { send(); return; }
    ensureToken([done, send](bool ok) { if (ok) send(); else done(false, QJsonDocument(), 401); });
}

void Account::ensureToken(const std::function<void(bool)> &cb)
{
    if (m_refresh.isEmpty()) { cb(false); return; }
    if (!m_access.isEmpty() && QDateTime::currentSecsSinceEpoch() < m_expires - 60) { cb(true); return; }
    request("POST", QStringLiteral("/auth/v1/token?grant_type=refresh_token"),
            QJsonDocument(QJsonObject{{"refresh_token", m_refresh}}),
            [this, cb](bool ok, const QJsonDocument &d, int) {
                if (ok) { storeSession(d.object()); cb(true); }
                else { signOutLocal(); setMessage(QStringLiteral("Your session ended. Please sign in again.")); cb(false); }
            }, false);
}

void Account::storeSession(const QJsonObject &o)
{
    m_access = o.value(QLatin1String("access_token")).toString();
    const QString refresh = o.value(QLatin1String("refresh_token")).toString();
    if (!refresh.isEmpty()) m_refresh = refresh;
    m_expires = QDateTime::currentSecsSinceEpoch() + o.value(QLatin1String("expires_in")).toInt(3600);
    const QString uid = o.value(QLatin1String("user")).toObject().value(QLatin1String("id")).toString();
    if (!uid.isEmpty()) m_uid = uid;
    QSettings st;
    st.setValue("account/refresh", m_refresh);
    st.setValue("account/uid", m_uid);
    st.setValue("account/username", m_username);
}

void Account::signUp(const QString &username, const QString &password)
{
    const QString u = username.trimmed().toLower();
    if (!validUsername(u)) { fail(QStringLiteral("Usernames are 3 to 20 letters, numbers or underscores.")); return; }
    if (password.size() < 8) { fail(QStringLiteral("Use a password of at least 8 characters.")); return; }
    m_busy = true;
    setMessage(QStringLiteral("Creating your account…"));
    const QJsonObject body{{"email", u + "@" + QString::fromLatin1(kEmailDomain)}, {"password", password},
                           {"data", QJsonObject{{"username", u}}}};
    request("POST", QStringLiteral("/auth/v1/signup"), QJsonDocument(body), [this, u](bool ok, const QJsonDocument &d, int st) {
        if (!ok || d.object().value(QLatin1String("access_token")).toString().isEmpty()) { fail(friendly(apiError(d, st), true)); return; }
        m_username = u;
        storeSession(d.object());
        afterSignIn();
    }, false);
}

void Account::signIn(const QString &username, const QString &password)
{
    const QString u = username.trimmed().toLower();
    if (u.isEmpty() || password.isEmpty()) { fail(QStringLiteral("Enter your username and password.")); return; }
    m_busy = true;
    setMessage(QStringLiteral("Signing in…"));
    const QJsonObject body{{"email", u + "@" + QString::fromLatin1(kEmailDomain)}, {"password", password}};
    request("POST", QStringLiteral("/auth/v1/token?grant_type=password"), QJsonDocument(body),
            [this, u](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { fail(friendly(apiError(d, st), false)); return; }
        m_username = u;
        storeSession(d.object());
        afterSignIn();
    }, false);
}

void Account::afterSignIn()
{
    m_playlists->useProfile(m_uid);
    request("GET", QStringLiteral("/rest/v1/profiles?select=*&id=eq.") + m_uid, {}, [this](bool ok, const QJsonDocument &d, int) {
        if (ok && !d.array().isEmpty()) {
            const QJsonObject o = d.array().first().toObject();
            m_username = o.value(QLatin1String("username")).toString(m_username);
            m_displayName = o.value(QLatin1String("display_name")).toString();
            m_bio = o.value(QLatin1String("bio")).toString();
            m_visibility = o.value(QLatin1String("visibility")).toString(QStringLiteral("private"));
            m_discoverable = o.value(QLatin1String("discoverable")).toBool();
            m_showPlaylists = o.value(QLatin1String("show_playlists")).toBool();
            QSettings().setValue("account/username", m_username);
            m_avatarPath = o.value(QLatin1String("avatar_path")).toString();
            m_bannerPath = o.value(QLatin1String("banner_path")).toString();
            QSettings pst;
            pst.setValue("account/avatarPath", m_avatarPath);
            pst.setValue("account/bannerPath", m_bannerPath);
            loadImage(QStringLiteral("avatar"));
            loadImage(QStringLiteral("banner"));
        }
        m_busy = false;
        setMessage(QString());
        if (m_syncPlaylists) syncNow();
    });
}

void Account::signOutLocal()
{
    if (!m_uid.isEmpty()) QDir(cacheDir()).removeRecursively();      // forget the cached pictures
    m_avatarPath.clear(); m_bannerPath.clear(); m_avatarUrl.clear(); m_bannerUrl.clear(); m_uploading = false;
    m_access.clear(); m_refresh.clear(); m_uid.clear(); m_username.clear(); m_displayName.clear(); m_bio.clear();
    m_visibility = QStringLiteral("private"); m_discoverable = false; m_showPlaylists = false;
    m_busy = false; m_syncing = false; m_jobs.clear(); m_lastSync.clear();
    QSettings st;
    st.remove("account/refresh"); st.remove("account/uid"); st.remove("account/username"); st.remove("account/lastSync");
    st.remove("account/avatarPath"); st.remove("account/bannerPath");
    m_playlists->useProfile(QString());
    setMessage(QString());
}

void Account::signOut() { signOutLocal(); }

void Account::saveProfile(const QString &displayName, const QString &bio, const QString &visibility,
                          bool discoverable, bool showPlaylists)
{
    if (!signedIn()) return;
    const QJsonObject body{{"display_name", displayName.trimmed().left(40)}, {"bio", bio.trimmed().left(160)},
                           {"visibility", visibility}, {"discoverable", discoverable}, {"show_playlists", showPlaylists}};
    setMessage(QStringLiteral("Saving…"));
    request("PATCH", QStringLiteral("/rest/v1/profiles?id=eq.") + m_uid, QJsonDocument(body),
            [this, displayName, bio, visibility, discoverable, showPlaylists](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { setMessage(apiError(d, st)); return; }
        m_displayName = displayName.trimmed().left(40); m_bio = bio.trimmed().left(160);
        m_visibility = visibility; m_discoverable = discoverable; m_showPlaylists = showPlaylists;
        setMessage(QStringLiteral("Profile saved."));
    }, true, {{"Prefer", "return=minimal"}});
}

// ---------- playlist sync ----------
void Account::syncNow()
{
    if (!signedIn() || m_syncing) return;
    m_syncing = true;
    setMessage(QStringLiteral("Syncing…"));
    request("GET", QStringLiteral("/rest/v1/playlists?select=id,name,updated_at,playlist_tracks(position,title,artist,album,duration_ms)&owner=eq.") + m_uid,
            {}, [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { finishSync(false, apiError(d, st)); return; }
        reconcile(d.array());
    });
}

void Account::queue(const QByteArray &verb, const QString &path, const QJsonDocument &body, const Extra &extra)
{
    m_jobs.push_back([this, verb, path, body, extra](std::function<void(bool)> next) {
        request(verb, path, body, [next](bool ok, const QJsonDocument &, int) { next(ok); }, true, extra);
    });
}

void Account::queuePush(const QVariantMap &pl)
{
    const QString id = pl.value("id").toString();
    const QJsonObject row{{"id", id}, {"owner", m_uid}, {"name", pl.value("name").toString().left(60)},
                          {"updated_at", isoUtc(pl.value("updated").toLongLong())}};
    queue("POST", QStringLiteral("/rest/v1/playlists?on_conflict=id"), QJsonDocument(QJsonArray{row}),
          {{"Prefer", "resolution=merge-duplicates,return=minimal"}});
    queue("DELETE", QStringLiteral("/rest/v1/playlist_tracks?playlist_id=eq.") + id, QJsonDocument());
    QJsonArray rows;
    int pos = 0;
    for (const QVariant &tv : pl.value("tracks").toList()) {
        const QVariantMap t = tv.toMap();
        rows.push_back(QJsonObject{{"playlist_id", id}, {"position", pos++}, {"title", t.value("title").toString().left(200)},
                                   {"artist", t.value("artist").toString().left(200)}, {"album", t.value("album").toString().left(200)},
                                   {"duration_ms", t.value("duration").toInt()}});
    }
    if (!rows.isEmpty()) queue("POST", QStringLiteral("/rest/v1/playlist_tracks"), QJsonDocument(rows), {{"Prefer", "return=minimal"}});
}

void Account::reconcile(const QJsonArray &remote)
{
    m_jobs.clear();
    QHash<QString, QJsonObject> rem;
    for (const QJsonValue &v : remote) { const QJsonObject o = v.toObject(); rem.insert(o.value(QLatin1String("id")).toString(), o); }

    for (const QString &id : m_playlists->takeDeleted())
        if (rem.contains(id)) { queue("DELETE", QStringLiteral("/rest/v1/playlists?id=eq.") + id, QJsonDocument()); rem.remove(id); }

    const auto pull = [this](const QJsonObject &o) {
        QVector<std::pair<int, QVariantMap>> tr;
        for (const QJsonValue &tv : o.value(QLatin1String("playlist_tracks")).toArray()) {
            const QJsonObject t = tv.toObject();
            tr.push_back({t.value(QLatin1String("position")).toInt(),
                          QVariantMap{{"title", t.value(QLatin1String("title")).toString()}, {"artist", t.value(QLatin1String("artist")).toString()},
                                      {"album", t.value(QLatin1String("album")).toString()}}});
        }
        std::sort(tr.begin(), tr.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
        QVariantList list;
        for (const auto &p : tr) list.push_back(p.second);
        m_playlists->applyRemote(o.value(QLatin1String("id")).toString(), o.value(QLatin1String("name")).toString(),
                                 parseIso(o.value(QLatin1String("updated_at")).toString()), list);
    };

    QSet<QString> localIds;
    for (const QVariant &v : m_playlists->snapshot()) {
        const QVariantMap m = v.toMap();
        const QString id = m.value("id").toString();
        localIds.insert(id);
        if (!rem.contains(id)) { queuePush(m); continue; }
        const qint64 remoteMs = parseIso(rem.value(id).value(QLatin1String("updated_at")).toString());
        const qint64 localMs = m.value("updated").toLongLong();
        if (localMs > remoteMs + 1500) queuePush(m);        // newest side wins
        else if (remoteMs > localMs + 1500) pull(rem.value(id));
    }
    for (auto it = rem.cbegin(); it != rem.cend(); ++it)
        if (!localIds.contains(it.key())) pull(it.value());
    runJobs();
}

void Account::runJobs()
{
    if (m_jobs.isEmpty()) { finishSync(true); return; }
    const Job job = m_jobs.takeFirst();
    job([this](bool ok) { if (ok) runJobs(); else finishSync(false, QStringLiteral("Sync stopped. Try again in a moment.")); });
}

void Account::finishSync(bool ok, const QString &err)
{
    m_syncing = false;
    m_jobs.clear();
    if (ok) {
        m_lastSync = QDateTime::currentDateTime().toString(QStringLiteral("d MMM, HH:mm"));
        QSettings().setValue("account/lastSync", m_lastSync);
        setMessage(QStringLiteral("Synced."));
    } else {
        setMessage(err.isEmpty() ? QStringLiteral("Sync failed.") : err);
    }
}

void Account::exportData()
{
    if (!signedIn()) return;
    request("POST", QStringLiteral("/rest/v1/rpc/export_my_data"), QJsonDocument(QJsonObject{}),
            [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { setMessage(apiError(d, st)); return; }
        const QString path = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation) + "/music-data-" + m_username + ".json";
        QFile f(path);
        if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) { f.write(d.toJson(QJsonDocument::Indented)); setMessage("Saved to " + path); }
        else setMessage(QStringLiteral("Couldn't save the file."));
    });
}

void Account::deleteAccount()
{
    if (!signedIn() || m_uploading) return;
    m_uploading = true;                       // blocks other picture actions meanwhile
    setMessage(QStringLiteral("Deleting your account…"));
    // The database can't delete stored files itself, so the app removes the pictures first.
    purgeStorage({QStringLiteral("avatars"), QStringLiteral("banners"), QStringLiteral("artist-photos")}, [this](bool cleared) {
        if (!cleared) {
            m_uploading = false;
            setMessage(QStringLiteral("Couldn't remove your pictures, so nothing was deleted. Try again."));
            return;
        }
        request("POST", QStringLiteral("/rest/v1/rpc/delete_my_account"), QJsonDocument(QJsonObject{}),
                [this](bool ok, const QJsonDocument &d, int st) {
            m_uploading = false;
            if (!ok) { setMessage(apiError(d, st)); return; }
            signOutLocal();
            setMessage(QStringLiteral("Your account was deleted."));
        });
    });
}

// ---------- profile picture and banner ----------
QString Account::cacheDir() const
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/profile/") + m_uid;
}

QString Account::localFileUrl(const QString &source) const
{
    const QString p = cleanPath(source);
    return (!p.isEmpty() && QFileInfo(p).isFile()) ? QUrl::fromLocalFile(p).toString() : QString();
}

void Account::putObject(const QString &bucket, const QString &path, const QByteArray &data, const QByteArray &mime, const Done &done)
{
    ensureToken([this, bucket, path, data, mime, done](bool ok) {
        if (!ok) { done(false, QJsonDocument(), 401); return; }
        QNetworkRequest rq{QUrl(QString::fromLatin1(kSupabaseUrl) + QStringLiteral("/storage/v1/object/") + bucket + QLatin1Char('/') + path)};
        rq.setRawHeader("apikey", kSupabaseKey);
        rq.setRawHeader("Authorization", "Bearer " + m_access.toUtf8());
        rq.setHeader(QNetworkRequest::ContentTypeHeader, mime);
        rq.setTransferTimeout(90000);
        QNetworkReply *r = m_net.post(rq, data);
        connect(r, &QNetworkReply::finished, this, [r, done]() {
            r->deleteLater();
            const int status = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QJsonDocument d = QJsonDocument::fromJson(r->readAll());
            done(status >= 200 && status < 300, d, status);
        });
    });
}

void Account::removeObject(const QString &bucket, const QString &path)
{
    request("DELETE", QStringLiteral("/storage/v1/object/") + bucket + QLatin1Char('/') + path, QJsonDocument(),
            [](bool, const QJsonDocument &, int) {});         // best effort: a leftover file is harmless
}

// Deletes every file in <bucket>/<my id>/ for each bucket in turn.
void Account::purgeStorage(QStringList buckets, const std::function<void(bool)> &done)
{
    if (buckets.isEmpty()) { done(true); return; }
    const QString b = buckets.first();
    request("POST", QStringLiteral("/storage/v1/object/list/") + b,
            QJsonDocument(QJsonObject{{"prefix", m_uid}, {"limit", 100}, {"offset", 0}}),
            [this, b, buckets, done](bool ok, const QJsonDocument &d, int st) mutable {
        if (!ok && st != 404) { done(false); return; }       // a missing bucket just means nothing to remove
        QJsonArray names;
        if (ok) for (const QJsonValue &v : d.array()) {
            const QString n = v.toObject().value(QLatin1String("name")).toString();
            if (!n.isEmpty()) names.push_back(m_uid + QLatin1Char('/') + n);
        }
        if (names.isEmpty()) { buckets.removeFirst(); purgeStorage(buckets, done); return; }
        const bool more = names.size() >= 100;
        request("DELETE", QStringLiteral("/storage/v1/object/") + b, QJsonDocument(QJsonObject{{"prefixes", names}}),
                [this, buckets, more, done](bool delOk, const QJsonDocument &, int) mutable {
            if (!delOk) { done(false); return; }
            if (!more) buckets.removeFirst();
            purgeStorage(buckets, done);
        });
    });
}

void Account::finishImage(const QString &kind, bool ok, const QString &text)
{
    m_uploading = false;
    setMessage(text);
    emit imageDone(kind, ok, text);
}

// Shows the cached copy of the picture, downloading it once if needed.
void Account::loadImage(const QString &kind)
{
    const bool avatar = kind == QLatin1String("avatar");
    QString &url = avatar ? m_avatarUrl : m_bannerUrl;
    const QString path = avatar ? m_avatarPath : m_bannerPath;
    url.clear();
    if (path.isEmpty() || m_uid.isEmpty()) { emit changed(); return; }

    const QString name = QFileInfo(path).fileName();
    const QString file = cacheDir() + QLatin1Char('/') + name;
    if (QFile::exists(file)) {
        for (const QString &old : QDir(cacheDir()).entryList({kind + QStringLiteral("-*")}, QDir::Files))
            if (old != name) QFile::remove(cacheDir() + QLatin1Char('/') + old);       // forget older pictures
        url = QUrl::fromLocalFile(file).toString();
        emit changed();
        return;
    }
    emit changed();
    if (m_fetching.contains(file)) return;
    m_fetching.insert(file);
    QNetworkRequest rq{QUrl(QString::fromLatin1(kSupabaseUrl) + QStringLiteral("/storage/v1/object/public/")
                            + (avatar ? QStringLiteral("avatars/") : QStringLiteral("banners/")) + path)};
    rq.setTransferTimeout(30000);
    QNetworkReply *r = m_net.get(rq);
    connect(r, &QNetworkReply::finished, this, [this, r, kind, file, path]() {
        r->deleteLater();
        m_fetching.remove(file);
        const QString &current = kind == QLatin1String("avatar") ? m_avatarPath : m_bannerPath;
        if (r->error() != QNetworkReply::NoError || current != path || m_uid.isEmpty()) return;
        const QByteArray bytes = r->readAll();
        if (bytes.isEmpty()) return;
        QDir().mkpath(cacheDir());
        QFile out(file);
        if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) { out.write(bytes); out.close(); }
        if (QFile::exists(file)) loadImage(kind);
    });
}

void Account::uploadImage(const QString &kind, const QString &source)
{
    const bool avatar = kind == QLatin1String("avatar");
    if (!signedIn() || m_uploading || (!avatar && kind != QLatin1String("banner"))) return;

    QByteArray data, mime;
    QString ext, err;
    if (!preparePicture(avatar, cleanPath(source), data, mime, ext, err)) { emit imageDone(kind, false, err); return; }

    const QString bucket = avatar ? QStringLiteral("avatars") : QStringLiteral("banners");
    const QString column = avatar ? QStringLiteral("avatar_path") : QStringLiteral("banner_path");
    const QString oldPath = avatar ? m_avatarPath : m_bannerPath;
    // A new name every time, so nothing old is ever served from a cache.
    const QString path = m_uid + QLatin1Char('/') + kind + QLatin1Char('-') + QString::number(QDateTime::currentMSecsSinceEpoch())
                         + QLatin1Char('.') + ext;

    m_uploading = true;
    setMessage(QStringLiteral("Uploading…"));
    putObject(bucket, path, data, mime, [this, kind, avatar, bucket, column, oldPath, path, data](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { finishImage(kind, false, apiError(d, st)); return; }
        if (!signedIn()) { m_uploading = false; return; }
        request("PATCH", QStringLiteral("/rest/v1/profiles?id=eq.") + m_uid, QJsonDocument(QJsonObject{{column, path}}),
                [this, kind, avatar, bucket, oldPath, path, data](bool ok2, const QJsonDocument &d2, int st2) {
            if (!ok2) { removeObject(bucket, path); finishImage(kind, false, apiError(d2, st2)); return; }
            if (!signedIn()) { m_uploading = false; return; }
            (avatar ? m_avatarPath : m_bannerPath) = path;
            QSettings().setValue(avatar ? "account/avatarPath" : "account/bannerPath", path);
            // Keep the copy we just made, so it never has to be downloaded again.
            QDir().mkpath(cacheDir());
            QFile out(cacheDir() + QLatin1Char('/') + QFileInfo(path).fileName());
            if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) { out.write(data); out.close(); }
            loadImage(kind);
            if (!oldPath.isEmpty()) removeObject(bucket, oldPath);
            finishImage(kind, true, avatar ? QStringLiteral("Profile picture updated.") : QStringLiteral("Banner updated."));
        }, true, {{"Prefer", "return=minimal"}});
    });
}

void Account::removeImage(const QString &kind)
{
    const bool avatar = kind == QLatin1String("avatar");
    if (!signedIn() || m_uploading || (!avatar && kind != QLatin1String("banner"))) return;
    const QString oldPath = avatar ? m_avatarPath : m_bannerPath;
    if (oldPath.isEmpty()) { emit imageDone(kind, true, QString()); return; }

    const QString bucket = avatar ? QStringLiteral("avatars") : QStringLiteral("banners");
    const QString column = avatar ? QStringLiteral("avatar_path") : QStringLiteral("banner_path");
    m_uploading = true;
    setMessage(QStringLiteral("Removing…"));
    request("PATCH", QStringLiteral("/rest/v1/profiles?id=eq.") + m_uid, QJsonDocument(QJsonObject{{column, QJsonValue(QJsonValue::Null)}}),
            [this, kind, avatar, bucket, oldPath](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { finishImage(kind, false, apiError(d, st)); return; }
        if (!signedIn()) { m_uploading = false; return; }
        (avatar ? m_avatarPath : m_bannerPath).clear();
        QSettings().remove(avatar ? "account/avatarPath" : "account/bannerPath");
        QFile::remove(cacheDir() + QLatin1Char('/') + QFileInfo(oldPath).fileName());
        loadImage(kind);
        removeObject(bucket, oldPath);
        finishImage(kind, true, avatar ? QStringLiteral("Profile picture removed.") : QStringLiteral("Banner removed."));
    }, true, {{"Prefer", "return=minimal"}});
}
