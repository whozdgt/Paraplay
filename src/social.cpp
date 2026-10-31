#include "social.h"

#include <QDateTime>
#include <QJsonArray>
#include <QRegularExpression>

#include "account.h"
#include "backend_config.h"
#include "library.h"
#include "player.h"

namespace {

QString str(const QJsonObject &o, const char *k) { return o.value(QLatin1String(k)).toString(); }
bool flag(const QJsonObject &o, const char *k) { return o.value(QLatin1String(k)).toBool(); }

// A number the database may have left out on purpose (null) -> -1.
int hiddenOr(const QJsonObject &o, const char *k)
{
    const QJsonValue v = o.value(QLatin1String(k));
    return v.isDouble() ? v.toInt() : -1;
}

qint64 parseIso(const QString &s)
{
    QString t = s;
    t.remove(QRegularExpression(QStringLiteral("\\.\\d+")));
    return QDateTime::fromString(t, Qt::ISODate).toMSecsSinceEpoch();
}

QString ago(const QString &iso)
{
    const qint64 then = parseIso(iso);
    const qint64 mins = (QDateTime::currentMSecsSinceEpoch() - then) / 60000;
    if (then <= 0 || mins < 1) return QStringLiteral("just now");
    if (mins < 60) return QStringLiteral("%1 min ago").arg(mins);
    return QStringLiteral("%1 h ago").arg(mins / 60);
}

QString songs(int n) { return n == 1 ? QStringLiteral("1 song") : QStringLiteral("%1 songs").arg(n); }

QString mmss(int ms)
{
    if (ms <= 0) return {};
    return QStringLiteral("%1:%2").arg(ms / 60000).arg((ms / 1000) % 60, 2, 10, QLatin1Char('0'));
}

void noReply(bool, const QJsonDocument &, int) {}

}   // namespace

Social::Social(Account *account, Library *library, Player *player, QObject *parent)
    : QObject(parent), m_acc(account), m_lib(library), m_player(player)
{
    m_poll.setInterval(60 * 1000);
    connect(&m_poll, &QTimer::timeout, this, [this] {
        if (!m_acc->signedIn()) return;
        if (m_watching) refresh(); else refreshRequests();
    });
    m_poll.start();

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(3000);
    connect(&m_debounce, &QTimer::timeout, this, &Social::publishNow);

    m_beat.setInterval(2 * 60 * 1000);
    connect(&m_beat, &QTimer::timeout, this, [this] { if (m_player->playing()) publishNow(); });
    m_beat.start();

    m_messageTimer.setSingleShot(true);
    m_messageTimer.setInterval(5000);
    connect(&m_messageTimer, &QTimer::timeout, this, [this] { m_message.clear(); emit messageChanged(); });

    connect(m_acc, &Account::changed, this, &Social::onAccountChanged);
    connect(m_player, &Player::trackChanged, this, &Social::onPlayback);
    connect(m_player, &Player::playingChanged, this, &Social::onPlayback);

    m_wasSignedIn = m_acc->signedIn();
    if (m_wasSignedIn) QTimer::singleShot(2500, this, &Social::refreshRequests);
}

// ---------------------------------------------------------------- plumbing

void Social::rpc(const char *fn, const QJsonObject &args, const Reply &done)
{
    m_acc->call("POST", QStringLiteral("/rest/v1/rpc/") + QLatin1String(fn), QJsonDocument(args), done);
}

void Social::setMessage(const QString &m)
{
    m_message = m;
    emit messageChanged();
    if (m.isEmpty()) m_messageTimer.stop(); else m_messageTimer.start();
}

void Social::failed(const QJsonDocument &d, int status)
{
    const QString code = d.object().value(QLatin1String("code")).toString();
    if (code == QLatin1String("PGRST202") || code == QLatin1String("42883") || code == QLatin1String("42P01"))
        setMessage(QStringLiteral("Friends needs a one-time database update first (supabase/social.sql)."));
    else if (status == 0)
        setMessage(QStringLiteral("Can't reach the server. Check your connection."));
    else
        setMessage(QStringLiteral("Something went wrong (code %1).").arg(status));
}

// Pictures of other people are public files; only their path comes from the database. Anything that does not look
// like one of our own upload names is ignored.
QString Social::storageUrl(const char *bucket, const QString &path) const
{
    static const QRegularExpression ok(QStringLiteral("^[0-9a-fA-F-]{36}/(avatar|banner)-\\d+\\.(png|jpg|jpeg|gif|webp)$"));
    if (!ok.match(path).hasMatch()) return {};
    return QString::fromLatin1(kSupabaseUrl) + QStringLiteral("/storage/v1/object/public/") + QLatin1String(bucket)
           + QLatin1Char('/') + path;
}

