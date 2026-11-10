#include <algorithm>
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
#include <QImage>
#include <QQuickWindow>
#include <QSettings>
#include <QStandardPaths>
#include <QStyleHints>
#include <QTimer>

#include "account.h"
#include "artistimages.h"
#include "cover.h"
#include "folders.h"
#include "library.h"
#include "player.h"
#include "playlists.h"
#include "playstats.h"
#include "safearea.h"
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
#ifdef Q_OS_IOS
#include "iosmedia.h"
#endif
#ifdef Q_OS_WIN
#include <cstdio>
#include <cstring>
#include "winmedia.h"
#endif

int main(int argc, char *argv[])
{
#ifdef Q_OS_WIN
    attachParentConsole();
    for (int i = 1; i < argc; ++i)
        if (!std::strcmp(argv[i], "--version") || !std::strcmp(argv[i], "-v")) { std::printf("musicplayer %s\n", APP_VERSION); return 0; }
#endif
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_WIN) && !defined(Q_OS_IOS)
    QQuickWindow::setDefaultAlphaBuffer(true);   // transparent window so the compositor can blur behind it
#endif
    QGuiApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C");              // libmpv requires this, otherwise mpv_create() fails
    QGuiApplication::setApplicationName("musicplayer");
    QGuiApplication::setApplicationVersion(QStringLiteral(APP_VERSION));
    QGuiApplication::setOrganizationName("musicplayer");
    QGuiApplication::setDesktopFileName("musicplayer");   // Wayland app_id / window class

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(Q_OS_WIN)
    // phones and most Windows PCs don't have JetBrains Mono, so the build packs it into the app
    const QDir fontDir(QStringLiteral(":/fonts"));
    for (const QString &f : fontDir.entryList({QStringLiteral("*.ttf"), QStringLiteral("*.otf")}, QDir::Files))
        QFontDatabase::addApplicationFont(fontDir.filePath(f));
#endif
    QFont font;
    font.setFamilies({"JetBrains Mono", "DejaVu Sans Mono", "Consolas", "monospace"});
    font.setPixelSize(14);
    QGuiApplication::setFont(font);

    QCommandLineParser cli;
    cli.addHelpOption();
    cli.addVersionOption();
    QCommandLineOption dirOpt(QStringList{"m", "music"}, "Music folder to scan.", "dir");
    cli.addOption(dirOpt);
    // For checking the interface without a screen (CI): set any setting for this run only, then save a picture of the window.
    QCommandLineOption setOpt("set", "Use a setting for this run only (not saved), e.g. theme=classic. Repeatable.", "key=value");
    QCommandLineOption shotOpt("screenshot", "Save a picture of the window to this file and quit.", "file");
    QCommandLineOption sizeOpt("size", "Window size for --screenshot, e.g. 390x844.", "WxH");
    QCommandLineOption mobileOpt("mobile", "Lay out as on a phone (touch-sized controls).");
    cli.addOption(setOpt);
    cli.addOption(shotOpt);
    cli.addOption(sizeOpt);
    cli.addOption(mobileOpt);
    cli.process(app);

    QSettings st;
    auto *settings = new QQmlPropertyMap(&app);
    const auto flag = [&](const char *k, bool d) { settings->insert(k, st.value(k, d).toBool()); };
    flag("frosted", true); flag("autoUpdateCheck", true); flag("adaptive", true); flag("lyrics", true); flag("onlineLyrics", true); flag("badges", true);
    flag("recordCover", false); flag("phoneGrid", false); flag("bitPerfect", true); flag("matchRate", true); flag("artistSplit", true); flag("onlineArtistPhotos", true);
    // Home page layout. Until homeCustom is set the page uses its built-in default (which differs for guests and signed-in people).
    flag("homeCustom", false);
    settings->insert("homeOrder", st.value("homeOrder", "").toString());   // comma separated section keys, top to bottom
    settings->insert("homeOff", st.value("homeOff", "").toString());       // sections the person switched off
    settings->insert("homeTop", st.value("homeTop", "4w").toString());     // top artists: "4w" or "all"
    settings->insert("ringCount", st.value("ringCount", 3).toInt());
    // Settings › Look › Theme. "midnight": pure black, every word in your accent colour, rounded shapes, glass bars.
    // "classic": your own background and text colours, square corners.
    settings->insert("theme", st.value("theme", "midnight").toString() == QLatin1String("classic") ? QStringLiteral("classic") : QStringLiteral("midnight"));
    settings->insert("uiScale", std::clamp(st.value("uiScale", 100).toInt(), 80, 150));   // Settings › Look › Interface size, in percent
    settings->insert("settingsQuery", QString());     // what is typed in the Settings search box; only lives while the window is open
    settings->insert("volume", st.value("volume", 100).toInt());
    settings->insert("artistExceptions", st.value("artistExceptions",
        QStringLiteral("Earth, Wind & Fire\nTyler, The Creator\nSimon & Garfunkel\nHall & Oates\nBrooks & Dunn")).toString());
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
    settings->insert("mobile", true);                 // a phone: touch-sized controls, one column, no window frame
