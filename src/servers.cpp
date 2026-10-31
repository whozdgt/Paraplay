#include "servers.h"

#include <QCryptographicHash>
#include <QDataStream>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QSslCertificate>
#include <QSslConfiguration>
#include <QSslError>
#include <QStandardPaths>
#include <QUrl>
#include <algorithm>

#include "library.h"

namespace {

using Params = QList<QPair<QString, QString>>;

QString enc(const QString &s) { return QString::fromLatin1(QUrl::toPercentEncoding(s)); }

QString str(const QJsonValue &v)
{
    if (v.isString()) return v.toString();
    if (v.isDouble()) return QString::number(qint64(v.toDouble()));
    return {};
}

QString randomHex(int bytes)
{
    QByteArray b;
    for (int i = 0; i < bytes; ++i) b.append(char(QRandomGenerator::system()->bounded(256)));
    return QString::fromLatin1(b.toHex());
}

QString md5hex(const QString &s)
{
    return QString::fromLatin1(QCryptographicHash::hash(s.toUtf8(), QCryptographicHash::Md5).toHex());
}

bool isLanHost(const QString &host)
{
    if (!host.contains(QLatin1Char('.'))) return true;      // "nas", "localhost"
    for (const char *suffix : {".local", ".lan", ".home", ".internal", ".home.arpa"})
        if (host.endsWith(QLatin1String(suffix))) return true;
    if (host.startsWith(QLatin1String("10.")) || host.startsWith(QLatin1String("192.168.")) || host.startsWith(QLatin1String("127.")))
        return true;
    if (host.startsWith(QLatin1String("172."))) {
        const int second = host.section(QLatin1Char('.'), 1, 1).toInt();
        return second >= 16 && second <= 31;
    }
    return false;
}

// "nas.local:4533" -> "http://nas.local:4533", "music.example.com" -> "https://music.example.com", no trailing slash.
QString normalizeUrl(QString u)
{
    u = u.trimmed();
    if (u.isEmpty()) return u;
    if (!u.contains(QLatin1String("://"))) {
        const QString host = u.section(QLatin1Char('/'), 0, 0).section(QLatin1Char(':'), 0, 0).toLower();
        u = (isLanHost(host) ? QStringLiteral("http://") : QStringLiteral("https://")) + u;
    }
    while (u.endsWith(QLatin1Char('/'))) u.chop(1);
    return u;
}

// codec name or file ending -> what we show; fills codec and lossless
void classify(Track &t, const QString &name, int bits)
{
    const QString n = name.toLower();
    t.lossless = true;
    if (n == QLatin1String("flac")) t.codec = QStringLiteral("FLAC");
    else if (n == QLatin1String("alac")) t.codec = QStringLiteral("ALAC");
    else if (n == QLatin1String("wav") || n.startsWith(QLatin1String("pcm"))) t.codec = QStringLiteral("WAV");
    else if (n == QLatin1String("aif") || n == QLatin1String("aiff")) t.codec = QStringLiteral("AIFF");
    else if (n == QLatin1String("wv") || n == QLatin1String("wavpack")) t.codec = QStringLiteral("WavPack");
    else if (n == QLatin1String("ape")) t.codec = QStringLiteral("APE");
    else if (n == QLatin1String("m4a") || n == QLatin1String("mp4")) {
        if (bits > 0) t.codec = QStringLiteral("ALAC");      // AAC has no bit depth
        else { t.codec = QStringLiteral("AAC"); t.lossless = false; }
    } else {
        t.lossless = false;
        if (n == QLatin1String("mp3")) t.codec = QStringLiteral("MP3");
        else if (n == QLatin1String("ogg") || n == QLatin1String("oga") || n == QLatin1String("vorbis")) t.codec = QStringLiteral("OGG");
        else if (n == QLatin1String("opus")) t.codec = QStringLiteral("OPUS");
        else if (n == QLatin1String("aac")) t.codec = QStringLiteral("AAC");
        else if (n.startsWith(QLatin1String("wma"))) t.codec = QStringLiteral("WMA");
        else t.codec = n.toUpper();
    }
}

void fillBlanks(Track &t)
{
    if (t.title.isEmpty()) t.title = QStringLiteral("Unknown title");
    if (t.artist.isEmpty()) t.artist = QStringLiteral("Unknown artist");
    if (t.album.isEmpty()) t.album = QStringLiteral("Unknown album");
}

QString dataDir() { return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation); }
QString cacheDir() { return QStandardPaths::writableLocation(QStandardPaths::CacheLocation); }

void deliver(const QPointer<CoverResponse> &r, const QImage &img, const QString &err)
{
    if (!r) return;
    // finish on the response's own thread, so it can't be deleted while we touch it
    QMetaObject::invokeMethod(r.data(), [r, img, err]() { if (r) r->done(img, err); }, Qt::QueuedConnection);
}

} // namespace