QVariantMap Social::person(const QJsonObject &o) const
{
    const QString user = str(o, "username");
    const QString shown = str(o, "display_name");
    QVariantMap m;
    m["id"] = str(o, "id");
    m["username"] = user;
    m["name"] = shown.isEmpty() ? user : shown;
    m["avatar"] = storageUrl("avatars", str(o, "avatar_path"));
    m["visibility"] = str(o, "visibility");
    m["state"] = str(o, "state");
    return m;
}

void Social::forgetEverything()
{
    m_results.clear(); m_following.clear(); m_requests.clear(); m_activity.clear();
    m_friendPlaylists.clear(); m_blocked.clear(); m_playlists.clear();
    m_profile.clear(); m_listening.clear(); m_playlist.clear(); m_matched.clear();
    m_openUser.clear(); m_lastQuery.clear(); m_searching = false;
    ++m_searchGen; ++m_profileGen; ++m_playlistGen;
    emit resultsChanged(); emit listsChanged(); emit profileChanged(); emit playlistChanged();
}

void Social::onAccountChanged()
{
    const bool in = m_acc->signedIn();
    if (in != m_wasSignedIn) {
        m_wasSignedIn = in;
        if (in) QTimer::singleShot(1500, this, &Social::refreshRequests);
        else forgetEverything();
    }
    const bool listening = in && m_acc->listeningPublic();
    if (listening != m_wasListening) {
        m_wasListening = listening;
        if (listening) m_debounce.start();          // just switched on: tell friends what is playing
        else if (in) clearNowPlaying();             // just switched off: take it down
    }
}

// ---------------------------------------------------------------- lists

void Social::watch(bool on)
{
    m_watching = on;
    if (on) refresh();
}

void Social::refreshRequests()
{
    if (!m_acc->signedIn()) return;
    rpc("social_requests", QJsonObject{}, [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { if (m_watching) failed(d, st); return; }
        m_requests.clear();
        for (const QJsonValue &v : d.array()) m_requests.push_back(person(v.toObject()));
        emit listsChanged();
    });
}

void Social::refresh()
{
    if (!m_acc->signedIn()) return;
    refreshRequests();
    rpc("social_following", QJsonObject{}, [this](bool ok, const QJsonDocument &d, int) {
        if (!ok) return;
        m_following.clear();
        for (const QJsonValue &v : d.array()) m_following.push_back(person(v.toObject()));
        emit listsChanged();
    });
    rpc("social_activity", QJsonObject{}, [this](bool ok, const QJsonDocument &d, int) {
        if (!ok) return;
        m_activity.clear();
        for (const QJsonValue &v : d.array()) {
            const QJsonObject o = v.toObject();
            QVariantMap m = person(o);
            m["title"] = str(o, "title");
            m["artist"] = str(o, "artist");
            m["quality"] = str(o, "quality");
            m["live"] = flag(o, "live");
            m["when"] = ago(str(o, "played_at"));
            m_activity.push_back(m);
        }
        emit listsChanged();
    });
    rpc("social_friend_playlists", QJsonObject{}, [this](bool ok, const QJsonDocument &d, int) {
        if (!ok) return;
        m_friendPlaylists.clear();
        for (const QJsonValue &v : d.array()) {
            const QJsonObject o = v.toObject();
            const QString name = str(o, "name");
            const QString user = str(o, "username");
            const QString shown = str(o, "display_name");
            const int n = o.value(QLatin1String("tracks")).toInt();
            m_friendPlaylists.push_back(QVariantMap{
                {"id", str(o, "id")}, {"name", name}, {"owner", user}, {"ownerName", shown.isEmpty() ? user : shown},
                {"count", n}, {"sub", songs(n)}, {"hue", int(qHash(name) % 360)}});
        }
        emit listsChanged();
    });
    rpc("social_blocked", QJsonObject{}, [this](bool ok, const QJsonDocument &d, int) {
        if (!ok) return;
        m_blocked.clear();
        for (const QJsonValue &v : d.array()) m_blocked.push_back(person(v.toObject()));
        emit listsChanged();
    });
}

void Social::search(const QString &q)
{
    const QString t = q.trimmed();
    m_lastQuery = t;
    const int gen = ++m_searchGen;
    m_results.clear();
    if (t.size() < 2 || !m_acc->signedIn()) { m_searching = false; emit resultsChanged(); return; }
    m_searching = true;
    emit resultsChanged();
    rpc("social_search", QJsonObject{{"q", t}}, [this, gen](bool ok, const QJsonDocument &d, int st) {
        if (gen != m_searchGen) return;
        m_searching = false;
        m_results.clear();
        if (ok) for (const QJsonValue &v : d.array()) m_results.push_back(person(v.toObject()));
        else failed(d, st);
        emit resultsChanged();
    });
}

// ---------------------------------------------------------------- one profile

