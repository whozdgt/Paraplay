#include "folders.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QStringList>

namespace {

const QStringList &audioFilters()
{
    static const QStringList f{"*.flac", "*.mp3", "*.m4a", "*.mp4", "*.ogg", "*.oga", "*.opus", "*.wav", "*.aif", "*.aiff",
                               "*.ape", "*.wv", "*.aac", "*.wma"};
    return f;
}

QVariantMap place(const QString &name, const QString &path)
{
    return QVariantMap{{"name", name}, {"path", path}};
}

} // namespace

QVariantList FolderBrowser::roots() const
{
    QVariantList out;
    QStringList seen;
    const auto add = [&](const QString &name, const QString &path) {
        const QString p = QDir::cleanPath(path);
        if (p.isEmpty() || seen.contains(p) || !QFileInfo(p).isDir()) return;
        seen << p;
        out.push_back(place(name, p));
    };
#ifdef Q_OS_ANDROID
    add(QStringLiteral("Phone storage"), QStringLiteral("/storage/emulated/0"));
    for (const QStorageInfo &v : QStorageInfo::mountedVolumes()) {      // an SD card or USB drive
        const QString r = v.rootPath();
        if (r.startsWith(QLatin1String("/storage/")) && !r.startsWith(QLatin1String("/storage/emulated")) && v.isValid() && v.isReady())
            add(v.displayName().isEmpty() ? QStringLiteral("SD card") : v.displayName(), r);
    }
#elif defined(Q_OS_IOS)
    // the only place an iPhone app may look: its own folder (Files › On My iPhone › Paraplay)
    add(QStringLiteral("Paraplay folder"), QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation));
#elif defined(Q_OS_WIN)
    add(QStringLiteral("Music"), QStandardPaths::writableLocation(QStandardPaths::MusicLocation));
    add(QStringLiteral("Home"), QDir::homePath());
    for (const QFileInfo &d : QDir::drives()) {
        const QString r = d.absoluteFilePath();
        add(QStringLiteral("Drive ") + r.left(2), r);
    }
#else
    add(QStringLiteral("Music"), QStandardPaths::writableLocation(QStandardPaths::MusicLocation));
    add(QStringLiteral("Home"), QDir::homePath());
    for (const QStorageInfo &v : QStorageInfo::mountedVolumes()) {
        const QString r = v.rootPath();
        if ((r.startsWith(QLatin1String("/run/media/")) || r.startsWith(QLatin1String("/media/")) || r.startsWith(QLatin1String("/mnt/")))
            && v.isValid() && v.isReady())
            add(v.displayName().isEmpty() ? r : v.displayName(), r);
    }
    add(QStringLiteral("Whole computer"), QStringLiteral("/"));
#endif
    return out;
}

QVariantList FolderBrowser::list(const QString &dir) const
{
    QVariantList out;
    const QFileInfoList dirs = QDir(dir).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Readable,
                                                       QDir::Name | QDir::IgnoreCase | QDir::LocaleAware);
    for (const QFileInfo &fi : dirs) out.push_back(place(fi.fileName(), fi.absoluteFilePath()));
    return out;
}

QString FolderBrowser::parent(const QString &dir) const
{
    const QString d = QDir::cleanPath(dir);
    for (const QVariant &r : roots())
        if (QDir::cleanPath(r.toMap().value("path").toString()) == d) return {};
    const QString up = QFileInfo(d).absolutePath();
    return up == d ? QString() : up;
}

bool FolderBrowser::isDir(const QString &dir) const { return !dir.isEmpty() && QFileInfo(dir).isDir(); }

int FolderBrowser::audioCount(const QString &dir) const
{
    return int(QDir(dir).entryList(audioFilters(), QDir::Files | QDir::Readable, QDir::NoSort).size());
}
