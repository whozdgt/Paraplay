#pragma once
#include <QColor>
#include <QImage>
#include <QObject>
#include <QStringList>
#include <QVector>
#include <functional>
#include <initializer_list>
#include <memory>

#include "library.h"

struct mpv_handle;

class Player : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hasTrack READ hasTrack NOTIFY trackChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double position READ position NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY trackChanged)
    Q_PROPERTY(QString title READ title NOTIFY trackChanged)
    Q_PROPERTY(QString artist READ artist NOTIFY trackChanged)
    Q_PROPERTY(QString album READ album NOTIFY trackChanged)
    Q_PROPERTY(QString path READ path NOTIFY trackChanged)
    Q_PROPERTY(QString source READ source NOTIFY trackChanged)   // name of the server the song streams from, or ""
    Q_PROPERTY(QString codec READ codec NOTIFY trackChanged)
    Q_PROPERTY(QString badge READ badge NOTIFY trackChanged)
    Q_PROPERTY(QString quality READ quality NOTIFY trackChanged)
    Q_PROPERTY(bool hires READ hires NOTIFY trackChanged)
    Q_PROPERTY(QString coverSource READ coverSource NOTIFY trackChanged)
    Q_PROPERTY(QColor glowA READ glowA NOTIFY trackChanged)
    Q_PROPERTY(QColor glowB READ glowB NOTIFY trackChanged)
    Q_PROPERTY(QStringList lyricLines READ lyricLines NOTIFY trackChanged)
    Q_PROPERTY(int lyricIndex READ lyricIndex NOTIFY lyricIndexChanged)
    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged)
public:
    // How the player reaches songs that live on a media server (set up once in main.cpp).
    struct RemoteHooks {
        std::function<QString(const QString &path)> url;            // song path -> address handed to mpv
        std::function<bool(const QString &path)> insecure;          // that server uses a self-signed certificate
        std::function<QString(const QString &path)> serverName;
        std::function<void(const Track &, std::function<void(const QImage &)>)> cover;   // for the album-colour glow
    };

    Player(Library *lib, bool bitPerfect, bool matchRate, QObject *parent = nullptr);
    ~Player() override;
    void setRemote(RemoteHooks hooks) { m_remote = std::move(hooks); }

    bool hasTrack() const { return m_tracks && m_cur >= 0 && m_cur < m_order.size(); }
    bool playing() const { return m_playing; }
    double position() const { return m_pos; }
    double duration() const { return m_dur; }
    QString title() const { return m_title; }
    QString artist() const { return m_artist; }
    QString album() const { return m_album; }
    QString path() const { return m_path; }
    QString source() const { return m_source; }
    QString codec() const { return m_codec; }
    QString badge() const { return m_badge; }
    QString quality() const { return m_quality; }
    bool hires() const { return m_hires; }
    QString coverSource() const { return m_cover; }
    QColor glowA() const { return m_glowA; }
    QColor glowB() const { return m_glowB; }
    QStringList lyricLines() const { return m_lyricLines; }
    int lyricIndex() const { return m_lyricIdx; }

    void setBitPerfect(bool on);
    int volume() const { return m_volume; }
    Q_INVOKABLE void setVolume(int v);

    Q_INVOKABLE void playRow(int viewRow);
    Q_INVOKABLE void toggle();
    Q_INVOKABLE void next();
    Q_INVOKABLE void prev();
    Q_INVOKABLE void seek(double seconds);
    void stop();

signals:
    void trackChanged();
    void playingChanged();
    void positionChanged();
    void lyricIndexChanged();
    void volumeChanged();

private:
    void handleEvents();
    void cmd(std::initializer_list<QByteArray> args);
    void startAt(int pos);
    void enqueueNext();
    void setPaused(bool p);
    void refreshPlaying();
    void updateCurrent();
    void loadLyrics(const QString &audioPath);
    void updateLyricIndex();
    QByteArray pathAt(int pos) const;
    void applyNetwork(int pos);

    Library *m_lib;
    mpv_handle *m_mpv = nullptr;
    std::shared_ptr<const QVector<Track>> m_tracks;
    QVector<int> m_order;
    int m_cur = -1;
    bool m_paused = true, m_idle = true, m_playing = false, m_bitPerfect;
    double m_pos = 0, m_dur = 0;
    QString m_title, m_artist, m_album, m_path, m_codec, m_badge, m_quality, m_cover, m_source;
    RemoteHooks m_remote;
    bool m_hires = false;
    QColor m_glowA{QStringLiteral("#f2994a")}, m_glowB{QStringLiteral("#963c82")};
    QStringList m_lyricLines;
    QVector<int> m_lyricTimes;
    int m_lyricIdx = -1;
    int m_volume = 100;
};