#else
    settings->insert("mobile", false);
#endif
    settings->insert("primary", QVariant::fromValue(QColor(st.value("primary", "#000000").toString())));
    settings->insert("accent", QVariant::fromValue(QColor(st.value("accent", "#16a34a").toString())));
#ifdef Q_OS_IOS
    // An iPhone app can only read its own folder. The Files app shows it as On My iPhone › Paraplay, and a Mac's
    // Finder shows it when the phone is plugged in: that is where the music goes.
    const QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QDir().mkpath(defaultDir);
#else
    const QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::MusicLocation);
#endif
    const QString dir = cli.isSet(dirOpt) ? cli.value(dirOpt) : st.value("musicDir", defaultDir).toString();
    settings->insert("bgColor", QVariant::fromValue(QColor(st.value("bgColor", "#f3f0f5").toString())));
    settings->insert("musicDir", dir);
    // How selected rows and boxes are tinted on a solid background (always on a phone): your colour at your strength.
    // New installs start with white on a dark page, black on a light one.
    {
        const QColor bg = settings->value("bgColor").value<QColor>();
        settings->insert("highlight", QVariant::fromValue(QColor(st.value("highlight", bg.lightnessF() < 0.5 ? "#ffffff" : "#000000").toString())));
        settings->insert("highlightOpacity", st.value("highlightOpacity", 12).toInt());
        settings->insert("boxOpacity", st.value("boxOpacity", 5).toInt());
    }
    // The colours and shapes everything is drawn with. QML reads these, never the raw settings, so a theme can
    // replace them without touching what you chose under Classic.
    const auto refreshTheme = [settings]() {
        const bool midnight = settings->value("theme").toString() == QLatin1String("midnight");
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(Q_OS_WIN)
        const bool solid = true;          // phones and Windows can't blur what is behind the window
#else
        const bool solid = midnight || !settings->value("frosted").toBool();
#endif
        const QColor accent = settings->value("accent").value<QColor>();
        QColor ink = settings->value("primary").value<QColor>();
        QColor ground = settings->value("bgColor").value<QColor>();
        QColor h = settings->value("highlight").value<QColor>();
        if (midnight) {
            ground = QColor(0, 0, 0);
            ink = accent;
            // a very dark accent would vanish on black: lift it until it reads
            for (int i = 0; i < 8 && ink.lightnessF() < 0.45; ++i) ink = ink.lighter(125);
            h = QColor(255, 255, 255);
        }
        const auto rgba = [](const QColor &c, double a) { QColor o = c; o.setAlphaF(std::clamp(a, 0.0, 1.0)); return QVariant::fromValue(o); };
        const auto mix = [](const QColor &a, const QColor &b, double t) {
            return QColor::fromRgbF(a.redF() * (1 - t) + b.redF() * t, a.greenF() * (1 - t) + b.greenF() * t, a.blueF() * (1 - t) + b.blueF() * t);
        };
        const double ho = settings->value("highlightOpacity").toInt() / 100.0;
        const double bo = settings->value("boxOpacity").toInt() / 100.0;
        settings->insert("solid", solid);
        settings->insert("round", midnight);
        settings->insert("ink", QVariant::fromValue(ink));
        settings->insert("ground", QVariant::fromValue(ground));
        // quieter text (artists, notes): a softer shade that still reads (at least 4.5:1) rather than see-through ink
        settings->insert("inkSoft", midnight ? QVariant::fromValue(mix(ink, QColor(128, 128, 128), 0.38)) : rgba(ink, 0.72));
        settings->insert("onInk", QVariant::fromValue(midnight ? QColor(0, 0, 0) : QColor(255, 255, 255)));     // text on an ink-filled button
        settings->insert("surface", midnight ? QVariant::fromValue(QColor(28, 28, 30)) : rgba(QColor(255, 255, 255), 0.95));   // menus, dialogs
        settings->insert("field", midnight ? QVariant::fromValue(QColor(44, 44, 46)) : rgba(QColor(255, 255, 255), 0.85));     // text boxes
        settings->insert("chipFill", midnight ? rgba(accent, 0.16) : rgba(h, std::clamp(bo * 1.6, 0.0, 1.0)));
        settings->insert("cardFill", midnight ? rgba(accent, 0.10) : rgba(h, bo));
        // the floating player and tab bar: frosted grey on Midnight
        settings->insert("glass", midnight ? rgba(QColor(44, 44, 48), 0.78) : (solid ? rgba(h, std::clamp(bo * 1.6, 0.0, 1.0)) : rgba(QColor(255, 255, 255), 0.5)));
        settings->insert("glassLine", midnight ? rgba(QColor(255, 255, 255), 0.12) : (solid ? rgba(h, std::min(0.4, bo * 3.5)) : rgba(QColor(255, 255, 255), 0.8)));
        settings->insert("roundButton", midnight ? rgba(QColor(120, 120, 128), 0.36) : QVariant::fromValue(QColor(0, 0, 0, 0)));
        settings->insert("hiSel", rgba(h, ho));
        settings->insert("hiHover", rgba(h, ho / 2));
        settings->insert("boxFill", rgba(h, bo));
        settings->insert("boxHover", rgba(h, bo * 1.6));
        settings->insert("boxLine", rgba(h, std::min(0.4, bo * 3.5)));
    };
    // --set key=value and --mobile: this run only. insert() doesn't announce a change, so nothing is saved.
    if (cli.isSet(mobileOpt)) settings->insert("mobile", true);
    for (const QString &kv : cli.values(setOpt)) {
        const qsizetype eq = kv.indexOf(QLatin1Char('='));
        if (eq <= 0) continue;
        const QString k = kv.left(eq), v = kv.mid(eq + 1);
        bool isInt = false;
        const int n = v.toInt(&isInt);
        if (v == QLatin1String("true") || v == QLatin1String("false")) settings->insert(k, v == QLatin1String("true"));
        else if (isInt) settings->insert(k, n);
        else if (v.startsWith(QLatin1Char('#'))) settings->insert(k, QVariant::fromValue(QColor(v)));
        else settings->insert(k, v);
    }
    refreshTheme();

    // Phones show the app's background behind the status bar: its icons go dark on a light background, light on a dark one.
    const auto applyBars = [settings]() {
#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS)
        const bool light = settings->value("ground").value<QColor>().lightnessF() >= 0.5;
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
        QGuiApplication::styleHints()->setColorScheme(light ? Qt::ColorScheme::Light : Qt::ColorScheme::Dark);
#endif
#ifdef Q_OS_ANDROID
        android::setSystemBarsLight(light);
#endif
#else
        Q_UNUSED(settings)
#endif
    };

    Library library;
    FolderBrowser folders;
    Player player(&library, settings->value("bitPerfect").toBool(), settings->value("matchRate").toBool());

    const auto applySplit = [&]() {
        library.setSplitOptions(settings->value("artistSplit").toBool(), settings->value("artistExceptions").toString());
    };
    applySplit();
    player.setVolume(settings->value("volume").toInt());
    player.setOnlineLyrics(settings->value("onlineLyrics").toBool());
    ArtistImages artistImages;
    artistImages.setOnline(settings->value("onlineArtistPhotos").toBool());
    Playlists playlists(&library);
    Account account(&playlists);
    ServerManager servers(&library);
    Social social(&account, &library, &player);
    PlayStats stats(&player, &library);
    social.setServerName([&](const QString &p) { return servers.serverNameFor(p); });
    UpdateChecker updater;
    player.setRemote({
        [&](const QString &p) { return servers.streamUrl(p); },
        [&](const QString &p) { return servers.allowsSelfSigned(p); },
        [&](const QString &p) { return servers.serverNameFor(p); },
        [&](const Track &t, std::function<void(const QImage &)> cb) { servers.loadCover(t.serverId(), t.cover, std::move(cb)); }});

    QObject::connect(settings, &QQmlPropertyMap::valueChanged, &app, [&](const QString &k, const QVariant &v) {
        if (k == "settingsQuery") return;            // the search box is not a setting: never saved
        st.setValue(k, v.typeId() == QMetaType::QColor ? QVariant(v.value<QColor>().name()) : v);
        if (k == "bgColor" || k == "frosted" || k == "highlight" || k == "highlightOpacity" || k == "boxOpacity" || k == "theme"
            || k == "accent" || k == "primary") refreshTheme();
        if (k == "bgColor" || k == "theme") applyBars();
        if (k == "bitPerfect") player.setBitPerfect(v.toBool());
        if (k == "musicDir") library.scan(v.toString());
        if (k == "volume") player.setVolume(v.toInt());
        if (k == "onlineArtistPhotos") artistImages.setOnline(v.toBool());
        if (k == "onlineLyrics") player.setOnlineLyrics(v.toBool());
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
    ctx->setContextProperty("stats", &stats);
    ctx->setContextProperty("folders", &folders);
    ctx->setContextProperty("updater", &updater);
    SafeArea safeArea;
    ctx->setContextProperty("safeArea", &safeArea);
    engine.loadFromModule("Music", "Main");
    if (engine.rootObjects().isEmpty()) return 1;
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    safeArea.watch(window);
    if (cli.isSet(shotOpt) && window) {
        const QStringList wh = cli.value(sizeOpt).split(QLatin1Char('x'));
        if (wh.size() == 2) window->resize(wh[0].toInt(), wh[1].toInt());
        const QString file = cli.value(shotOpt);
        QTimer::singleShot(3500, &app, [window, file]() {
            const QImage img = window->grabWindow();
            if (!img.save(file)) qWarning("screenshot: couldn't save %s", qPrintable(file));
            QCoreApplication::quit();
        });
    }
    applyBars();

#ifdef HAVE_MPRIS
    Mpris mpris(&player);
#endif
#ifdef Q_OS_WIN
    WinMedia winMedia(&player);              // the keyboard's media keys
#endif
#ifdef Q_OS_IOS
    IosMedia iosMedia(&player);              // keeps playing with the screen locked; lock-screen controls
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
