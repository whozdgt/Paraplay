#include "player.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QRegularExpression>
#include <algorithm>
#include <cmath>
#include <vector>

#include <mpv/client.h>

#include "cover.h"

namespace {

// Pick two vivid, different hues from a tiny copy of the cover art.
void dominant(const QImage &src, QColor &a, QColor &b)
{
    a = QColor(QStringLiteral("#f2994a"));
    b = QColor(QStringLiteral("#963c82"));
    if (src.isNull()) return;
    const QImage s = src.scaled(24, 24, Qt::IgnoreAspectRatio, Qt::FastTransformation).convertToFormat(QImage::Format_RGB32);
    struct Bin { double w = 0, r = 0, g = 0, b = 0; } bins[12];
    for (int y = 0; y < s.height(); ++y)
        for (int x = 0; x < s.width(); ++x) {
            const QColor c = s.pixelColor(x, y);
            const double h = c.hsvHueF();
            if (h < 0) continue;
            const double w = c.hsvSaturationF() * c.valueF();
            if (w < 0.05) continue;
            Bin &bin = bins[int(h * 12) % 12];
            bin.w += w; bin.r += c.redF() * w; bin.g += c.greenF() * w; bin.b += c.blueF() * w;
        }
    int i1 = -1, i2 = -1;
    for (int i = 0; i < 12; ++i) if (bins[i].w > 0 && (i1 < 0 || bins[i].w > bins[i1].w)) i1 = i;
    if (i1 < 0) return;
    for (int i = 0; i < 12; ++i) {
        const int d = std::min((i - i1 + 12) % 12, (i1 - i + 12) % 12);
        if (d >= 2 && bins[i].w > 0 && (i2 < 0 || bins[i].w > bins[i2].w)) i2 = i;
    }
    const auto col = [](const Bin &x) { return QColor::fromRgbF(x.r / x.w, x.g / x.w, x.b / x.w); };
    a = col(bins[i1]);
    if (i2 >= 0) b = col(bins[i2]);
    else b = QColor::fromHsvF(std::fmod(a.hsvHueF() + 0.12, 1.0), a.hsvSaturationF(), a.valueF());
}

} // namespace

Player::Player(Library *lib, bool bitPerfect, bool matchRate, QObject *parent)
    : QObject(parent), m_lib(lib), m_bitPerfect(bitPerfect)
{
    m_mpv = mpv_create();
    if (!m_mpv) { qWarning("Music: mpv_create() failed, playback is disabled"); return; }
    const auto o = [this](const char *k, const char *v) { mpv_set_option_string(m_mpv, k, v); };
    o("config", "no");
    o("terminal", "no");
    o("idle", "yes");
    o("vid", "no");
    o("audio-display", "no");
    o("load-scripts", "no");
    o("osc", "no");
    o("input-default-bindings", "no");
    o("input-vo-keyboard", "no");
    o("ytdl", "no");
    o("network-timeout", "20");
    o("audio-client-name", "Music");
    o("gapless-audio", "yes");
    o("prefetch-playlist", "yes");
    o("demuxer-max-bytes", "4MiB");        // keep memory small
    o("demuxer-max-back-bytes", "0");
    o("volume-max", "100");
    o("volume", "100");
    o("replaygain", bitPerfect ? "no" : "track");
    if (!matchRate) o("audio-samplerate", "48000");   // otherwise: follow the file's rate
#ifdef Q_OS_LINUX
    o("ao", "pipewire,pulse,alsa");
#endif
    // https streams from your own server: check certificates against the system's list of authorities.
    for (const char *ca : {"/etc/ssl/certs/ca-certificates.crt", "/etc/pki/tls/certs/ca-bundle.crt", "/etc/ssl/cert.pem"})
        if (QFileInfo::exists(QLatin1String(ca))) { o("tls-ca-file", ca); break; }
    o("tls-verify", "yes");
    const int rc = mpv_initialize(m_mpv);
    if (rc < 0) { qWarning("Music: mpv_initialize failed: %s", mpv_error_string(rc)); mpv_destroy(m_mpv); m_mpv = nullptr; return; }
    mpv_request_log_messages(m_mpv, "warn");
    mpv_observe_property(m_mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "idle-active", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "playlist-pos", MPV_FORMAT_INT64);
    mpv_set_wakeup_callback(m_mpv, [](void *ctx) {
        QMetaObject::invokeMethod(static_cast<Player *>(ctx), &Player::handleEvents, Qt::QueuedConnection);
    }, this);
}

