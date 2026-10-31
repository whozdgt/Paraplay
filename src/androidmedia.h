#pragma once
#include <QByteArray>
#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

class Player;

// Phones only: mirrors what the player is doing into Android's media notification and lock screen
// (see android/src/io/github/whozdgt/paraplay/MediaService.java), and passes their buttons back to the player.
class AndroidMedia : public QObject {
    Q_OBJECT
public:
    explicit AndroidMedia(Player *player, QObject *parent = nullptr);

private:
    void schedule();
    void push();
    void onCommand(int cmd, qint64 arg);

    Player *m_p;
    QTimer m_delay;
    QElapsedTimer m_clock;
    double m_sentPos = 0;
    bool m_sentPlaying = false, m_active = false;
    QString m_coverPath;
    QByteArray m_cover;
};
