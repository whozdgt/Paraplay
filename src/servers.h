#pragma once
#include <QHash>
#include <QImage>
#include <QJsonDocument>
#include <QList>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QQuickTextureFactory>
#include <QSet>
#include <QTimer>
#include <QVariantList>
#include <QVector>
#include <functional>
#include <memory>
#include <vector>

#include "types.h"

class Library;
class QNetworkReply;

struct ServerInfo {
    QString id, kind, name, url, user;      // kind: "subsonic" (Navidrome and friends) or "jellyfin"
    QString secret;                         // Subsonic: one-way sign-in token. Jellyfin: access token.
    QString salt;                           // Subsonic: the salt that token was made with
    QString userId;                         // Jellyfin: the user's id on the server
    QString pin;                            // SHA-256 of the self-signed certificate you chose to trust
    bool allowSelfSigned = false;
    bool enabled = true;
};

// One kind of media server. Subsonic/Navidrome and Jellyfin each implement this (see servers.cpp).
class ServerClient : public QObject {
    Q_OBJECT
public:
    using LoginDone = std::function<void(bool ok, const QString &detail)>;
    using TracksDone = std::function<void(bool ok, const QVector<Track> &tracks, const QString &err)>;
    using JsonDone = std::function<void(bool ok, const QJsonDocument &doc, const QString &err)>;

    ServerClient(const ServerInfo &info, QNetworkAccessManager *net, QObject *parent = nullptr);
    ~ServerClient() override;

    const ServerInfo &info() const { return m_info; }
    // Checks the sign-in. On success `detail` says what the server is ("Navidrome 0.53.3").
    virtual void login(const QString &password, const LoginDone &done) = 0;
    // Downloads the whole song list. `progress` gets the number of songs so far.
    virtual void fetchAll(const std::function<void(int)> &progress, const TracksDone &done) = 0;
    virtual QString streamUrl(const QString &itemId) const = 0;
    virtual QNetworkRequest coverRequest(const QString &coverId) const = 0;
    QNetworkReply *fetch(const QNetworkRequest &rq) { return send(rq); }

signals:
    void pinned(const QString &fingerprint);

protected:
    QNetworkReply *send(const QNetworkRequest &rq, const QByteArray &body = {}, bool post = false);
    void getJson(const QNetworkRequest &rq, const JsonDone &done, const QByteArray &body = {}, bool post = false);
    QString errorText(QNetworkReply *r) const;

    ServerInfo m_info;
    QNetworkAccessManager *m_net;
    QSet<QNetworkReply *> m_replies;
    bool m_certChanged = false;
};

// The answer to one cover-picture request from QML.
class CoverResponse : public QQuickImageResponse {
public:
    QQuickTextureFactory *textureFactory() const override
    {
        return m_img.isNull() ? nullptr : QQuickTextureFactory::textureFactoryForImage(m_img);
    }
    QString errorString() const override { return m_err; }
    void done(const QImage &img, const QString &err = {}) { m_img = img; m_err = err; emit finished(); }
private:
    QImage m_img;
    QString m_err;
};

// Your servers: saved settings, sign-in, song lists, and the bridge to the player and the cover pictures.
class ServerManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(int count READ count NOTIFY changed)
    Q_PROPERTY(bool testing READ testing NOTIFY changed)
public:
    explicit ServerManager(Library *lib, QObject *parent = nullptr);
    ~ServerManager() override;

    int revision() const { return m_rev; }
    int count() const { return int(m_servers.size()); }
    bool testing() const { return m_testing; }

    Q_INVOKABLE QVariantList list() const;
    Q_INVOKABLE QString sourceName(const QString &id) const;
    // Signs in. With addIt=false it only checks the details; with true it also saves the server and loads its songs.
    Q_INVOKABLE void connectServer(const QString &kind, const QString &name, const QString &url, const QString &user,
                                   const QString &password, bool allowSelfSigned, bool addIt);
    Q_INVOKABLE void syncNow(const QString &id = QString());     // empty = every server
    Q_INVOKABLE void setEnabled(const QString &id, bool on);
    Q_INVOKABLE void removeServer(const QString &id);

    // For the player.
    QString streamUrl(const QString &path) const;
    bool allowsSelfSigned(const QString &path) const;
    QString serverNameFor(const QString &path) const;
    // For covers: the picture is cached on disk, `cb` gets a null image if there is none.
    void loadCover(const QString &serverId, const QString &coverId, std::function<void(const QImage &)> cb);
    void fetchCover(const QString &id, const QSize &size, const QPointer<CoverResponse> &resp);

signals:
    void changed();
    void connectResult(bool ok, const QString &text, bool added);

private:
    struct Entry {
        ServerInfo info;
        ServerClient *client = nullptr;                 // owned through the QObject parent
        QString state = QStringLiteral("idle");         // idle | syncing | ok | error
        QString detail, error;
        int count = 0, progress = 0;
        qint64 lastSync = 0;
    };

    Entry *find(const QString &id) const;
    ServerClient *makeClient(const ServerInfo &si);
    void touch() { ++m_rev; emit changed(); }
    void sync(const QString &id);
    void load();
    void save() const;
    QString tracksFile(const QString &id) const;
    void saveTracks(const QString &id, const QVector<Track> &tracks) const;
    QVector<Track> loadTracks(const QString &id) const;
    QString coverFile(const QString &serverId, const QString &coverId) const;
    void pruneCovers() const;

    Library *m_lib;
    QNetworkAccessManager m_net;
    std::vector<std::unique_ptr<Entry>> m_servers;
    QHash<QString, QList<std::function<void(const QImage &)>>> m_coverWaiters;
    QTimer m_timer;
    int m_rev = 0;
    bool m_testing = false;
};

// image://remote/<server id>/<base64url(cover id)>
class RemoteCoverProvider : public QQuickAsyncImageProvider {
public:
    explicit RemoteCoverProvider(ServerManager *m) : m_mgr(m) {}
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;
private:
    ServerManager *m_mgr;
};