Player::~Player()
{
    if (!m_mpv) return;
    mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
    mpv_terminate_destroy(m_mpv);
}

void Player::setBitPerfect(bool on)
{
    m_bitPerfect = on;
    if (!m_mpv) return;
    mpv_set_property_string(m_mpv, "replaygain", on ? "no" : "track");
}

void Player::setVolume(int v)
{
    v = std::clamp(v, 0, 100);
    m_volume = v;
    if (m_mpv) mpv_set_property_string(m_mpv, "volume", QByteArray::number(v).constData());
    emit volumeChanged();
}

void Player::cmd(std::initializer_list<QByteArray> args)
{
    if (!m_mpv) return;
    std::vector<const char *> v;
    for (const QByteArray &a : args) v.push_back(a.constData());
    v.push_back(nullptr);
    mpv_command(m_mpv, v.data());
}

QByteArray Player::pathAt(int pos) const
{
    const Track &t = (*m_tracks)[m_order[pos]];
    if (!t.isRemote()) return t.path.toUtf8();
    return m_remote.url ? m_remote.url(t.path).toUtf8() : QByteArray();
}

// Streams get a bigger read-ahead, and servers with a self-signed certificate are let through.
void Player::applyNetwork(int pos)
{
    if (!m_mpv) return;
    const Track &t = (*m_tracks)[m_order[pos]];
    const bool insecure = t.isRemote() && m_remote.insecure && m_remote.insecure(t.path);
    mpv_set_property_string(m_mpv, "tls-verify", insecure ? "no" : "yes");
    mpv_set_property_string(m_mpv, "demuxer-max-bytes", t.isRemote() ? "16MiB" : "4MiB");
}

void Player::playRow(int viewRow)
{
    const Library::Snapshot s = m_lib->snapshot();
    if (viewRow < 0 || viewRow >= s.order.size()) return;
    m_tracks = s.tracks;
    m_order = s.order;
    startAt(viewRow);
}

void Player::startAt(int pos)
{
    if (!m_mpv) { qWarning("Music: cannot play, mpv is not available"); return; }
    if (!m_tracks || pos < 0 || pos >= m_order.size()) return;
    const QByteArray file = pathAt(pos);
    if (file.isEmpty()) { qWarning("Music: that song's server isn't available"); return; }
    m_cur = pos;
    applyNetwork(pos);
    cmd({"loadfile", file, "replace"});
    enqueueNext();
    setPaused(false);
    updateCurrent();
}

void Player::enqueueNext()
{
    if (m_cur + 1 >= m_order.size()) return;
    const QByteArray file = pathAt(m_cur + 1);
    if (file.isEmpty()) return;
    applyNetwork(m_cur + 1);
    cmd({"loadfile", file, "append"});
}

void Player::setPaused(bool p)
{
    if (!m_mpv) return;
    int f = p ? 1 : 0;
    mpv_set_property(m_mpv, "pause", MPV_FORMAT_FLAG, &f);
}

void Player::toggle()
{
    if (!hasTrack()) return;
    if (m_idle) { startAt(m_cur); return; }
    setPaused(m_playing);
}

void Player::next() { if (hasTrack() && m_cur + 1 < m_order.size()) startAt(m_cur + 1); }

void Player::prev()
{
    if (!hasTrack()) return;
    if (m_pos > 3.0 || m_cur == 0) seek(0);
    else startAt(m_cur - 1);
}

void Player::stop()
{
    if (!m_mpv) return;
    cmd({"stop"});
}

void Player::seek(double seconds)
{
    if (!hasTrack()) return;
    seconds = std::clamp(seconds, 0.0, m_dur > 0 ? m_dur : seconds);
    cmd({"seek", QByteArray::number(seconds, 'f', 3), "absolute"});
    m_pos = seconds;
    emit positionChanged();
    updateLyricIndex();
}

void Player::refreshPlaying()
{
    const bool p = !m_paused && !m_idle && m_cur >= 0;
    if (p != m_playing) { m_playing = p; emit playingChanged(); }
}

