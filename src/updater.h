#pragma once
#include <QNetworkAccessManager>
#include <QObject>
#include <QPointer>
#include <QStringList>

class QProcess;
class QNetworkReply;

// Looks for a newer release on GitHub (once a day, or when asked) and can install it by running the
// update script that setup put next to the program. Nothing is sent except the request itself.
// On Android there is no script: every build is published as a small "latest.json" plus an APK, and installing means
// downloading that APK and handing it to Android's installer.
class UpdateChecker : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString current READ current CONSTANT)
    Q_PROPERTY(QString latest READ latest NOTIFY changed)
    Q_PROPERTY(bool configured READ configured CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool checking READ checking NOTIFY changed)
    Q_PROPERTY(bool installing READ installing NOTIFY changed)
    Q_PROPERTY(bool installed READ installed NOTIFY changed)       // built and installed, waiting for a restart
    Q_PROPERTY(bool canInstall READ canInstall CONSTANT)
    Q_PROPERTY(bool store READ store CONSTANT)                     // an app-store build: the store does the updating
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString notes READ notes NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)        // 0..1 while an APK downloads
public:
    explicit UpdateChecker(QObject *parent = nullptr);

    QString current() const;
    QString latest() const { return m_latest; }
    bool configured() const;
    bool available() const { return m_available; }
    bool checking() const { return m_checking; }
    bool installing() const { return m_installing; }
    bool installed() const { return m_installed; }
    bool canInstall() const;
    bool store() const;
    QString status() const { return m_status; }
    QString notes() const { return m_notes; }
    double progress() const { return m_progress; }

    Q_INVOKABLE void check(bool manual);
    Q_INVOKABLE void install();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void openReleasePage() const;
    void checkOnStart(bool enabled);

signals:
    void changed();

private:
    QString scriptPath() const;
    void setStatus(const QString &s);
    void checkAndroid(bool manual);
    void installAndroid();
    void launchInstaller();

    QNetworkAccessManager m_net;
    QProcess *m_proc = nullptr;
    QString m_latest, m_tag, m_status, m_notes, m_page, m_exe;
    QStringList m_tail;
    QString m_apkPath, m_sha;
    int m_latestBuild = 0;
    double m_progress = 0;
    QPointer<QNetworkReply> m_download;
    bool m_available = false, m_checking = false, m_installing = false, m_installed = false;
};
