#include "cover.h"

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>

#include <taglib/fileref.h>
#include <taglib/tvariant.h>

static QImage decode(QImageReader &r, const QSize &target) {
    QSize s = r.size();
    if (target.isValid() && s.isValid() && (s.width() > target.width() || s.height() > target.height())) {
        s.scale(target, Qt::KeepAspectRatio);
        r.setScaledSize(s);
    }
    return r.read();
}

QImage loadCover(const QString &path, const QSize &target)
{
    {
#ifdef Q_OS_WIN
        TagLib::FileRef f(reinterpret_cast<const wchar_t *>(path.utf16()), false);
#else
        const QByteArray enc = QFile::encodeName(path);
        TagLib::FileRef f(enc.constData(), false);
#endif
        if (!f.isNull()) {
            const auto pics = f.complexProperties("PICTURE");
            TagLib::ByteVector best;
            for (const auto &pic : pics) {
                TagLib::ByteVector bv = pic.value("data").toByteVector();
                if (bv.isEmpty()) continue;
                if (best.isEmpty() || pic.value("pictureType").toString() == "Front Cover") best = bv;
            }
            if (!best.isEmpty()) {
                QByteArray bytes(best.data(), int(best.size()));
                QBuffer buf(&bytes);
                buf.open(QIODevice::ReadOnly);
                QImageReader r(&buf);
                QImage img = decode(r, target);
                if (!img.isNull()) return img;
            }
        }
    }
    const QDir dir = QFileInfo(path).dir();
    for (const char *base : {"cover", "folder", "front", "album"})
        for (const char *ext : {"jpg", "jpeg", "png", "webp"}) {
            const QString p = dir.filePath(QString::fromLatin1(base) + "." + QLatin1String(ext));
            if (QFileInfo::exists(p)) {
                QImageReader r(p);
                QImage img = decode(r, target);
                if (!img.isNull()) return img;
            }
        }
    return {};
}

QString coverUrl(const QString &path)
{
    return QStringLiteral("image://cover/")
        + QString::fromLatin1(path.toUtf8().toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QString coverUrl(const Track &t)
{
    if (!t.isRemote()) return coverUrl(t.path);
    if (t.cover.isEmpty()) return {};
    return QStringLiteral("image://remote/") + t.serverId() + QLatin1Char('/')
        + QString::fromLatin1(t.cover.toUtf8().toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QImage CoverProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QString path = QString::fromUtf8(QByteArray::fromBase64(id.toLatin1(),
                          QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
    QImage img = loadCover(path, requestedSize.isValid() ? requestedSize : QSize(600, 600));
    if (size) *size = img.size();
    return img;
}
