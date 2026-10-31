#include "updater.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVersionNumber>

#include "update_config.h"
#ifdef Q_OS_ANDROID
#include "android.h"
#endif

#ifndef PARAPLAY_BUILD
#define PARAPLAY_BUILD 0
#endif

UpdateChecker::UpdateChecker(QObject *parent) : QObject(parent), m_exe(QCoreApplication::applicationFilePath()) {}

QString UpdateChecker::current() const
{
#ifdef Q_OS_ANDROID
    return QStringLiteral(APP_VERSION " (build %1)").arg(PARAPLAY_BUILD);
#else
    return QStringLiteral(APP_VERSION);
#endif
}

bool UpdateChecker::configured() const { return kUpdateRepo[0] != '\0'; }

QString UpdateChecker::scriptPath() const
{
    return QDir::cleanPath(QCoreApplication::applicationDirPath() + QStringLiteral("/../share/musicplayer/musicplayer-update"));
}

// In-app installing works once the player was installed by update.sh (it puts the script in place).
bool UpdateChecker::canInstall() const
{
#ifdef Q_OS_ANDROID
    return configured();
#else
    return configured() && QFileInfo::exists(scriptPath());
#endif
}

void UpdateChecker::setStatus(const QString &s)
{
    m_status = s;
    emit changed();
}

void UpdateChecker::checkOnStart(bool enabled)
{
    if (!enabled || !configured()) return;
    QSettings st;
    const qint64 last = st.value(QStringLiteral("lastUpdateCheck"), 0).toLongLong();
#ifdef Q_OS_ANDROID
    const qint64 gap = qint64(1) * 3600 * 1000;          // new builds come often; at most once an hour
#else
    const qint64 gap = qint64(12) * 3600 * 1000;         // at most twice a day
#endif
    if (QDateTime::currentMSecsSinceEpoch() - last < gap) return;
    QTimer::singleShot(4000, this, [this]() { check(false); });
}

void UpdateChecker::check(bool manual)
{
    if (!configured()) { if (manual) setStatus(QStringLiteral("Updates aren't set up in this build yet.")); return; }
    if (m_checking || m_installing) return;
#ifdef Q_OS_ANDROID
    checkAndroid(manual);
    return;
#endif
    m_checking = true;
    if (manual) setStatus(QStringLiteral("Checking…"));
    else emit changed();
    QNetworkRequest rq(QUrl(QStringLiteral("https://api.github.com/repos/%1/releases/latest").arg(QLatin1String(kUpdateRepo))));
    rq.setRawHeader("Accept", "application/vnd.github+json");
    rq.setHeader(QNetworkRequest::UserAgentHeader, "musicplayer");
    rq.setTransferTimeout(15000);
    QNetworkReply *r = m_net.get(rq);
    connect(r, &QNetworkReply::finished, this, [this, r, manual]() {
        r->deleteLater();
        m_checking = false;
        const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (r->error() != QNetworkReply::NoError) {
            if (code == 404) setStatus(manual ? QStringLiteral("No release has been published yet.") : QString());
            else setStatus(manual ? QStringLiteral("Couldn't reach GitHub. Try again later.") : QString());
            return;
        }
        QSettings().setValue(QStringLiteral("lastUpdateCheck"), QDateTime::currentMSecsSinceEpoch());
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const QString tag = o.value("tag_name").toString();
        const QVersionNumber latest = QVersionNumber::fromString(tag.startsWith(QLatin1Char('v')) ? tag.mid(1) : tag);
        if (latest.isNull()) { setStatus(manual ? QStringLiteral("Couldn't read the newest version.") : QString()); return; }
        m_tag = tag;
        m_latest = latest.toString();
        m_page = o.value("html_url").toString();
        m_notes = o.value("body").toString().left(1500);
        m_available = QVersionNumber::compare(latest, QVersionNumber::fromString(current())) > 0;
        setStatus(m_available ? QStringLiteral("Version %1 is available.").arg(m_latest)
                              : QStringLiteral("You're up to date (version %1).").arg(current()));
    });
}

