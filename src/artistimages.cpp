#include "artistimages.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {
QString norm(const QString &s)
{
    static const QRegularExpression re(QStringLiteral("[^\\p{L}\\p{N}]"));
    QString r = s.toLower();
    r.remove(re);
    return r;
}
}

ArtistImages::ArtistImages(QObject *parent) : QObject(parent)
{
    m_customDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/artist-photos";
    m_cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/artists";
    QDir().mkpath(m_customDir);
    QDir().mkpath(m_cacheDir);
}

QString ArtistImages::keyFor(const QString &name) const
{
    return QString::fromLatin1(QCryptographicHash::hash(norm(name).toUtf8(), QCryptographicHash::Sha1).toHex().left(16));
}

QString ArtistImages::url(const QString &name)
{
    if (name.trimmed().isEmpty()) return {};
    const QString k = keyFor(name);
    const QStringList custom = QDir(m_customDir).entryList({k + "-*.png"}, QDir::Files, QDir::Name);
    if (!custom.isEmpty()) return QUrl::fromLocalFile(m_customDir + "/" + custom.last()).toString();
    const QString cached = m_cacheDir + "/" + k + ".jpg";
    if (QFileInfo::exists(cached)) return QUrl::fromLocalFile(cached).toString();
    if (m_online && !m_queued.contains(k)) {
        const QFileInfo none(m_cacheDir + "/" + k + ".none");
        if (!none.exists() || none.lastModified().daysTo(QDateTime::currentDateTime()) > 30) {
            m_queued.insert(k);
            m_queue.enqueue({name, k});
            QTimer::singleShot(0, this, &ArtistImages::pump);
        }
    }
    return {};
}

void ArtistImages::markNone(const QString &k)
{
    QFile f(m_cacheDir + "/" + k + ".none");
    if (f.open(QIODevice::WriteOnly)) f.close();
}

void ArtistImages::finishJob()
{
    m_busy = false;
    QTimer::singleShot(200, this, &ArtistImages::pump);   // stay well under Deezer's rate limit
}

void ArtistImages::pump()
{
    if (m_busy || m_queue.isEmpty()) return;
    m_busy = true;
    const auto job = m_queue.dequeue();
    const QString name = job.first, k = job.second;
    QNetworkRequest rq(QUrl(QStringLiteral("https://api.deezer.com/search/artist?limit=5&q=")
                            + QString::fromLatin1(QUrl::toPercentEncoding(name))));
    rq.setHeader(QNetworkRequest::UserAgentHeader, "musicplayer");
    QNetworkReply *r = m_net.get(rq);
    connect(r, &QNetworkReply::finished, this, [this, r, name, k]() {
        r->deleteLater();
        QString pic;
        if (r->error() == QNetworkReply::NoError) {
            const QJsonArray arr = QJsonDocument::fromJson(r->readAll()).object().value(QLatin1String("data")).toArray();
            for (const QJsonValue &v : arr) {
                const QJsonObject o = v.toObject();
                if (norm(o.value(QLatin1String("name")).toString()) != norm(name)) continue;   // exact name only
                for (const char *f : {"picture_xl", "picture_big", "picture_medium"}) {
                    pic = o.value(QLatin1String(f)).toString();
                    if (!pic.isEmpty()) break;
                }
                break;
            }
        }
        if (pic.isEmpty() || pic.contains(QLatin1String("/artist//"))) { markNone(k); finishJob(); return; }
        QNetworkReply *ir = m_net.get(QNetworkRequest(QUrl(pic)));
        connect(ir, &QNetworkReply::finished, this, [this, ir, k]() {
            ir->deleteLater();
            QImage img;
            if (ir->error() == QNetworkReply::NoError) img.loadFromData(ir->readAll());
            if (img.isNull()) markNone(k);
            else {
                img.scaled(500, 500, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(m_cacheDir + "/" + k + ".jpg", "JPG", 85);
                ++m_rev;
                emit revisionChanged();
            }
            finishJob();
        });
    });
}

void ArtistImages::setCustom(const QString &name, const QString &source)
{
    QString path = source.trimmed();
    if (path.size() > 1 && (path.startsWith('\'') || path.startsWith('"'))) path = path.mid(1, path.size() - 2);
    if (path.startsWith(QLatin1String("file://"))) path = QUrl(path).toLocalFile();
    const QImage img(path);
    if (img.isNull()) return;
    const QString k = keyFor(name);
    for (const QString &f : QDir(m_customDir).entryList({k + "-*.png"}, QDir::Files)) QFile::remove(m_customDir + "/" + f);
    img.scaled(600, 600, Qt::KeepAspectRatio, Qt::SmoothTransformation)
        .save(m_customDir + "/" + k + "-" + QString::number(QDateTime::currentMSecsSinceEpoch()) + ".png", "PNG");
    ++m_rev;
    emit revisionChanged();
}

void ArtistImages::clearCustom(const QString &name)
{
    const QString k = keyFor(name);
    for (const QString &f : QDir(m_customDir).entryList({k + "-*.png"}, QDir::Files)) QFile::remove(m_customDir + "/" + f);
    ++m_rev;
    emit revisionChanged();
}
