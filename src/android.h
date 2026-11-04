#include <QtGlobal>
#pragma once
// Android-only helpers: asking for access to the phone's music files.
#ifdef Q_OS_ANDROID
#include <QByteArray>
#include <QString>
#include <functional>

namespace android {
bool audioAllowed();            // may the app read music files in shared storage?
void askForAudio();
#ifndef PARAPLAY_STORE          // the Play Store build can't install apps, not even its own updates
bool canInstallApks();          // has the user allowed this app to install apps (needed to update itself)?
void askInstallApks();          // opens the system page where they allow it
bool installApk(const QString &path);   // hands an APK to Android's installer; false if it couldn't be started
#endif

// Dark or light status-bar and gesture-bar icons, to stand out against the app's background, which shows behind them.
void setSystemBarsLight(bool lightBackground);

// Background playback: a foreground service with a media notification and lock-screen controls (MediaService.java).
void mediaInit(std::function<void(int cmd, qint64 arg)> handler);   // cmd: 0 play, 1 pause, 2 next, 3 previous, 4 seek (arg ms), 5 stop
void mediaUpdate(const QString &title, const QString &artist, const QString &album, qint64 durationMs, qint64 positionMs,
                 bool playing, bool streaming, const QByteArray &coverJpeg);
void mediaStop();
void mediaDetach();             // the app is closing: forget the player and take the notification down
bool notificationsAllowed();    // Android 13+ asks before an app may show notifications
void askNotifications();        // shows the system permission dialog
}
#endif