// ---------------------------------------------------------------------------------------------
// ServerClient: the web plumbing both kinds of server share

ServerClient::ServerClient(const ServerInfo &info, QNetworkAccessManager *net, QObject *parent)
    : QObject(parent), m_info(info), m_net(net)
{
}

ServerClient::~ServerClient()
{
    const auto replies = m_replies;               // abort() ends a reply, which edits the set
    for (QNetworkReply *r : replies) {
        r->disconnect(this);
        r->abort();
        r->deleteLater();
    }
}

QNetworkReply *ServerClient::send(const QNetworkRequest &request, const QByteArray &body, bool post)
{
    QNetworkRequest rq = request;
    rq.setTransferTimeout(30000);
    rq.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *r = post ? m_net->post(rq, body) : m_net->get(rq);
    m_replies.insert(r);
    // A self-signed certificate is let through only if you asked for that, and only the one you trusted first.
    connect(r, &QNetworkReply::sslErrors, this, [this, r](const QList<QSslError> &) {
        if (!m_info.allowSelfSigned) return;
        const QString fp = QString::fromLatin1(
            r->sslConfiguration().peerCertificate().digest(QCryptographicHash::Sha256).toHex(':'));
        if (fp.isEmpty()) return;
        if (m_info.pin.isEmpty()) {
            m_info.pin = fp;
            emit pinned(fp);
            r->ignoreSslErrors();
        } else if (m_info.pin == fp) {
            r->ignoreSslErrors();
        } else {
            m_certChanged = true;
        }
    });
    connect(r, &QNetworkReply::finished, this, [this, r]() { m_replies.remove(r); });
    return r;
}

void ServerClient::getJson(const QNetworkRequest &rq, const JsonDone &done, const QByteArray &body, bool post)
{
    QNetworkReply *r = send(rq, body, post);
    connect(r, &QNetworkReply::finished, this, [this, r, done]() {
        r->deleteLater();
        if (r->error() != QNetworkReply::NoError) { done(false, QJsonDocument(), errorText(r)); return; }
        QJsonParseError pe;
        const QJsonDocument doc = QJsonDocument::fromJson(r->readAll(), &pe);
        if (pe.error != QJsonParseError::NoError) {
            done(false, QJsonDocument(), QStringLiteral("That address answered, but not like a music server."));
            return;
        }
        done(true, doc, QString());
    });
}

QString ServerClient::errorText(QNetworkReply *r) const
{
    if (m_certChanged)
        return QStringLiteral("The server's certificate changed since you trusted it. Remove the server and add it again if that is expected.");
    switch (r->error()) {
    case QNetworkReply::ConnectionRefusedError: return QStringLiteral("The server refused the connection. Check the address and port.");
    case QNetworkReply::HostNotFoundError: return QStringLiteral("Can't find that address.");
    case QNetworkReply::TimeoutError:
    case QNetworkReply::OperationCanceledError: return QStringLiteral("The server didn't answer in time.");
    case QNetworkReply::SslHandshakeFailedError:
        return QStringLiteral("The server's certificate isn't trusted. If it's your own, turn on “Allow a self-signed certificate”.");
    case QNetworkReply::AuthenticationRequiredError:
    case QNetworkReply::ContentAccessDenied: return QStringLiteral("Wrong username or password.");
    default: break;
    }
    const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (code == 401 || code == 403) return QStringLiteral("Wrong username or password.");
    if (code == 404) return QStringLiteral("Nothing answers at that address (404). Check the address.");
    return r->errorString();
}

// ---------------------------------------------------------------------------------------------
// Navidrome / Subsonic / OpenSubsonic

namespace {

class SubsonicClient : public ServerClient {
public:
    using ServerClient::ServerClient;

    void login(const QString &, const LoginDone &done) override
    {
        getJson(QNetworkRequest(api(QStringLiteral("ping"))), [done](bool ok, const QJsonDocument &doc, const QString &err) {
            QString e;
            if (!ok) { done(false, err); return; }
            if (!subOk(doc, e)) { done(false, e); return; }
            const QJsonObject r = doc.object().value("subsonic-response").toObject();
            QString type = r.value("type").toString();
            if (type.isEmpty()) type = QStringLiteral("Subsonic");
            else type[0] = type[0].toUpper();
            const QString ver = r.value("serverVersion").toString();
            done(true, ver.isEmpty() ? type : type + QStringLiteral(" ") + ver);
        });
    }

    void fetchAll(const std::function<void(int)> &progress, const TracksDone &done) override
    {
        pageSongs(0, 0, QString(), std::make_shared<QVector<Track>>(), progress, done);
    }

    QString streamUrl(const QString &itemId) const override
    {
        // format=raw: the original file, never transcoded
        return QString::fromLatin1(api(QStringLiteral("stream"),
            {{QStringLiteral("id"), itemId}, {QStringLiteral("format"), QStringLiteral("raw")}}).toEncoded());
    }

