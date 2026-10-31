#pragma once
// Minimal MPRIS2 so media keys, playerctl and waybar's media module work.
#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QStringList>
#include <QVariantMap>

class Player;

class MprisRoot : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(bool CanQuit READ yes CONSTANT)
    Q_PROPERTY(bool CanRaise READ no CONSTANT)
    Q_PROPERTY(bool HasTrackList READ no CONSTANT)
    Q_PROPERTY(QString Identity READ identity CONSTANT)
    Q_PROPERTY(QString DesktopEntry READ identityId CONSTANT)
    Q_PROPERTY(QStringList SupportedUriSchemes READ none CONSTANT)
    Q_PROPERTY(QStringList SupportedMimeTypes READ none CONSTANT)
public:
    explicit MprisRoot(QObject *parent) : QDBusAbstractAdaptor(parent) {}
    bool yes() const { return true; }
    bool no() const { return false; }
    QString identity() const { return QStringLiteral("Music"); }
    QString identityId() const { return QStringLiteral("musicplayer"); }
    QStringList none() const { return {}; }
public slots:
    void Quit();
    void Raise() {}
};

class MprisPlayer : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ status)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(qlonglong Position READ position)
    Q_PROPERTY(double Rate READ one)
    Q_PROPERTY(double MinimumRate READ one)
    Q_PROPERTY(double MaximumRate READ one)
    Q_PROPERTY(double Volume READ one)
    Q_PROPERTY(bool CanGoNext READ yes)
    Q_PROPERTY(bool CanGoPrevious READ yes)
    Q_PROPERTY(bool CanPlay READ yes)
    Q_PROPERTY(bool CanPause READ yes)
    Q_PROPERTY(bool CanSeek READ yes)
    Q_PROPERTY(bool CanControl READ yes)
public:
    MprisPlayer(Player *p, QObject *parent);
    QString status() const;
    QVariantMap metadata() const;
    qlonglong position() const;
    double one() const { return 1.0; }
    bool yes() const { return true; }
public slots:
    void Next();
    void Previous();
    void Pause();
    void PlayPause();
    void Stop();
    void Play();
    void Seek(qlonglong offsetUs);
    void SetPosition(const QDBusObjectPath &track, qlonglong posUs);
    void OpenUri(const QString &) {}
private:
    Player *m_p;
};

class Mpris : public QObject {
    Q_OBJECT
public:
    explicit Mpris(Player *p);
private:
    void refresh();
    Player *m_player;
    MprisPlayer *m_pl;
};
