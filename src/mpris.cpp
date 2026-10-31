#include "mpris.h"

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>

#include "player.h"

void MprisRoot::Quit() { QCoreApplication::quit(); }

MprisPlayer::MprisPlayer(Player *p, QObject *parent) : QDBusAbstractAdaptor(parent), m_p(p) {}

QString MprisPlayer::status() const
{
    if (!m_p->hasTrack()) return QStringLiteral("Stopped");
    return m_p->playing() ? QStringLiteral("Playing") : QStringLiteral("Paused");
}

QVariantMap MprisPlayer::metadata() const
{
    QVariantMap m;
    if (!m_p->hasTrack()) {
        m["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath("/org/mpris/MediaPlayer2/TrackList/NoTrack"));
        return m;
    }
    m["mpris:trackid"] = QVariant::fromValue(QDBusObjectPath("/org/mpris/MediaPlayer2/Track/1"));
    m["mpris:length"] = qlonglong(m_p->duration() * 1e6);
    m["xesam:title"] = m_p->title();
    m["xesam:artist"] = QStringList{m_p->artist()};
    m["xesam:album"] = m_p->album();
    return m;
}

qlonglong MprisPlayer::position() const { return qlonglong(m_p->position() * 1e6); }

void MprisPlayer::Next() { m_p->next(); }
void MprisPlayer::Previous() { m_p->prev(); }
void MprisPlayer::Pause() { if (m_p->playing()) m_p->toggle(); }
void MprisPlayer::PlayPause() { m_p->toggle(); }
void MprisPlayer::Stop() { m_p->stop(); }
void MprisPlayer::Play() { if (!m_p->playing()) m_p->toggle(); }
void MprisPlayer::Seek(qlonglong offsetUs) { m_p->seek(m_p->position() + offsetUs / 1e6); }
void MprisPlayer::SetPosition(const QDBusObjectPath &, qlonglong posUs) { m_p->seek(posUs / 1e6); }

Mpris::Mpris(Player *p) : QObject(p), m_player(p)
{
    new MprisRoot(this);
    m_pl = new MprisPlayer(p, this);
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.registerService(QStringLiteral("org.mpris.MediaPlayer2.musicplayer"));
    bus.registerObject(QStringLiteral("/org/mpris/MediaPlayer2"), this, QDBusConnection::ExportAdaptors);
    connect(p, &Player::trackChanged, this, &Mpris::refresh);
    connect(p, &Player::playingChanged, this, &Mpris::refresh);
}

void Mpris::refresh()
{
    QVariantMap changed;
    changed["PlaybackStatus"] = m_pl->status();
    changed["Metadata"] = m_pl->metadata();
    QDBusMessage sig = QDBusMessage::createSignal(QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("PropertiesChanged"));
    sig << QStringLiteral("org.mpris.MediaPlayer2.Player") << changed << QStringList();
    QDBusConnection::sessionBus().send(sig);
}
