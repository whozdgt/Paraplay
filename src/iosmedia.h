#pragma once
#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

class Player;

// iPhone only: lets music keep playing with the screen locked (the "playback" audio session), shows the song on the
// lock screen and in Control Centre, and passes their buttons (and headphone buttons) back to the player.
class IosMedia : public QObject {
    Q_OBJECT
public:
    explicit IosMedia(Player *player, QObject *parent = nullptr);
    ~IosMedia() override;

private:
    void schedule();
    void push();

    Player *m_p;
    QTimer m_delay;
    QElapsedTimer m_clock;
    double m_sentPos = 0;
    QString m_coverPath;
    void *m_artwork = nullptr;      // the cover as an MPMediaItemArtwork (retained)
    QList<void *> m_targets;        // what the remote commands hand back, to remove them again
    void *m_observer = nullptr;     // audio interruptions (a phone call)
};
