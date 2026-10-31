#include <clocale>
#include <memory>

#include <QColor>
#include <QCommandLineParser>
#include <QDir>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlPropertyMap>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

#include "account.h"
#include "artistimages.h"
#include "cover.h"
#include "folders.h"
#include "library.h"
#include "player.h"
#include "playlists.h"
#include "servers.h"
#include "social.h"
#include "updater.h"
#ifdef HAVE_MPRIS
#include "mpris.h"
#endif
#ifdef Q_OS_ANDROID
#include "android.h"
#include "androidmedia.h"
#endif

int main(int argc, char *argv[])
{
#ifndef Q_OS_ANDROID
    QQuickWindow::setDefaultAlphaBuffer(true);   // transparent window so the compositor can blur behind it
#endif
    QGuiApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");              // libmpv requires this, otherwise mpv_create() fails
    QGuiApplication::setApplicationName("musicplayer");
    QGuiApplication::setApplicationVersion(QStringLiteral(APP_VERSION));
    QGuiApplication::setOrganizationName("musicplayer");
    QGuiApplication::setDesktopFileName("musicplayer");   // Wayland app_id / window class

#ifdef Q_OS_ANDROID
    // phones don't have JetBrains Mono, so the build packs it into the app
    const QDir fontDir(QStringLiteral(":/fonts"));
    for (const QString &f : fontDir.entryList({QStringLiteral("*.ttf"), QStringLiteral("*.otf")}, QDir::Files))
        QFontDatabase::addApplicationFont(fontDir.filePath(f));
#endif
    QFont font;
    font.setFamilies({"JetBrains Mono", "DejaVu Sans Mono", "monospace"});
    font.setPixelSize(14);
    QGuiApplication::setFont(font);

    QCommandLineParser cli;
    cli.addHelpOption();
    cli.addVersionOption();
    QCommandLineOption dirOpt(QStringList{"m", "music"}, "Music folder to scan.", "dir");
    cli.addOption(dirOpt);
    cli.process(app);

    QSettings st;
    auto *settings = new QQmlPropertyMap(&app);
    const auto flag = [&](const char *k, bool d) { settings->insert(k, st.value(k, d).toBool()); };
    flag("frosted", true); flag("autoUpdateCheck", true); flag("adaptive", true); flag("lyrics", true); flag("badges", true);
    flag("recordCover", false); flag("phoneGrid", false); flag("bitPerfect", true); flag("matchRate", true); flag("artistSplit", true); flag("onlineArtistPhotos", true);
    settings->insert("ringCount", st.value("ringCount", 3).toInt());
    settings->insert("volume", st.value("volume", 100).toInt());
    settings->insert("artistExceptions", st.value("artistExceptions",
        QStringLiteral("Earth, Wind & Fire\nTyler, The Creator\nSimon & Garfunkel\nHall & Oates\nBrooks & Dunn")).toString());
    settings->insert("primary", QVariant::fromValue(QColor(st.value("primary", "#000000").toString())));
    settings->insert("accent", QVariant::fromValue(QColor(st.value("accent", "#16a34a").toString())));
    const QString dir = cli.isSet(dirOpt)
        ? cli.value(dirOpt)
        : st.value("musicDir", QStandardPaths::writableLocation(QStandardPaths::MusicLocation)).toString();
    settings->insert("bgColor", QVariant::fromValue(QColor(st.value("bgColor", "#f3f0f5").toString())));
    settings->insert("musicDir", dir);

    Library library;
    FolderBrowser folders;
    Player player(&library, settings->value("bitPerfect").toBool(), settings->value("matchRate").toBool());

    const auto applySplit = [&]() {
        library.setSplitOptions(settings->value("artistSplit").toBool(), settings->value("artistExceptions").toString());
    };
    applySplit();
    player.setVolume(settings->value("volume").toInt());
    ArtistImages artistImages;
    artistImages.setOnline(settings->value("onlineArtistPhotos").toBool());
    Playlists playlists(&library);
    Account account(&playlists);
    ServerManager servers(&library);
    Social social(&account, &library, &player);
    social.setServerName([&](const QString &p) { return servers.serverNameFor(p); });
    UpdateChecker updater;
    player.setRemote({
        [&](const QString &p) { return servers.streamUrl(p); },
        [&](const QString &p) { return servers.allowsSelfSigned(p); },
        [&](const QString &p) { return servers.serverNameFor(p); },
        [&](const Track &t, std::function<void(const QImage &)> cb) { servers.loadCover(t.serverId(), t.cover, std::move(cb)); }});

    QObject::connect(settings, &QQmlPropertyMap::valueChanged, &app, [&](const QString &k, const QVariant &v) {
        st.setValue(k, v.typeId() == QMetaType::QColor ? QVariant(v.value<QColor>().name()) : v);
        if (k == "bitPerfect") player.setBitPerfect(v.toBool());
        if (k == "musicDir") library.scan(v.toString());
        if (k == "volume") player.setVolume(v.toInt());
        if (k == "onlineArtistPhotos") artistImages.setOnline(v.toBool());
        if (k == "artistSplit" || k == "artistExceptions") applySplit();
    });

    QQmlApplicationEngine engine;
    engine.addImageProvider("cover", new CoverProvider);
    engine.addImageProvider("remote", new RemoteCoverProvider(&servers));
    QQmlContext *ctx = engine.rootContext();
    ctx->setContextProperty("settings", settings);
    ctx->setContextProperty("library", &library);
    ctx->setContextProperty("player", &player);
    ctx->setContextProperty("artistImages", &artistImages);
    ctx->setContextProperty("playlists", &playlists);
    ctx->setContextProperty("account", &account);
    ctx->setContextProperty("servers", &servers);
    ctx->setContextProperty("social", &social);
    ctx->setContextProperty("folders", &folders);
    ctx->setContextProperty("updater", &updater);
    engine.loadFromModule("Music", "Main");
    if (engine.rootObjects().isEmpty()) return 1;

#ifdef HAVE_MPRIS
    Mpris mpris(&player);
#endif
#ifdef Q_OS_ANDROID
    AndroidMedia androidMedia(&player);      // notification, lock-screen controls and playing with the screen off
    // Reading the music folder needs the user's OK. Ask, then scan as soon as they say yes.
    if (android::audioAllowed()) {
        library.scan(dir);
    } else {
        android::askForAudio();
        auto *wait = new QTimer(&app);
        auto tries = std::make_shared<int>(0);
        QObject::connect(wait, &QTimer::timeout, &app, [&, wait, tries]() {
            if (android::audioAllowed()) { wait->stop(); library.scan(settings->value("musicDir").toString()); }
            else if (++*tries > 240) wait->stop();      // gave up after about two minutes
        });
        wait->start(500);
    }
#else
    library.scan(dir);
#endif
    updater.checkOnStart(settings->value("autoUpdateCheck").toBool());
    return app.exec();
}
