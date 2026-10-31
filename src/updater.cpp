#include "updater.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QProcessEnvironment>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QVersionNumber>

#include "update_config.h"

UpdateChecker::UpdateChecker(QObject *parent) : QObject(parent), m_exe(QCoreApplication::applicationFilePath()) {}

QString UpdateChecker::current() const { return QStringLiteral(APP_VERSION); }

bool UpdateChecker::configured() const { return kUpdateRepo[0] != '\0'; }

QString UpdateChecker::scriptPath() const
{
    return QDir::cleanPath(QCoreApplication::applicationDirPath() + QStringLiteral("/../share/musicplayer/musicplayer-update"));
}

// In-app installing works once the player was installed by update.sh (it puts the script in place).
bool UpdateChecker::canInstall() const { return configured() && QFileInfo::exists(scriptPath()); }

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
    if (QDateTime::currentMSecsSinceEpoch() - last < qint64(12) * 3600 * 1000) return;      // at most twice a day
    QTimer::singleShot(4000, this, [this]() { check(false); });
}

void UpdateChecker::check(bool manual)
{
    if (!configured()) { if (manual) setStatus(QStringLiteral("Updates aren't set up in this build yet.")); return; }
    if (m_checking || m_installing) return;
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
