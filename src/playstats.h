#pragma once
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

class Library;
class Player;

// Counts what you listen to, on this device only, so the Home page can show your top artists.
// A play counts once you have really listened to half the song or 30 seconds, whichever comes first.
// It is kept in a plain text file next to the other app data (one line per play: time, artist),
// and never leaves the device. Settings -> Home can wipe it.
class PlayStats : public QObject {
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(int total READ total NOTIFY changed)
public:
    PlayStats(Player *player, Library *library, QObject *parent = nullptr);

    int revision() const { return m_rev; }
    int total() const { return int(m_plays.size()); }
    // [{ name, plays }], most played first. days = 0 means all time.
    Q_INVOKABLE QVariantList topArtists(int days, int limit) const;
    Q_INVOKABLE void clear();

signals:
    void changed();

private:
    struct Play { qint64 when; QString artist; };

    void reset(const QString &path);
    void onTrack();
    void onPosition();
    void record();
    QString filePath() const;
    void load();

    Player *m_player;
    Library *m_lib;
    QVector<Play> m_plays;
    QString m_path;                 // the song being counted
    double m_lastPos = -1, m_listened = 0;
    bool m_counted = false;
    int m_rev = 0;
};
