#include <QtGlobal>

#include "android.h"

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>

namespace android {

namespace {

int sdkInt() { return QJniObject::getStaticField<jint>("android/os/Build$VERSION", "SDK_INT"); }

// Android 13+ asks for "audio files"; older versions ask for "storage".
QString permissionName()
{
    return sdkInt() >= 33 ? QStringLiteral("android.permission.READ_MEDIA_AUDIO")
                          : QStringLiteral("android.permission.READ_EXTERNAL_STORAGE");
}

} // namespace

bool audioAllowed()
{
    const QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) return false;
    const QJniObject name = QJniObject::fromString(permissionName());
    // PackageManager.PERMISSION_GRANTED == 0
    return activity.callMethod<jint>("checkSelfPermission", "(Ljava/lang/String;)I", name.object<jstring>()) == 0;
}

void askForAudio()
{
    const QJniObject activity = QNativeInterface::QAndroidApplication::context();
    if (!activity.isValid()) return;
    QJniEnvironment env;
    const jclass stringClass = env->FindClass("java/lang/String");
    jobjectArray list = env->NewObjectArray(1, stringClass, nullptr);
    const QJniObject name = QJniObject::fromString(permissionName());
    env->SetObjectArrayElement(list, 0, name.object<jstring>());
    activity.callMethod<void>("requestPermissions", "([Ljava/lang/String;I)V", list, jint(7));
    env->DeleteLocalRef(list);
    env->DeleteLocalRef(stringClass);
}

} // namespace android
#endif