void UpdateChecker::install()
{
#ifdef Q_OS_ANDROID
    installAndroid();
    return;
#endif
    if (!m_available || m_installing || m_installed || !canInstall()) return;
    m_installing = true;
    m_tail.clear();
    setStatus(QStringLiteral("Starting…"));
    m_proc = new QProcess(this);
    m_proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_proc, &QProcess::readyRead, this, [this]() {
        const QStringList lines = QString::fromUtf8(m_proc->readAll()).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &raw : lines) {
            const QString line = raw.trimmed();
            if (line.isEmpty()) continue;
            m_tail << line;
            while (m_tail.size() > 12) m_tail.removeFirst();
            if (line.startsWith(QLatin1String("STEP: "))) setStatus(line.mid(6));
        }
    });
    connect(m_proc, &QProcess::finished, this, [this](int code, QProcess::ExitStatus st) {
        m_installing = false;
        if (code == 0 && st == QProcess::NormalExit) {
            m_installed = true;
            setStatus(QStringLiteral("Updated to version %1. Restart to use it.").arg(m_latest));
        } else {
            setStatus(QStringLiteral("The update didn't finish. %1").arg(m_tail.isEmpty() ? QString() : m_tail.last().left(160)));
        }
        m_proc->deleteLater();
        m_proc = nullptr;
    });
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert(QStringLiteral("MUSICPLAYER_REPO"), QLatin1String(kUpdateRepo));      // one place to set the repository
    m_proc->setProcessEnvironment(env);
    // low priority, so the music doesn't stutter while it builds
    m_proc->start(QStringLiteral("nice"), {QStringLiteral("-n"), QStringLiteral("10"), QStringLiteral("bash"), scriptPath(), QStringLiteral("--tag"), m_tag});
}

void UpdateChecker::restart()
{
    QString exe = m_exe;
    if (exe.endsWith(QLatin1String(" (deleted)"))) exe.chop(10);       // the file was replaced while we were running
    QStringList args = QCoreApplication::arguments();
    if (!args.isEmpty()) args.removeFirst();
    // a short pause lets this copy hand back its MPRIS name first
    QProcess::startDetached(QStringLiteral("sh"), QStringList{QStringLiteral("-c"), QStringLiteral("sleep 1; exec \"$0\" \"$@\""), exe} + args);
    QCoreApplication::quit();
}

void UpdateChecker::openReleasePage() const
{
    if (!m_page.isEmpty()) QDesktopServices::openUrl(QUrl(m_page));
}

// ---- Android: download the newest APK and hand it to Android's installer ----

namespace {
const char *kLatestBase = "https://github.com/%1/releases/download/android-latest/%2";

QNetworkRequest androidRequest(const QString &file)
{
    QNetworkRequest rq(QUrl(QString::fromLatin1(kLatestBase).arg(QLatin1String(kUpdateRepo), file)));
    rq.setHeader(QNetworkRequest::UserAgentHeader, "paraplay");
    rq.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);   // GitHub hands files off to another host
    rq.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    return rq;
}

QString fileSha256(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) return {};
    QCryptographicHash h(QCryptographicHash::Sha256);
    if (!h.addData(&f)) return {};
    return QString::fromLatin1(h.result().toHex());
}
} // namespace

