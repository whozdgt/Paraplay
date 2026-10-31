#pragma once
#include <QDataStream>
#include <QString>
#include <QStringView>

struct Track {
    QString path, title, artist, album, codec;
    QString cover;      // media-server songs: the server's id for the cover picture
    QString albumId;    // media-server songs: the server's album id (keeps same-named albums apart)
    int trackNo = 0, sampleRate = 0, bits = 0, bitrate = 0, lengthMs = 0;
    qint64 mtime = 0, size = 0;
    bool lossless = false;

    // Songs that live on a media server use "srv://<server id>/<item id>" as their path.
    bool isRemote() const { return path.startsWith(QLatin1String("srv://")); }
    bool fromServer(const QString &id) const
    {
        return isRemote() && path.size() > 6 + id.size() && path[6 + id.size()] == QLatin1Char('/')
            && QStringView(path).mid(6, id.size()) == QStringView(id);
    }
    QString serverId() const
    {
        if (!isRemote()) return {};
        const qsizetype e = path.indexOf(QLatin1Char('/'), 6);
        return path.mid(6, e < 0 ? -1 : e - 6);
    }
    QString itemId() const
    {
        if (!isRemote()) return {};
        const qsizetype e = path.indexOf(QLatin1Char('/'), 6);
        return e < 0 ? QString() : path.mid(e + 1);
    }

    bool hires() const { return lossless && (bits > 16 || sampleRate > 48000); }
    static QString khz(int hz) {
        return hz % 1000 == 0 ? QString::number(hz / 1000) : QString::number(hz / 1000.0, 'f', 1);
    }
    QString badge() const {
        if (lossless) {
            if (bits > 0 && sampleRate > 0) return QStringLiteral("%1 %2/%3").arg(codec).arg(bits).arg(khz(sampleRate));
            if (sampleRate > 0) return QStringLiteral("%1 %2k").arg(codec, khz(sampleRate));
            return codec;   // a server that doesn't tell us the rate
        }
        return bitrate > 0 ? QStringLiteral("%1 %2").arg(codec).arg(bitrate) : codec;
    }
    QString quality() const {
        if (lossless) {
            if (bits > 0 && sampleRate > 0) return QStringLiteral("%1-bit / %2 kHz").arg(bits).arg(khz(sampleRate));
            if (sampleRate > 0) return QStringLiteral("%1 kHz").arg(khz(sampleRate));
            return QStringLiteral("Lossless");
        }
        return bitrate > 0 ? QStringLiteral("%1 kbps").arg(bitrate) : QString();
    }
};

inline QDataStream &operator<<(QDataStream &s, const Track &t) {
    return s << t.path << t.title << t.artist << t.album << t.codec << t.cover << t.albumId << qint32(t.trackNo)
             << qint32(t.sampleRate) << qint32(t.bits) << qint32(t.bitrate) << qint32(t.lengthMs)
             << t.mtime << t.size << quint8(t.lossless);
}
inline QDataStream &operator>>(QDataStream &s, Track &t) {
    qint32 a, b, c, d, e; quint8 l;
    s >> t.path >> t.title >> t.artist >> t.album >> t.codec >> t.cover >> t.albumId >> a >> b >> c >> d >> e >> t.mtime >> t.size >> l;
    t.trackNo = a; t.sampleRate = b; t.bits = c; t.bitrate = d; t.lengthMs = e; t.lossless = l;
    return s;
}