void Social::openProfile(const QString &username, bool preview) { loadProfile(username, preview, false); }
void Social::reloadProfile() { if (!m_openUser.isEmpty()) loadProfile(m_openUser, m_openPreview, true); }

void Social::loadProfile(const QString &username, bool preview, bool quiet)
{
    if (!m_acc->signedIn()) return;
    m_openUser = username;
    m_openPreview = preview;
    const int gen = ++m_profileGen;
    if (!quiet) {
        m_profile = QVariantMap{{"username", username}, {"loading", true}, {"missing", false}};
        m_playlists.clear();
        m_listening.clear();
        emit profileChanged();
    }
    rpc("social_profile", QJsonObject{{"uname", username}}, [this, gen, preview](bool ok, const QJsonDocument &d, int st) {
        if (gen != m_profileGen) return;
        const QJsonArray rows = d.array();
        if (!ok || rows.isEmpty()) {          // not found, or one of you blocked the other
            if (!ok) failed(d, st);
            m_profile["loading"] = false;
            m_profile["missing"] = true;
            m_playlists.clear();
            m_listening.clear();
            emit profileChanged();
            return;
        }
        const QJsonObject o = rows.first().toObject();
        QVariantMap p = person(o);
        const bool self = str(o, "id") == m_acc->uid();
        bool locked = flag(o, "locked");
        int followers = hiddenOr(o, "followers"), following = hiddenOr(o, "following"), shared = hiddenOr(o, "playlists");
        QString bio = str(o, "bio");
        QString banner = str(o, "banner_path");
        bool listeningNow = flag(o, "listening");

        if (preview) {
            // Show your own profile the way a stranger would see it: the saved settings decide.
            p["state"] = QStringLiteral("none");
            if (m_acc->visibility() != QLatin1String("public")) {
                locked = true; bio.clear(); banner.clear(); followers = following = shared = -1;
            } else {
                if (!m_acc->showCounts()) followers = following = -1;
                if (!m_acc->showPlaylists()) shared = -1;
            }
        }
        if (locked) listeningNow = false;

        p["self"] = self && !preview;
        p["preview"] = preview;
        p["locked"] = locked;
        p["bio"] = bio;
        p["banner"] = storageUrl("banners", banner);
        p["animated"] = banner.endsWith(QLatin1String(".gif"), Qt::CaseInsensitive);
        p["followers"] = followers;
        p["following"] = following;
        p["playlistCount"] = shared;
        p["loading"] = false;
        p["missing"] = false;
        m_profile = p;
        if (locked || shared < 0) m_playlists.clear();
        if (!listeningNow) m_listening.clear();
        emit profileChanged();
        if (locked) return;

        const QString id = str(o, "id");
        if (shared >= 0)
            rpc("social_playlists", QJsonObject{{"owner_id", id}}, [this, gen](bool ok2, const QJsonDocument &d2, int) {
                if (gen != m_profileGen || !ok2) return;
                m_playlists.clear();
                for (const QJsonValue &v : d2.array()) {
                    const QJsonObject po = v.toObject();
                    const QString name = str(po, "name");
                    const int n = po.value(QLatin1String("tracks")).toInt();
                    m_playlists.push_back(QVariantMap{{"id", str(po, "id")}, {"name", name}, {"count", n},
                                                      {"sub", songs(n)}, {"hue", int(qHash(name) % 360)}});
                }
                emit profileChanged();
            });
        if (listeningNow)
            rpc("social_listening", QJsonObject{{"uid", id}}, [this, gen](bool ok2, const QJsonDocument &d2, int) {
                if (gen != m_profileGen || !ok2 || d2.array().isEmpty()) return;
                const QJsonObject lo = d2.array().first().toObject();
                m_listening = QVariantMap{{"title", str(lo, "title")}, {"artist", str(lo, "artist")}, {"quality", str(lo, "quality")}};
                emit profileChanged();
            });
    });
}

// ---------------------------------------------------------------- people

void Social::follow(const QString &id)
{
    rpc("social_follow", QJsonObject{{"target", id}}, [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { failed(d, st); return; }
        refresh(); reloadProfile(); if (!m_lastQuery.isEmpty()) search(m_lastQuery);
    });
}

void Social::unfollow(const QString &id)
{
    // Allowed by the "follows remove" rule: you may delete rows where you are the follower.
    m_acc->call("DELETE", QStringLiteral("/rest/v1/follows?follower=eq.") + m_acc->uid() + QStringLiteral("&followee=eq.") + id,
                QJsonDocument(), [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { failed(d, st); return; }
        refresh(); reloadProfile(); if (!m_lastQuery.isEmpty()) search(m_lastQuery);
    });
}

void Social::respond(const QString &id, bool accept)
{
    rpc("social_respond", QJsonObject{{"from_user", id}, {"accept", accept}}, [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { failed(d, st); return; }
        refresh();
    });
}