    QNetworkRequest coverRequest(const QString &coverId) const override
    {
        return QNetworkRequest(api(QStringLiteral("getCoverArt"),
            {{QStringLiteral("id"), coverId}, {QStringLiteral("size"), QStringLiteral("600")}}));
    }

private:
    struct Walk {
        QStringList albums;
        int next = 0, inflight = 0;
        QVector<Track> out;
    };

    QUrl api(const QString &method, const Params &extra = {}) const
    {
        QString q = QStringLiteral("u=%1&t=%2&s=%3&v=1.16.1&c=musicplayer&f=json").arg(enc(m_info.user), m_info.secret, m_info.salt);
        for (const auto &p : extra) q += QStringLiteral("&") + p.first + QStringLiteral("=") + enc(p.second);
        QUrl u(m_info.url + QStringLiteral("/rest/") + method + QStringLiteral(".view"));
        u.setQuery(q);
        return u;
    }

    static bool subOk(const QJsonDocument &doc, QString &err)
    {
        const QJsonObject r = doc.object().value("subsonic-response").toObject();
        if (r.value("status").toString() == QLatin1String("ok")) return true;
        err = r.value("error").toObject().value("message").toString();
        if (err.isEmpty())
            err = r.isEmpty() ? QStringLiteral("That address answered, but it isn't a Subsonic or Navidrome server.")
                              : QStringLiteral("The server refused the request.");
        return false;
    }

    Track trackFrom(const QJsonObject &s) const
    {
        Track t;
        const QString id = str(s.value("id"));
        if (id.isEmpty()) return t;
        t.path = QStringLiteral("srv://%1/%2").arg(m_info.id, id);
        t.title = s.value("title").toString();
        t.artist = s.value("artist").toString();
        t.album = s.value("album").toString();
        t.albumId = str(s.value("albumId"));
        t.cover = str(s.value("coverArt"));
        t.trackNo = s.value("track").toInt();
        t.lengthMs = s.value("duration").toInt() * 1000;
        t.bitrate = s.value("bitRate").toInt();
        t.sampleRate = s.value("samplingRate").toInt();     // OpenSubsonic extras, when the server has them
        t.bits = s.value("bitDepth").toInt();
        t.size = qint64(s.value("size").toDouble());
        const QDateTime dt = QDateTime::fromString(s.value("created").toString(), Qt::ISODate);
        t.mtime = dt.isValid() ? dt.toSecsSinceEpoch() : 0;
        classify(t, s.value("suffix").toString(), t.bits);
        fillBlanks(t);
        return t;
    }

    // Preferred way: search3 with an empty query lists every song, 500 at a time.
    void pageSongs(int mode, int offset, const QString &prevFirst, const std::shared_ptr<QVector<Track>> &out,
                   const std::function<void(int)> &progress, const TracksDone &done)
    {
        constexpr int kPage = 500;
        const Params p{{QStringLiteral("query"), mode == 0 ? QString() : QStringLiteral("\"\"")},
                       {QStringLiteral("songCount"), QString::number(kPage)},
                       {QStringLiteral("songOffset"), QString::number(offset)},
                       {QStringLiteral("artistCount"), QStringLiteral("0")},
                       {QStringLiteral("albumCount"), QStringLiteral("0")}};
        getJson(QNetworkRequest(api(QStringLiteral("search3"), p)),
                [this, mode, offset, prevFirst, out, progress, done](bool ok, const QJsonDocument &doc, const QString &err) {
            QString e;
            if (!ok) { done(false, QVector<Track>(), err); return; }
            if (!subOk(doc, e)) { done(false, QVector<Track>(), e); return; }
            const QJsonArray songs = doc.object().value("subsonic-response").toObject()
                                         .value("searchResult3").toObject().value("song").toArray();
            const QString first = songs.isEmpty() ? QString() : str(songs.at(0).toObject().value("id"));
            if (songs.isEmpty() || (offset > 0 && first == prevFirst)) {      // last page, or a server that ignores the offset
                if (out->isEmpty() && mode == 0) { pageSongs(1, 0, QString(), out, progress, done); return; }
                if (out->isEmpty()) { pageAlbums(0, std::make_shared<Walk>(), progress, done); return; }
                done(true, *out, QString());
                return;
            }
            for (const QJsonValue &v : songs) {
                Track t = trackFrom(v.toObject());
                if (!t.path.isEmpty()) out->push_back(std::move(t));
            }
            progress(int(out->size()));
            if (out->size() > 2000000) { done(true, *out, QString()); return; }
            pageSongs(mode, offset + int(songs.size()), first, out, progress, done);
        });
    }

