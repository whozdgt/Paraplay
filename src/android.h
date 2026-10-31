#include <QtGlobal>
#pragma once
// Android-only helpers: asking for access to the phone's music files.
#ifdef Q_OS_ANDROID
#include <QString>

namespace android {
bool audioAllowed();            // may the app read music files in shared storage?
void askForAudio();
bool canInstallApks();          // has the user allowed this app to install apps (needed to update itself)?
void askInstallApks();          // opens the system page where they allow it
bool installApk(const QString &path);   // hands an APK to Android's installer; false if it couldn't be started             // shows the system permission dialog (the result is read back with audioAllowed())
}
#endif