void Player::handleEvents()
{
    while (m_mpv) {
        mpv_event *e = mpv_wait_event(m_mpv, 0);
        if (e->event_id == MPV_EVENT_NONE) break;
        if (e->event_id == MPV_EVENT_LOG_MESSAGE) {
            auto *lm = static_cast<mpv_event_log_message *>(e->data);
            // never print the sign-in token that is part of a stream address
            static const QRegularExpression secret(QStringLiteral("([?&](?:t|s|u|api_key|ApiKey|DeviceId)=)[^&\\s]+"));
            QString text = QString::fromUtf8(QByteArray(lm->text).trimmed());
            text.replace(secret, QStringLiteral("\\1***"));
            qWarning("mpv [%s] %s", lm->prefix, text.toUtf8().constData());
            continue;
        }
        if (e->event_id != MPV_EVENT_PROPERTY_CHANGE) continue;
        auto *p = static_cast<mpv_event_property *>(e->data);
        const QByteArray name(p->name);
        if (name == "time-pos" && p->format == MPV_FORMAT_DOUBLE) {
            const double v = *static_cast<double *>(p->data);
            if (v < m_pos || v - m_pos >= 0.25) { m_pos = v; emit positionChanged(); updateLyricIndex(); }
        } else if (name == "pause" && p->format == MPV_FORMAT_FLAG) {
            m_paused = *static_cast<int *>(p->data) != 0;
            refreshPlaying();
        } else if (name == "idle-active" && p->format == MPV_FORMAT_FLAG) {
            m_idle = *static_cast<int *>(p->data) != 0;
            if (m_idle) { m_pos = 0; emit positionChanged(); }
            refreshPlaying();
        } else if (name == "playlist-pos" && p->format == MPV_FORMAT_INT64) {
            // Entry 1 started = the prefetched next track began (gapless advance).
            if (*static_cast<int64_t *>(p->data) == 1 && m_cur + 1 < m_order.size()) {
                ++m_cur;
                cmd({"playlist-remove", "0"});
                enqueueNext();
                updateCurrent();
            }
        }
    }
}

void Player::updateCurrent()
{
    const Track &t = (*m_tracks)[m_order[m_cur]];
    m_title = t.title; m_artist = t.artist; m_album = t.album; m_path = t.path;
    m_codec = t.codec; m_badge = t.badge(); m_quality = t.quality(); m_hires = t.hires();
    m_dur = t.lengthMs / 1000.0;
    m_pos = 0;
    m_cover = coverUrl(t);
    m_source = (t.isRemote() && m_remote.serverName) ? m_remote.serverName(t.path) : QString();
    if (t.isRemote()) {
        dominant(QImage(), m_glowA, m_glowB);            // default colours until the cover has arrived
        m_lyricLines.clear();
        m_lyricTimes.clear();
        if (m_remote.cover) {
            const QString playing = t.path;
            m_remote.cover(t, [this, playing](const QImage &img) {
                if (img.isNull() || m_path != playing) return;
                dominant(img, m_glowA, m_glowB);
                emit trackChanged();
            });
        }
    } else {
        dominant(loadCover(t.path, QSize(64, 64)), m_glowA, m_glowB);
        loadLyrics(t.path);
    }
    m_lyricIdx = -1;
    emit trackChanged();
    emit positionChanged();
    emit lyricIndexChanged();
    refreshPlaying();
}

void Player::loadLyrics(const QString &audioPath)
{
    m_lyricLines.clear();
    m_lyricTimes.clear();
    const QFileInfo fi(audioPath);
    QFile f(fi.path() + "/" + fi.completeBaseName() + ".lrc");
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    static const QRegularExpression re(QStringLiteral(R"(\[(\d+):(\d+)(?:[.:](\d+))?\])"));
    QVector<std::pair<int, QString>> items;
    while (!f.atEnd()) {
        const QString line = QString::fromUtf8(f.readLine()).trimmed();
        QVector<int> times;
        qsizetype last = 0;
        auto it = re.globalMatch(line);
        while (it.hasNext()) {
            const auto m = it.next();
            int ms = m.captured(1).toInt() * 60000 + m.captured(2).toInt() * 1000;
            const QString frac = m.captured(3);
            if (!frac.isEmpty()) ms += frac.leftJustified(3, QLatin1Char('0')).left(3).toInt();
            times.push_back(ms);
            last = m.capturedEnd();
        }
        if (times.isEmpty()) continue;
        const QString text = line.mid(last).trimmed();
        for (int ms : times) items.push_back({ms, text});
    }
    std::stable_sort(items.begin(), items.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    for (const auto &it : items) { m_lyricTimes.push_back(it.first); m_lyricLines << it.second; }
}

void Player::updateLyricIndex()
{
    if (m_lyricTimes.isEmpty()) return;
    const int ms = int(m_pos * 1000);
    const int idx = int(std::upper_bound(m_lyricTimes.begin(), m_lyricTimes.end(), ms) - m_lyricTimes.begin()) - 1;
    if (idx != m_lyricIdx) { m_lyricIdx = idx; emit lyricIndexChanged(); }
}