    // Fallback for servers that don't list songs that way: every album, then every album's songs.
    void pageAlbums(int offset, const std::shared_ptr<Walk> &w, const std::function<void(int)> &progress, const TracksDone &done)
    {
        const Params p{{QStringLiteral("type"), QStringLiteral("alphabeticalByName")},
                       {QStringLiteral("size"), QStringLiteral("500")},
                       {QStringLiteral("offset"), QString::number(offset)}};
        getJson(QNetworkRequest(api(QStringLiteral("getAlbumList2"), p)),
                [this, offset, w, progress, done](bool ok, const QJsonDocument &doc, const QString &err) {
            QString e;
            if (!ok) { done(false, QVector<Track>(), err); return; }
            if (!subOk(doc, e)) { done(false, QVector<Track>(), e); return; }
            const QJsonArray albums = doc.object().value("subsonic-response").toObject()
                                          .value("albumList2").toObject().value("album").toArray();
            const QString first = albums.isEmpty() ? QString() : str(albums.at(0).toObject().value("id"));
            if (albums.isEmpty() || (offset > 0 && !w->albums.isEmpty() && first == w->albums.first())) {
                if (w->albums.isEmpty()) { done(true, QVector<Track>(), QString()); return; }
                pumpWalk(w, progress, done);
                return;
            }
            for (const QJsonValue &v : albums) w->albums << str(v.toObject().value("id"));
            pageAlbums(offset + int(albums.size()), w, progress, done);
        });
    }

    void pumpWalk(const std::shared_ptr<Walk> &w, const std::function<void(int)> &progress, const TracksDone &done)
    {
        while (w->inflight < 3 && w->next < w->albums.size()) {
            const QString id = w->albums[w->next++];
            ++w->inflight;
            getJson(QNetworkRequest(api(QStringLiteral("getAlbum"), {{QStringLiteral("id"), id}})),
                    [this, w, progress, done](bool ok, const QJsonDocument &doc, const QString &) {
                --w->inflight;
                QString e;
                if (ok && subOk(doc, e)) {
                    const QJsonArray songs = doc.object().value("subsonic-response").toObject()
                                                 .value("album").toObject().value("song").toArray();
                    for (const QJsonValue &v : songs) {
                        Track t = trackFrom(v.toObject());
                        if (!t.path.isEmpty()) w->out.push_back(std::move(t));
                    }
                    progress(int(w->out.size()));
                }
                if (w->next >= w->albums.size() && w->inflight == 0) { done(true, w->out, QString()); return; }
                pumpWalk(w, progress, done);
            });
        }
    }
};

// ---------------------------------------------------------------------------------------------
// Jellyfin

class JellyfinClient : public ServerClient {
public:
    using ServerClient::ServerClient;

    void login(const QString &password, const LoginDone &done) override
    {
        QNetworkRequest rq = request(QStringLiteral("/Users/AuthenticateByName"));
        rq.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        const QByteArray body = QJsonDocument(QJsonObject{{"Username", m_info.user}, {"Pw", password}}).toJson(QJsonDocument::Compact);
        getJson(rq, [this, done](bool ok, const QJsonDocument &doc, const QString &err) {
            if (!ok) { done(false, err); return; }
            const QJsonObject o = doc.object();
            const QString token = o.value("AccessToken").toString();
            if (token.isEmpty()) { done(false, QStringLiteral("That address answered, but it isn't a Jellyfin server.")); return; }
            m_info.secret = token;
            m_info.userId = o.value("User").toObject().value("Id").toString();
            getJson(request(QStringLiteral("/System/Info/Public")), [done](bool ok2, const QJsonDocument &d2, const QString &) {
                QString name = QStringLiteral("Jellyfin");
                if (ok2) {
                    const QString v = d2.object().value("Version").toString();
                    if (!v.isEmpty()) name += QStringLiteral(" ") + v;
                }
                done(true, name);
            });
        }, body, true);
    }

    void fetchAll(const std::function<void(int)> &progress, const TracksDone &done) override
    {
        if (m_info.userId.isEmpty()) { done(false, QVector<Track>(), QStringLiteral("Signed out. Remove this server and add it again.")); return; }
        page(0, std::make_shared<QVector<Track>>(), progress, done);
    }

    QString streamUrl(const QString &itemId) const override
    {
        // static=true: the original file as it is on the server
        return m_info.url + QStringLiteral("/Audio/") + enc(itemId) + QStringLiteral("/stream?static=true&api_key=")
            + enc(m_info.secret) + QStringLiteral("&DeviceId=") + enc(m_info.id);
    }

