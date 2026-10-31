#include <QtGlobal>

#include "android.h"

#ifdef Q_OS_ANDROID
#include <QCoreApplication>
#include <QMetaObject>
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

namespace {
QString packageName(const QJniObject &ctx) { return ctx.callObjectMethod("getPackageName", "()Ljava/lang/String;").toString(); }
void clearException()
{
    QJniEnvironment env;
    if (env->ExceptionCheck()) { env->ExceptionDescribe(); env->ExceptionClear(); }
}
} // namespace

bool canInstallApks()
{
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid() || sdkInt() < 26) return true;
    const QJniObject pm = ctx.callObjectMethod("getPackageManager", "()Landroid/content/pm/PackageManager;");
    const bool ok = pm.callMethod<jboolean>("canRequestPackageInstalls", "()Z");
    clearException();
    return ok;
}

void askInstallApks()
{
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return;
    const QJniObject action = QJniObject::fromString(QStringLiteral("android.settings.MANAGE_UNKNOWN_APP_SOURCES"));
    QJniObject intent("android/content/Intent", "(Ljava/lang/String;)V", action.object<jstring>());
    const QJniObject uriText = QJniObject::fromString(QStringLiteral("package:") + packageName(ctx));
    const QJniObject uri = QJniObject::callStaticObjectMethod("android/net/Uri", "parse", "(Ljava/lang/String;)Landroid/net/Uri;",
                                                              uriText.object<jstring>());
    intent.callObjectMethod("setData", "(Landroid/net/Uri;)Landroid/content/Intent;", uri.object());
    intent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", jint(0x10000000));       // FLAG_ACTIVITY_NEW_TASK
    ctx.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", intent.object());
    clearException();
}

bool installApk(const QString &path)
{
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return false;
    // Android won't hand a bare file path to the installer; it has to go through the app's FileProvider.
    const QJniObject file("java/io/File", "(Ljava/lang/String;)V", QJniObject::fromString(path).object<jstring>());
    const QJniObject authority = QJniObject::fromString(packageName(ctx) + QStringLiteral(".qtprovider"));
    const QJniObject uri = QJniObject::callStaticObjectMethod(
        "androidx/core/content/FileProvider", "getUriForFile",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/io/File;)Landroid/net/Uri;",
        ctx.object(), authority.object<jstring>(), file.object());
    if (!uri.isValid()) { clearException(); return false; }
    const QJniObject action = QJniObject::fromString(QStringLiteral("android.intent.action.VIEW"));
    QJniObject intent("android/content/Intent", "(Ljava/lang/String;)V", action.object<jstring>());
    const QJniObject mime = QJniObject::fromString(QStringLiteral("application/vnd.android.package-archive"));
    intent.callObjectMethod("setDataAndType", "(Landroid/net/Uri;Ljava/lang/String;)Landroid/content/Intent;",
                            uri.object(), mime.object<jstring>());
    // FLAG_GRANT_READ_URI_PERMISSION | FLAG_ACTIVITY_NEW_TASK
    intent.callObjectMethod("addFlags", "(I)Landroid/content/Intent;", jint(0x1 | 0x10000000));
    ctx.callMethod<void>("startActivity", "(Landroid/content/Intent;)V", intent.object());
    QJniEnvironment env;
    const bool failed = env->ExceptionCheck();
    clearException();
    return !failed;
}

namespace {
std::function<void(int, qint64)> g_mediaHandler;
const char *const kMediaClass = "io/github/whozdgt/paraplay/MediaService";

// Called by MediaService.java (on Android's main thread) when a notification or lock-screen button is pressed.
void JNICALL nativeMediaCommand(JNIEnv *, jclass, jint cmd, jlong arg)
{
    QMetaObject::invokeMethod(qApp, [cmd, arg]() { if (g_mediaHandler) g_mediaHandler(int(cmd), qint64(arg)); }, Qt::QueuedConnection);
}
} // namespace

void mediaInit(std::function<void(int, qint64)> handler)
{
    g_mediaHandler = std::move(handler);
    static char name[] = "nativeCommand";
    static char sig[] = "(IJ)V";
    const JNINativeMethod methods[] = {{name, sig, reinterpret_cast<void *>(&nativeMediaCommand)}};
    QJniEnvironment env;
    if (!env.registerNativeMethods(kMediaClass, methods, 1)) qWarning("media: couldn't register the service's native method");
}

void mediaUpdate(const QString &title, const QString &artist, const QString &album, qint64 durationMs, qint64 positionMs,
                 bool playing, bool streaming, const QByteArray &coverJpeg)
{
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return;
    QJniEnvironment env;
    jbyteArray art = nullptr;
    if (!coverJpeg.isEmpty()) {
        art = env->NewByteArray(coverJpeg.size());
        env->SetByteArrayRegion(art, 0, coverJpeg.size(), reinterpret_cast<const jbyte *>(coverJpeg.constData()));
    }
    QJniObject::callStaticMethod<void>(kMediaClass, "update",
        "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;JJZZ[B)V",
        ctx.object(), QJniObject::fromString(title).object<jstring>(), QJniObject::fromString(artist).object<jstring>(),
        QJniObject::fromString(album).object<jstring>(), jlong(durationMs), jlong(positionMs),
        jboolean(playing), jboolean(streaming), art);
    if (art) env->DeleteLocalRef(art);
    clearException();
}

void mediaStop()
{
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return;
    QJniObject::callStaticMethod<void>(kMediaClass, "stop", "(Landroid/content/Context;)V", ctx.object());
    clearException();
}

bool notificationsAllowed()
{
    if (sdkInt() < 33) return true;
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return true;
    const QJniObject name = QJniObject::fromString(QStringLiteral("android.permission.POST_NOTIFICATIONS"));
    return ctx.callMethod<jint>("checkSelfPermission", "(Ljava/lang/String;)I", name.object<jstring>()) == 0;
}

void askNotifications()
{
    if (sdkInt() < 33) return;
    const QJniObject ctx = QNativeInterface::QAndroidApplication::context();
    if (!ctx.isValid()) return;
    QJniEnvironment env;
    const jclass stringClass = env->FindClass("java/lang/String");
    jobjectArray list = env->NewObjectArray(1, stringClass, nullptr);
    const QJniObject name = QJniObject::fromString(QStringLiteral("android.permission.POST_NOTIFICATIONS"));
    env->SetObjectArrayElement(list, 0, name.object<jstring>());
    ctx.callMethod<void>("requestPermissions", "([Ljava/lang/String;I)V", list, jint(8));
    env->DeleteLocalRef(list);
    env->DeleteLocalRef(stringClass);
}

} // namespace android
#endif