void UpdateChecker::checkAndroid(bool manual)
{
    m_checking = true;
    if (manual) setStatus(QStringLiteral("Checking…"));
    else emit changed();
    QNetworkRequest rq = androidRequest(QStringLiteral("latest.json"));
    rq.setTransferTimeout(15000);
    QNetworkReply *r = m_net.get(rq);
    connect(r, &QNetworkReply::finished, this, [this, r, manual]() {
        r->deleteLater();
        m_checking = false;
        const int code = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (r->error() != QNetworkReply::NoError) {
            if (code == 404) setStatus(manual ? QStringLiteral("No update has been published yet.") : QString());
            else setStatus(manual ? QStringLiteral("Couldn't reach GitHub. Check your connection and try again.") : QString());
            return;
        }
        QSettings().setValue(QStringLiteral("lastUpdateCheck"), QDateTime::currentMSecsSinceEpoch());
        const QJsonObject o = QJsonDocument::fromJson(r->readAll()).object();
        const int build = o.value("build").toInt();
        if (build <= 0) { setStatus(manual ? QStringLiteral("Couldn't read the newest version.") : QString()); return; }
        m_latestBuild = build;
        m_latest = QStringLiteral("%1 (build %2)").arg(o.value("version").toString(QStringLiteral(APP_VERSION))).arg(build);
        m_sha = o.value("sha256").toString();
        m_notes = o.value("notes").toString().left(1500);
        m_available = build > PARAPLAY_BUILD;
        setStatus(m_available ? QStringLiteral("An update is available: %1.").arg(m_latest)
                              : QStringLiteral("You're up to date (%1).").arg(current()));
    });
}

void UpdateChecker::installAndroid()
{
#ifdef Q_OS_ANDROID
    if (!m_available || m_installing) return;
    if (!android::canInstallApks()) {
        // Android asks once, per app, before an app may install other apps (including itself).
        android::askInstallApks();
        setStatus(QStringLiteral("Android needs your OK first. Switch on “Allow from this source”, go Back, then tap Update now again."));
        return;
    }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/update");
    QDir().mkpath(dir);
    m_apkPath = dir + QStringLiteral("/Paraplay-update.apk");
    m_progress = 0;
    // A finished download from an earlier try (installer cancelled) can be reused.
    if (!m_sha.isEmpty() && QFileInfo::exists(m_apkPath) && fileSha256(m_apkPath).compare(m_sha, Qt::CaseInsensitive) == 0) {
        launchInstaller();
        return;
    }
    QFile::remove(m_apkPath);
    auto *file = new QFile(m_apkPath, this);
    if (!file->open(QIODevice::WriteOnly)) {
        delete file;
        setStatus(QStringLiteral("Couldn't save the update on this phone."));
        return;
    }
    m_installing = true;
    setStatus(QStringLiteral("Downloading… 0%"));
    QNetworkReply *r = m_net.get(androidRequest(QStringLiteral("Paraplay-android.apk")));
    m_download = r;
    connect(r, &QNetworkReply::readyRead, this, [r, file]() { file->write(r->readAll()); });
    connect(r, &QNetworkReply::downloadProgress, this, [this](qint64 got, qint64 total) {
        const double p = total > 0 ? double(got) / double(total) : 0.0;
        if (int(p * 100) == int(m_progress * 100)) return;
        m_progress = p;
        setStatus(QStringLiteral("Downloading… %1%").arg(int(p * 100)));
    });
    connect(r, &QNetworkReply::finished, this, [this, r, file]() {
        r->deleteLater();
        file->write(r->readAll());
        file->close();
        file->deleteLater();
        m_installing = false;
        m_progress = 0;
        if (r->error() != QNetworkReply::NoError) {
            QFile::remove(m_apkPath);
            setStatus(QStringLiteral("The download didn't finish. Check your connection and try again."));
            return;
        }
        if (QFileInfo(m_apkPath).size() < 1000000 ||
            (!m_sha.isEmpty() && fileSha256(m_apkPath).compare(m_sha, Qt::CaseInsensitive) != 0)) {
            QFile::remove(m_apkPath);
            setStatus(QStringLiteral("The downloaded update looks damaged. Try again in a minute."));
            return;
        }
        launchInstaller();
    });
#endif
}

void UpdateChecker::launchInstaller()
{
#ifdef Q_OS_ANDROID
    if (android::installApk(m_apkPath))
        setStatus(QStringLiteral("Tap Install in the Android prompt. If it says the app conflicts with the existing one, uninstall Paraplay once and install the update by hand."));
    else
        setStatus(QStringLiteral("Couldn't open Android's installer."));
#endif
}