    QNetworkRequest coverRequest(const QString &coverId) const override
    {
        return request(QStringLiteral("/Items/%1/Images/Primary").arg(enc(coverId)), QStringLiteral("maxWidth=600&quality=90"));
    }

private:
    QNetworkRequest request(const QString &path, const QString &query = QString()) const
    {
        QUrl u(m_info.url + path);
        if (!query.isEmpty()) u.setQuery(query);
        QNetworkRequest rq(u);
        QString auth = QStringLiteral("MediaBrowser Client=\"musicplayer\", Device=\"Desktop\", DeviceId=\"%1\", Version=\"0.6\"").arg(m_info.id);
        if (!m_info.secret.isEmpty()) auth += QStringLiteral(", Token=\"%1\"").arg(m_info.secret);
        rq.setRawHeader("Authorization", auth.toUtf8());
        rq.setRawHeader("X-Emby-Authorization", auth.toUtf8());
        rq.setRawHeader("Accept", "application/json");
        return rq;
    }

    Track trackFrom(const QJsonObject &o) const
    {
        Track t;
        const QString id = o.value("Id").toString();
        if (id.isEmpty()) return t;
        t.path = QStringLiteral("srv://%1/%2").arg(m_info.id, id);
        t.title = o.value("Name").toString();
        QStringList artists;
        for (const QJsonValue &a : o.value("Artists").toArray()) artists << a.toString();
        t.artist = artists.isEmpty() ? o.value("AlbumArtist").toString() : artists.join(QStringLiteral("; "));
        t.album = o.value("Album").toString();
        t.albumId = o.value("AlbumId").toString();
        t.trackNo = o.value("IndexNumber").toInt();
        t.lengthMs = int(o.value("RunTimeTicks").toDouble() / 10000.0);
        const QDateTime dt = QDateTime::fromString(o.value("DateCreated").toString(), Qt::ISODate);
        t.mtime = dt.isValid() ? dt.toSecsSinceEpoch() : 0;
        // the song's own picture, or else its album's
        if (!o.value("ImageTags").toObject().value("Primary").toString().isEmpty()) t.cover = id;
        else if (!o.value("AlbumPrimaryImageTag").toString().isEmpty()) t.cover = t.albumId;
        QString codec, container;
        int bits = 0;
        const QJsonArray sources = o.value("MediaSources").toArray();
        if (!sources.isEmpty()) {
            const QJsonObject src = sources.at(0).toObject();
            t.size = qint64(src.value("Size").toDouble());
            container = src.value("Container").toString();
            for (const QJsonValue &sv : src.value("MediaStreams").toArray()) {
                const QJsonObject s = sv.toObject();
                if (s.value("Type").toString() != QLatin1String("Audio")) continue;
                codec = s.value("Codec").toString();
                t.sampleRate = s.value("SampleRate").toInt();
                bits = s.value("BitDepth").toInt();
                t.bitrate = s.value("BitRate").toInt() / 1000;
                break;
            }
            if (t.bitrate == 0) t.bitrate = src.value("Bitrate").toInt() / 1000;
        }
        t.bits = bits;
        classify(t, codec.isEmpty() ? container : codec, bits);
        fillBlanks(t);
        return t;
    }

    void page(int start, const std::shared_ptr<QVector<Track>> &out, const std::function<void(int)> &progress, const TracksDone &done)
    {
        constexpr int kPage = 300;
        const QString q = QStringLiteral("IncludeItemTypes=Audio&Recursive=true&Fields=MediaSources,DateCreated"
                                         "&EnableImages=true&SortBy=SortName&StartIndex=%1&Limit=%2").arg(start).arg(kPage);
        getJson(request(QStringLiteral("/Users/%1/Items").arg(enc(m_info.userId)), q),
                [this, start, out, progress, done](bool ok, const QJsonDocument &doc, const QString &err) {
            if (!ok) { done(false, QVector<Track>(), err); return; }
            const QJsonObject root = doc.object();
            const QJsonArray items = root.value("Items").toArray();
            for (const QJsonValue &v : items) {
                Track t = trackFrom(v.toObject());
                if (!t.path.isEmpty()) out->push_back(std::move(t));
            }
            progress(int(out->size()));
            const int total = root.value("TotalRecordCount").toInt();
            const int next = start + int(items.size());
            if (items.isEmpty() || (total > 0 && next >= total)) { done(true, *out, QString()); return; }
            page(next, out, progress, done);
        });
    }
};

} // namespace

// ---------------------------------------------------------------------------------------------
// ServerManager

ServerManager::ServerManager(Library *lib, QObject *parent) : QObject(parent), m_lib(lib)
{
    load();
    m_timer.setInterval(4 * 60 * 60 * 1000);          // look for new songs every few hours
    connect(&m_timer, &QTimer::timeout, this, [this]() { syncNow(); });
    m_timer.start();
    QTimer::singleShot(2500, this, [this]() { syncNow(); });      // after the window is up
    QTimer::singleShot(15000, this, [this]() { pruneCovers(); });
}

ServerManager::~ServerManager()
{
    // The clients abort their requests when they go, which needs the network manager (a member) to still exist.
    for (const auto &e : m_servers) {
        delete e->client;
        e->client = nullptr;
    }
}