void Social::block(const QString &id)
{
    rpc("social_block", QJsonObject{{"target", id}}, [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { failed(d, st); return; }
        setMessage(QStringLiteral("Blocked. You can undo this under Requests."));
        refresh();
        reloadProfile();          // it will no longer open
        if (!m_lastQuery.isEmpty()) search(m_lastQuery);
    });
}

void Social::unblock(const QString &id)
{
    m_acc->call("DELETE", QStringLiteral("/rest/v1/blocks?blocker=eq.") + m_acc->uid() + QStringLiteral("&blocked=eq.") + id,
                QJsonDocument(), [this](bool ok, const QJsonDocument &d, int st) {
        if (!ok) { failed(d, st); return; }
        refresh();
    });
}

void Social::report(const QString &id, const QString &reason)
{
    const QString r = reason.trimmed().left(500);
    if (r.isEmpty() || !m_acc->signedIn()) return;
    m_acc->call("POST", QStringLiteral("/rest/v1/reports"),
                QJsonDocument(QJsonObject{{"reporter", m_acc->uid()}, {"target", id}, {"reason", r}}),
                [this](bool ok, const QJsonDocument &d, int st) {
        if (ok) setMessage(QStringLiteral("Thanks. We'll take a look."));
        else failed(d, st);
    }, {{"Prefer", "return=minimal"}});
}

// ---------------------------------------------------------------- a friend's playlist

void Social::openPlaylist(const QString &id, const QString &name, const QString &owner)
{
    if (!m_acc->signedIn()) return;
    const int gen = ++m_playlistGen;
    m_matched.clear();
    m_playlist = QVariantMap{{"id", id}, {"name", name}, {"owner", owner}, {"loading", true}, {"missing", false},
                             {"tracks", QVariantList()}, {"total", 0}, {"have", 0}};
    emit playlistChanged();
    rpc("social_playlist_tracks", QJsonObject{{"pid", id}}, [this, gen, id, name, owner](bool ok, const QJsonDocument &d, int st) {
        if (gen != m_playlistGen) return;
        if (!ok) failed(d, st);
        QVariantList tracks;
        QStringList paths;
        for (const QJsonValue &v : d.array()) {
            const QJsonObject o = v.toObject();
            const QString title = str(o, "title"), artist = str(o, "artist"), album = str(o, "album");
            const int ms = o.value(QLatin1String("duration_ms")).toInt();
            QVariantMap t{{"title", title}, {"artist", artist}, {"album", album}, {"time", mmss(ms)}};
            Track mine;
            if (m_lib->matchLoose(title, artist, album, ms, mine)) {
                t["matched"] = true;
                t["row"] = int(paths.size());          // its place in the queue when you press Play all
                t["badge"] = mine.badge();
                t["where"] = mine.isRemote() ? (m_serverName ? m_serverName(mine.path) : QStringLiteral("server"))
                                             : QStringLiteral("this computer");
                paths << mine.path;
            } else {
                t["matched"] = false;
                t["row"] = -1;
            }
            tracks.push_back(t);
        }
        m_matched = paths;
        m_playlist = QVariantMap{{"id", id}, {"name", name}, {"owner", owner}, {"loading", false}, {"missing", !ok || tracks.isEmpty()},
                                 {"tracks", tracks}, {"total", int(tracks.size())}, {"have", int(paths.size())}};
        emit playlistChanged();
    });
}

// ---------------------------------------------------------------- "listening now"
// Only when you switched "Show what I'm listening to" on. Title, artist and quality: never a file name or path.

void Social::onPlayback()
{
    if (m_acc->signedIn() && m_acc->listeningPublic() && m_player->hasTrack() && m_player->playing()) m_debounce.start();
}

void Social::publishNow()
{
    if (!m_acc->signedIn() || !m_acc->listeningPublic() || !m_player->hasTrack() || !m_player->playing()) return;
    if (m_player->title().isEmpty() && m_player->artist().isEmpty()) return;
    const QJsonObject row{{"user_id", m_acc->uid()},
                          {"title", m_player->title().left(200)},
                          {"artist", m_player->artist().left(200)},
                          {"quality", m_player->badge().left(40)},
                          {"updated_at", QDateTime::currentDateTimeUtc().toString(Qt::ISODate)}};
    m_acc->call("POST", QStringLiteral("/rest/v1/now_playing?on_conflict=user_id"), QJsonDocument(row), noReply,
                {{"Prefer", "resolution=merge-duplicates,return=minimal"}});
}

void Social::clearNowPlaying()
{
    if (!m_acc->signedIn()) return;
    m_acc->call("DELETE", QStringLiteral("/rest/v1/now_playing?user_id=eq.") + m_acc->uid(), QJsonDocument(), noReply);
}
