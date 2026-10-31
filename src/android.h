#include <QtGlobal>
#pragma once
// Android-only helpers: asking for access to the phone's music files.
#ifdef Q_OS_ANDROID
#include <QString>

namespace android {
bool audioAllowed();            // may the app read music files in shared storage?
void askForAudio();             // shows the system permission dialog (the result is read back with audioAllowed())
}
#endif