ServerManager::Entry *ServerManager::find(const QString &id) const
{
    for (const auto &e : m_servers) if (e->info.id == id) return e.get();
    return nullptr;
}

ServerClient *ServerManager::makeClient(const ServerInfo &si)
{
    ServerClient *c = si.kind == QLatin1String("jellyfin") ? static_cast<ServerClient *>(new JellyfinClient(si, &m_net, this))
                                                          : static_cast<ServerClient *>(new SubsonicClient(si, &m_net, this));
    connect(c, &ServerClient::pinned, this, [this, id = si.id](const QString &fp) {
        if (Entry *e = find(id)) { e->info.pin = fp; save(); }
    });
    return c;
}

QString ServerManager::tracksFile(const QString &id) const
{
    QDir().mkpath(cacheDir());
    return cacheDir() + QStringLiteral("/server-") + id + QStringLiteral(".bin");
}

void ServerManager::saveTracks(const QString &id, const QVector<Track> &tracks) const
{
    QFile f(tracksFile(id));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    QDataStream s(&f);
    s.setVersion(QDataStream::Qt_6_0);
    s << quint32(0x4D555333) << qint32(tracks.size());
    for (const Track &t : tracks) s << t;
}

QVector<Track> ServerManager::loadTracks(const QString &id) const
{
    QVector<Track> v;
    QFile f(tracksFile(id));
    if (!f.open(QIODevice::ReadOnly)) return v;
    QDataStream s(&f);
    s.setVersion(QDataStream::Qt_6_0);
    quint32 magic = 0;
    qint32 n = 0;
    s >> magic >> n;
    if (magic != 0x4D555333 || n < 0) return v;
    v.reserve(n);
    for (qint32 i = 0; i < n && s.status() == QDataStream::Ok; ++i) { Track t; s >> t; v.push_back(std::move(t)); }
    if (s.status() != QDataStream::Ok) v.clear();
    return v;
}

void ServerManager::load()
{
    QFile f(dataDir() + QStringLiteral("/servers.json"));
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).object().value("servers").toArray();
    for (const QJsonValue &v : arr) {
        const QJsonObject o = v.toObject();
        ServerInfo si;
        si.id = o.value("id").toString();
        si.kind = o.value("kind").toString();
        si.name = o.value("name").toString();
        si.url = o.value("url").toString();
        si.user = o.value("user").toString();
        si.secret = o.value("secret").toString();
        si.salt = o.value("salt").toString();
        si.userId = o.value("userId").toString();
        si.pin = o.value("pin").toString();
        si.allowSelfSigned = o.value("allowSelfSigned").toBool();
        si.enabled = o.value("enabled").toBool(true);
        if (si.id.isEmpty() || si.url.isEmpty()) continue;
        auto e = std::make_unique<Entry>();
        e->info = si;
        e->count = o.value("count").toInt();
        e->lastSync = qint64(o.value("lastSync").toDouble());
        e->detail = o.value("detail").toString();
        e->client = makeClient(si);
        if (si.enabled) {
            const QVector<Track> cached = loadTracks(si.id);      // shows up straight away, before the first sync
            if (!cached.isEmpty()) m_lib->setRemoteTracks(si.id, cached);
        }
        m_servers.push_back(std::move(e));
    }
}

