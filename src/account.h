#pragma once
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QObject>
#include <QPair>
#include <QSet>
#include <QTimer>
#include <QVariantMap>
#include <functional>

class Playlists;

// Username + password accounts on Supabase: sign up / in / out, profile, playlist sync.
class Account : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString username READ username NOTIFY changed)
    Q_PROPERTY(QString displayName READ displayName NOTIFY changed)
    Q_PROPERTY(QString bio READ bio NOTIFY changed)
    Q_PROPERTY(QString visibility READ visibility NOTIFY changed)
    Q_PROPERTY(bool discoverable READ discoverable NOTIFY changed)
    Q_PROPERTY(bool showPlaylists READ showPlaylists NOTIFY changed)
    Q_PROPERTY(bool syncPlaylists READ syncPlaylists WRITE setSyncPlaylists NOTIFY changed)
    Q_PROPERTY(QString avatarUrl READ avatarUrl NOTIFY changed)
    Q_PROPERTY(QString bannerUrl READ bannerUrl NOTIFY changed)
    Q_PROPERTY(bool bannerAnimated READ bannerAnimated NOTIFY changed)
    Q_PROPERTY(bool uploading READ uploading NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(QString lastSync READ lastSync NOTIFY changed)
public:
    explicit Account(Playlists *pl, QObject *parent = nullptr);

    bool signedIn() const { return !m_refresh.isEmpty() && !m_uid.isEmpty(); }
    bool busy() const { return m_busy || m_syncing || m_uploading; }
    bool uploading() const { return m_uploading; }
    // Local file URLs of the cached pictures (empty when there is none).
    QString avatarUrl() const { return m_avatarUrl; }
    QString bannerUrl() const { return m_bannerUrl; }
    bool bannerAnimated() const { return m_bannerPath.endsWith(QLatin1String(".gif"), Qt::CaseInsensitive); }
    QString username() const { return m_username; }
    QString displayName() const { return m_displayName; }
    QString bio() const { return m_bio; }
    QString visibility() const { return m_visibility; }
    bool discoverable() const { return m_discoverable; }
    bool showPlaylists() const { return m_showPlaylists; }
    bool syncPlaylists() const { return m_syncPlaylists; }
    void setSyncPlaylists(bool on);
    QString message() const { return m_message; }
    QString lastSync() const { return m_lastSync; }

    Q_INVOKABLE void signUp(const QString &username, const QString &password);
    Q_INVOKABLE void signIn(const QString &username, const QString &password);
    Q_INVOKABLE void signOut();
    Q_INVOKABLE void syncNow();
    Q_INVOKABLE void saveProfile(const QString &displayName, const QString &bio, const QString &visibility,
                                 bool discoverable, bool showPlaylists);
    // kind is "avatar" or "banner". source is a file path or file:// URL.
    Q_INVOKABLE void uploadImage(const QString &kind, const QString &source);
    Q_INVOKABLE void removeImage(const QString &kind);
    // Turns a pasted path / dropped URL into a file:// URL, or "" if there is no such file.
    Q_INVOKABLE QString localFileUrl(const QString &source) const;
    Q_INVOKABLE void exportData();
    Q_INVOKABLE void deleteAccount();

signals:
    void changed();
    void imageDone(const QString &kind, bool ok, const QString &text);

private:
    using Done = std::function<void(bool ok, const QJsonDocument &doc, int status)>;
    using Extra = QList<QPair<QByteArray, QByteArray>>;
    using Job = std::function<void(std::function<void(bool)>)>;

    void request(const QByteArray &verb, const QString &path, const QJsonDocument &body, const Done &done,
                 bool auth = true, const Extra &extra = {});
    void ensureToken(const std::function<void(bool)> &cb);
    void storeSession(const QJsonObject &o);
    void afterSignIn();
    void signOutLocal();
    void setMessage(const QString &m);
    void fail(const QString &m);
    void reconcile(const QJsonArray &remote);
    void queue(const QByteArray &verb, const QString &path, const QJsonDocument &body, const Extra &extra = {});
    void queuePush(const QVariantMap &pl);
    void runJobs();
    void finishSync(bool ok, const QString &err = {});
    void putObject(const QString &bucket, const QString &path, const QByteArray &data, const QByteArray &mime,
                   const Done &done);
    void removeObject(const QString &bucket, const QString &path);
    void purgeStorage(QStringList buckets, const std::function<void(bool)> &done);
    void loadImage(const QString &kind);
    void finishImage(const QString &kind, bool ok, const QString &text);
    QString cacheDir() const;

    QNetworkAccessManager m_net;
    Playlists *m_playlists;
    QTimer m_syncTimer;
    QList<Job> m_jobs;
    QString m_access, m_refresh, m_uid, m_username, m_displayName, m_bio, m_visibility = QStringLiteral("private");
    QString m_message, m_lastSync;
    QString m_avatarPath, m_bannerPath, m_avatarUrl, m_bannerUrl;   // storage path / cached file URL
    QSet<QString> m_fetching;
    qint64 m_expires = 0;
    bool m_uploading = false;
    bool m_busy = false, m_syncing = false, m_discoverable = false, m_showPlaylists = false, m_syncPlaylists = true;
};
