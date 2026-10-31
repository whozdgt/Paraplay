#include "androidmedia.h"

#include <QBuffer>
#include <QImage>
#include <QSettings>

#include "android.h"
#include "cover.h"
#include "player.h"

AndroidMedia::AndroidMedia(Player *player, QObject *parent) : QObject(parent), m_p(player)
{
    m_delay.setSingleShot(true);
    m_delay.setInterval(150);          // a song change fires several signals in a row; send one update
    connect(&m_delay, &QTimer::timeout, this, &AndroidMedia::push);
    connect(m_p, &Player::trackChanged, this, &AndroidMedia::schedule);
    connect(m_p, &Player::playingChanged, this, &AndroidMedia::schedule);
    connect(m_p, &Player::positionChanged, this, [this]() {
        // a seek: the position jumps away from where the notification expects it to be
        if (!m_p->playing() || !m_clock.isValid()) return;
        const double expected = m_sentPos + m_clock.elapsed() / 1000.0;
        if (qAbs(m_p->position() - expected) > 1.5) schedule();
    });
    android::mediaInit([this](int cmd, qint64 arg) { onCommand(cmd, arg); });
}

AndroidMedia::~AndroidMedia() { android::mediaDetach(); }

void AndroidMedia::schedule() { m_delay.start(); }

void AndroidMedia::push()
{
    if (!m_p->hasTrack()) {
        if (m_active) { android::mediaStop(); m_active = false; m_sentPlaying = false; }
        return;
    }
    // The first time something plays, ask once whether notifications are allowed, so the controls can be shown.
    if (m_p->playing() && !android::notificationsAllowed()) {
        QSettings st;
        if (!st.value("askedNotifications", false).toBool()) {
            st.setValue("askedNotifications", true);
            android::askNotifications();
        }
    }
    const QString path = m_p->path();
    const bool streaming = path.startsWith(QLatin1String("srv://"));
    if (path != m_coverPath || m_cover.isEmpty()) {
        QImage img = streaming ? m_p->coverImage() : loadCover(path, QSize(512, 512));
        m_cover.clear();
        if (!img.isNull()) {
            if (img.width() > 512 || img.height() > 512) img = img.scaled(512, 512, Qt::KeepAspectRatio, Qt::SmoothTransformation);
            QBuffer buf(&m_cover);
            buf.open(QIODevice::WriteOnly);
            img.convertToFormat(QImage::Format_RGB32).save(&buf, "JPEG", 85);
        }
        m_coverPath = path;
    }
    m_sentPos = m_p->position();
    m_clock.start();
    m_sentPlaying = m_p->playing();
    m_active = true;
    android::mediaUpdate(m_p->title(), m_p->artist(), m_p->album(), qint64(m_p->duration() * 1000), qint64(m_sentPos * 1000),
                         m_sentPlaying, streaming, m_cover);
}

void AndroidMedia::onCommand(int cmd, qint64 arg)
{
    switch (cmd) {
    case 0: if (!m_p->playing()) m_p->toggle(); break;           // play
    case 1: if (m_p->playing()) m_p->toggle(); break;            // pause
    case 2: m_p->next(); break;
    case 3: m_p->prev(); break;
    case 4: m_p->seek(double(arg) / 1000.0); break;
    case 5: if (m_p->playing()) m_p->toggle(); break;            // stop
    default: break;
    }
}
