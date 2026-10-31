#pragma once
#include <QJsonDocument>
#include <QJsonObject>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class Account;
class Library;
class Player;

// Friends, public profiles, follow requests and "listening now".
//
// Privacy lives in the database, not here: every list below comes from a Supabase function that already left out
// whatever the viewer may not see (a Private profile's bio, banner, playlists and listening). This class only shows
// what it is given. Songs in a friend's playlist arrive as text (title, artist, album, length) and are matched
// against your own library, so no music file is ever sent or received.
class Social : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)      // "Find people"
    Q_PROPERTY(bool searching READ searching NOTIFY resultsChanged)
    Q_PROPERTY(QVariantList following READ following NOTIFY listsChanged)
    Q_PROPERTY(QVariantList requests READ requests NOTIFY listsChanged)      // people waiting for you to accept
    Q_PROPERTY(QVariantList activity READ activity NOTIFY listsChanged)      // what the people you follow are playing
    Q_PROPERTY(QVariantList friendPlaylists READ friendPlaylists NOTIFY listsChanged)   // playlists they chose to share
    Q_PROPERTY(QVariantList blocked READ blocked NOTIFY listsChanged)
    Q_PROPERTY(int requestCount READ requestCount NOTIFY listsChanged)
    Q_PROPERTY(QVariantMap profile READ profile NOTIFY profileChanged)       // the profile page that is open
    Q_PROPERTY(QVariantList playlists READ playlists NOTIFY profileChanged)
    Q_PROPERTY(QVariantMap listening READ listening NOTIFY profileChanged)
    Q_PROPERTY(QVariantMap playlist READ playlist NOTIFY playlistChanged)    // the friend's playlist that is open
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
public:
    Social(Account *account, Library *library, Player *player, QObject *parent = nullptr);
    // song path -> name of the media server it comes from (for "Home server" labels)
    void setServerName(std::function<QString(const QString &)> f) { m_serverName = std::move(f); }

    QVariantList results() const { return m_results; }
    bool searching() const { return m_searching; }
    QVariantList following() const { return m_following; }
    QVariantList requests() const { return m_requests; }
    QVariantList activity() const { return m_activity; }
    QVariantList friendPlaylists() const { return m_friendPlaylists; }
    QVariantList blocked() const { return m_blocked; }
    int requestCount() const { return int(m_requests.size()); }
    QVariantMap profile() const { return m_profile; }
    QVariantList playlists() const { return m_playlists; }
    QVariantMap listening() const { return m_listening; }
    QVariantMap playlist() const { return m_playlist; }
    QString message() const { return m_message; }

    Q_INVOKABLE void watch(bool on);                 // the Friends page is showing: keep it fresh
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void search(const QString &q);
    Q_INVOKABLE void openProfile(const QString &username, bool preview = false);
    Q_INVOKABLE void follow(const QString &id);
    Q_INVOKABLE void unfollow(const QString &id);    // also cancels a request you sent
    Q_INVOKABLE void respond(const QString &id, bool accept);
    Q_INVOKABLE void block(const QString &id);
    Q_INVOKABLE void unblock(const QString &id);
    Q_INVOKABLE void report(const QString &id, const QString &reason);
    Q_INVOKABLE void openPlaylist(const QString &id, const QString &name, const QString &owner);
    Q_INVOKABLE QStringList matchedPaths() const { return m_matched; }

signals:
    void resultsChanged();
    void listsChanged();
    void profileChanged();
    void playlistChanged();
    void messageChanged();

private:
    using Reply = std::function<void(bool ok, const QJsonDocument &doc, int status)>;
    void rpc(const char *fn, const QJsonObject &args, const Reply &done);
    void refreshRequests();
    void reloadProfile();
    void loadProfile(const QString &username, bool preview, bool quiet);
    void setMessage(const QString &m);
    void failed(const QJsonDocument &d, int status);
    QVariantMap person(const QJsonObject &o) const;
    QString storageUrl(const char *bucket, const QString &path) const;
    void onAccountChanged();
    void onPlayback();
    void publishNow();
    void clearNowPlaying();
    void forgetEverything();

    Account *m_acc;
    Library *m_lib;
    Player *m_player;
    std::function<QString(const QString &)> m_serverName;

    QVariantList m_results, m_following, m_requests, m_activity, m_friendPlaylists, m_blocked, m_playlists;
    QVariantMap m_profile, m_listening, m_playlist;
    QStringList m_matched;
    QString m_message, m_lastQuery, m_openUser;
    bool m_searching = false, m_watching = false, m_openPreview = false;
    bool m_wasSignedIn = false, m_wasListening = false;
    int m_searchGen = 0, m_profileGen = 0, m_playlistGen = 0;

    QTimer m_poll;          // refreshes the Friends page and the "requests" badge
    QTimer m_debounce;      // waits a moment after a song change before telling friends
    QTimer m_beat;          // keeps "listening now" fresh during a long song
    QTimer m_messageTimer;
};