void ServerManager::save() const
{
    QJsonArray arr;
    for (const auto &e : m_servers) {
        const ServerInfo &s = e->info;
        arr.push_back(QJsonObject{{"id", s.id}, {"kind", s.kind}, {"name", s.name}, {"url", s.url}, {"user", s.user},
                                  {"secret", s.secret}, {"salt", s.salt}, {"userId", s.userId}, {"pin", s.pin},
                                  {"allowSelfSigned", s.allowSelfSigned}, {"enabled", s.enabled},
                                  {"count", e->count}, {"lastSync", double(e->lastSync)}, {"detail", e->detail}});
    }
    QDir().mkpath(dataDir());
    QFile f(dataDir() + QStringLiteral("/servers.json"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);      // it holds sign-in tokens: only you may read it
    f.write(QJsonDocument(QJsonObject{{"servers", arr}}).toJson(QJsonDocument::Compact));
}

QVariantList ServerManager::list() const
{
    QVariantList out;
    for (const auto &e : m_servers) {
        out.push_back(QVariantMap{{"id", e->info.id}, {"kind", e->info.kind}, {"name", e->info.name}, {"url", e->info.url},
                                  {"user", e->info.user}, {"enabled", e->info.enabled},
                                  {"state", e->info.enabled ? e->state : QStringLiteral("off")},
                                  {"detail", e->detail}, {"error", e->error}, {"count", e->count},
                                  {"progress", e->progress}, {"lastSync", double(e->lastSync)},
                                  {"selfSigned", e->info.allowSelfSigned}});
    }
    return out;
}

QString ServerManager::sourceName(const QString &id) const
{
    if (id.isEmpty()) return QStringLiteral("All sources");
    if (id == QLatin1String("local")) return QStringLiteral("This computer");
    const Entry *e = find(id);
    return e ? e->info.name : QStringLiteral("All sources");
}

void ServerManager::connectServer(const QString &kind, const QString &name, const QString &url, const QString &user,
                                  const QString &password, bool allowSelfSigned, bool addIt)
{
    if (m_testing) return;
    ServerInfo si;
    si.id = randomHex(4);
    si.kind = kind == QLatin1String("jellyfin") ? kind : QStringLiteral("subsonic");
    si.name = name.trimmed();
    si.url = normalizeUrl(url);
    si.user = user.trimmed();
    si.allowSelfSigned = allowSelfSigned;
    if (si.url.isEmpty()) { emit connectResult(false, QStringLiteral("Type the server's address first."), false); return; }
    if (si.user.isEmpty()) { emit connectResult(false, QStringLiteral("Type your username on that server."), false); return; }
    for (const auto &e : m_servers)
        if (e->info.url == si.url && e->info.user == si.user) {
            emit connectResult(false, QStringLiteral("That server is already in your list."), false);
            return;
        }
    if (si.kind == QLatin1String("subsonic")) {
        // Navidrome and friends accept a one-way token, so the password itself is never stored.
        si.salt = randomHex(6);
        si.secret = md5hex(password + si.salt);
    }
    ServerClient *c = makeClient(si);
    m_testing = true;
    touch();
    c->login(password, [this, c, addIt](bool ok, const QString &detail) {
        m_testing = false;
        if (!ok) { c->deleteLater(); touch(); emit connectResult(false, detail, false); return; }
        if (!addIt) {
            QString msg = QStringLiteral("Connected: %1.").arg(detail);
            if (!c->info().pin.isEmpty()) msg += QStringLiteral(" Self-signed certificate accepted.");
            c->deleteLater();
            touch();
            emit connectResult(true, msg, false);
            return;
        }
        auto e = std::make_unique<Entry>();
        e->info = c->info();
        if (e->info.name.isEmpty()) e->info.name = QUrl(e->info.url).host();
        e->client = c;
        e->detail = detail;
        const QString id = e->info.id;
        const QString shown = e->info.name;
        m_servers.push_back(std::move(e));
        save();
        touch();
        emit connectResult(true, QStringLiteral("Added %1.").arg(shown), true);
        sync(id);
    });
}

void ServerManager::syncNow(const QString &id)
{
    if (!id.isEmpty()) { sync(id); return; }
    QStringList ids;
    for (const auto &e : m_servers) ids << e->info.id;
    for (const QString &i : std::as_const(ids)) sync(i);
}

void ServerManager::sync(const QString &id)
{
    Entry *e = find(id);
    if (!e || !e->info.enabled || e->state == QLatin1String("syncing")) return;
    e->state = QStringLiteral("syncing");
    e->error.clear();
    e->progress = 0;
    touch();
    e->client->fetchAll(
        [this, id](int n) { if (Entry *x = find(id)) { x->progress = n; touch(); } },
        [this, id](bool ok, const QVector<Track> &tracks, const QString &err) {
            Entry *x = find(id);
            if (!x) return;
            if (!x->info.enabled) { x->state = QStringLiteral("idle"); touch(); return; }
            if (!ok) { x->state = QStringLiteral("error"); x->error = err; touch(); return; }
            x->state = QStringLiteral("ok");
            x->count = int(tracks.size());
            x->lastSync = QDateTime::currentMSecsSinceEpoch();
            m_lib->setRemoteTracks(id, tracks);
            saveTracks(id, tracks);
            save();
            touch();
        });
}

void ServerManager::setEnabled(const QString &id, bool on)
{
    Entry *e = find(id);
    if (!e || e->info.enabled == on) return;
    e->info.enabled = on;
    if (!on) {
        if (m_lib->source() == id) m_lib->setSource(QString());
        m_lib->setRemoteTracks(id, QVector<Track>());
        e->state = QStringLiteral("idle");
    } else {
        const QVector<Track> cached = loadTracks(id);
        if (!cached.isEmpty()) m_lib->setRemoteTracks(id, cached);
    }
    save();
    touch();
    if (on) sync(id);
}

void ServerManager::removeServer(const QString &id)
{
    for (auto it = m_servers.begin(); it != m_servers.end(); ++it) {
        if ((*it)->info.id != id) continue;
        ServerClient *c = (*it)->client;
        m_servers.erase(it);
        if (c) c->deleteLater();
        if (m_lib->source() == id) m_lib->setSource(QString());
        m_lib->setRemoteTracks(id, QVector<Track>());
        QFile::remove(tracksFile(id));
        QDir(cacheDir() + QStringLiteral("/covers/") + id).removeRecursively();
        save();
        touch();
        return;
    }
}

QString ServerManager::streamUrl(const QString &path) const
{
    if (!path.startsWith(QLatin1String("srv://"))) return {};
    const qsizetype slash = path.indexOf(QLatin1Char('/'), 6);
    if (slash < 0) return {};
    const Entry *e = find(path.mid(6, slash - 6));
    if (!e || !e->client || !e->info.enabled) return {};
    return e->client->streamUrl(path.mid(slash + 1));
}

bool ServerManager::allowsSelfSigned(const QString &path) const
{
    if (!path.startsWith(QLatin1String("srv://"))) return false;
    const qsizetype slash = path.indexOf(QLatin1Char('/'), 6);
    if (slash < 0) return false;
    const Entry *e = find(path.mid(6, slash - 6));
    return e && e->info.allowSelfSigned;
}

QString ServerManager::serverNameFor(const QString &path) const
{
    if (!path.startsWith(QLatin1String("srv://"))) return {};
    const qsizetype slash = path.indexOf(QLatin1Char('/'), 6);
    if (slash < 0) return {};
    const Entry *e = find(path.mid(6, slash - 6));
    return e ? e->info.name : QString();
}

// ---- cover pictures: cached on disk, fetched once -------------------------------------------

QString ServerManager::coverFile(const QString &serverId, const QString &coverId) const
{
    const QString h = QString::fromLatin1(QCryptographicHash::hash(coverId.toUtf8(), QCryptographicHash::Sha1).toHex());
    return cacheDir() + QStringLiteral("/covers/") + serverId + QLatin1Char('/') + h + QStringLiteral(".img");
}

void ServerManager::loadCover(const QString &serverId, const QString &coverId, std::function<void(const QImage &)> cb)
{
    Entry *e = find(serverId);
    if (!e || !e->client || coverId.isEmpty()) { cb(QImage()); return; }
    const QString file = coverFile(serverId, coverId);
    if (QFileInfo::exists(file)) { cb(QImage(file)); return; }
    auto &waiting = m_coverWaiters[file];
    waiting.push_back(std::move(cb));
    if (waiting.size() > 1) return;                       // already on its way
    QNetworkReply *r = e->client->fetch(e->client->coverRequest(coverId));
    connect(r, &QNetworkReply::finished, this, [this, r, file]() {
        r->deleteLater();
        QImage img;
        if (r->error() == QNetworkReply::NoError) {
            const QByteArray data = r->readAll();
            img = QImage::fromData(data);
            if (!img.isNull()) {
                QDir().mkpath(QFileInfo(file).path());
                QFile f(file);
                if (f.open(QIODevice::WriteOnly)) f.write(data);
            }
        }
        const auto callbacks = m_coverWaiters.take(file);
        for (const auto &fn : callbacks) fn(img);
    });
}

void ServerManager::fetchCover(const QString &id, const QSize &size, const QPointer<CoverResponse> &resp)
{
    const qsizetype slash = id.indexOf(QLatin1Char('/'));
    if (slash < 0) { deliver(resp, QImage(), QStringLiteral("bad cover id")); return; }
    const QString serverId = id.left(slash);
    const QString coverId = QString::fromUtf8(QByteArray::fromBase64(id.mid(slash + 1).toLatin1(),
                                              QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    loadCover(serverId, coverId, [resp, size](const QImage &img) {
        QImage out = img;
        if (!out.isNull() && size.width() > 0 && size.height() > 0 && (out.width() > size.width() || out.height() > size.height()))
            out = out.scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        deliver(resp, out, out.isNull() ? QStringLiteral("no cover") : QString());
    });
}

void ServerManager::pruneCovers() const
{
    QDirIterator it(cacheDir() + QStringLiteral("/covers"), QDir::Files, QDirIterator::Subdirectories);
    QList<QFileInfo> files;
    qint64 total = 0;
    while (it.hasNext()) {
        it.next();
        files << it.fileInfo();
        total += it.fileInfo().size();
    }
    constexpr qint64 kMax = qint64(300) << 20, kKeep = qint64(200) << 20;
    if (total <= kMax) return;
    std::sort(files.begin(), files.end(), [](const QFileInfo &a, const QFileInfo &b) { return a.lastModified() < b.lastModified(); });
    for (const QFileInfo &fi : std::as_const(files)) {
        if (total <= kKeep) break;
        total -= fi.size();
        QFile::remove(fi.filePath());
    }
}

QQuickImageResponse *RemoteCoverProvider::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    auto *r = new CoverResponse;
    const QPointer<CoverResponse> p(r);
    ServerManager *m = m_mgr;
    QMetaObject::invokeMethod(m, [m, id, requestedSize, p]() { m->fetchCover(id, requestedSize, p); }, Qt::QueuedConnection);
    return r;
}
