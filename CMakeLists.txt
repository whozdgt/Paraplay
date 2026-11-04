cmake_minimum_required(VERSION 3.21)
project(musicplayer VERSION 0.7.0 LANGUAGES CXX)

if(WIN32)
  enable_language(RC)      # the program's icon and version information
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

# An app-store build (Google Play, Apple's App Store) has no self-updater: the store installs updates.
# iOS builds are always store builds.
option(PARAPLAY_STORE "Build for an app store: no in-app updater" OFF)
if(IOS)
  set(PARAPLAY_STORE ON)
endif()

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent Network)
if(ANDROID OR IOS)
  # Phones: Qt Multimedia plays the audio, and TagLib is built for the phone by the CI workflow (TAGLIB_PREFIX).
  find_package(Qt6 6.6 REQUIRED COMPONENTS Multimedia)
  if(NOT TAGLIB_PREFIX)
    message(FATAL_ERROR "Set -DTAGLIB_PREFIX=<folder where TagLib was installed for the phone>")
  endif()
  add_library(taglib_static STATIC IMPORTED)
  set_target_properties(taglib_static PROPERTIES
    IMPORTED_LOCATION "${TAGLIB_PREFIX}/lib/libtag.a"
    INTERFACE_INCLUDE_DIRECTORIES "${TAGLIB_PREFIX}/include"
    INTERFACE_LINK_LIBRARIES z)
else()
  if(UNIX AND NOT APPLE)
    find_package(Qt6 6.6 REQUIRED COMPONENTS DBus)
  endif()
  if(WIN32)
    # MSYS2's pkg-config hands out /ucrt64/... paths that the Windows build of CMake can't see: look the files up directly.
    find_path(MPV_INCLUDE_DIR mpv/client.h REQUIRED)
    find_library(MPV_LIBRARY NAMES mpv libmpv REQUIRED)
    find_path(TAGLIB_INCLUDE_DIR taglib/fileref.h REQUIRED)
    find_library(TAGLIB_LIBRARY NAMES tag REQUIRED)
    add_library(PkgConfig::MPV INTERFACE IMPORTED)
    set_target_properties(PkgConfig::MPV PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}" INTERFACE_LINK_LIBRARIES "${MPV_LIBRARY}")
    add_library(PkgConfig::TAGLIB INTERFACE IMPORTED)
    set_target_properties(PkgConfig::TAGLIB PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${TAGLIB_INCLUDE_DIR}" INTERFACE_LINK_LIBRARIES "${TAGLIB_LIBRARY}")
  else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
    pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
  endif()
endif()

qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(musicplayer
  src/main.cpp src/library.cpp src/library.h src/player.cpp src/player.h
  src/cover.cpp src/cover.h src/types.h src/fuzzy.h src/lyrics.cpp src/lyrics.h
  src/artistimages.cpp src/artistimages.h src/playlists.cpp src/playlists.h
  src/account.cpp src/account.h src/backend_config.h
  src/servers.cpp src/servers.h src/updater.cpp src/updater.h src/update_config.h
  src/social.cpp src/social.h src/folders.cpp src/folders.h
  src/playstats.cpp src/playstats.h src/safearea.h)

target_compile_definitions(musicplayer PRIVATE APP_VERSION="${PROJECT_VERSION}")
if(PARAPLAY_STORE)
  target_compile_definitions(musicplayer PRIVATE PARAPLAY_STORE)
endif()

qt_add_qml_module(musicplayer
  URI Music
  VERSION 1.0
  QML_FILES
    qml/Main.qml qml/Icon.qml qml/IconButton.qml qml/Cover.qml qml/Progress.qml
    qml/QualityChip.qml qml/NavItem.qml qml/Sidebar.qml qml/SongList.qml
    qml/Groups.qml qml/Carousel.qml qml/PlayerBar.qml qml/ExpandedPlayer.qml qml/SettingsPanel.qml
    qml/SectionLabel.qml qml/ToggleRow.qml qml/Slider255.qml qml/ColorEditor.qml
    qml/SettingItem.qml qml/SetGroup.qml qml/SetBlock.qml qml/SetAccordion.qml qml/SetSlider.qml qml/SliderRow.qml
    qml/ValueRow.qml qml/SetNavItem.qml qml/SetSearch.qml qml/Swatch.qml qml/HexField.qml qml/ThemeEditor.qml
    qml/SetLibrary.qml qml/SetSound.qml qml/SetLook.qml qml/SetHome.qml qml/SetAbout.qml
    qml/ArtistPhoto.qml qml/SearchBar.qml qml/NamePrompt.qml
    qml/Btn.qml qml/AuthPanel.qml qml/ProfilePage.qml qml/Avatar.qml qml/ImagePopup.qml
    qml/CoverTile.qml qml/Field.qml qml/AddServerPanel.qml
    qml/PersonRow.qml qml/FollowButton.qml qml/Chip.qml qml/TwoColumns.qml qml/FriendsPage.qml
    qml/PublicProfile.qml qml/ProfilePreview.qml qml/FriendPlaylist.qml
    qml/FolderPicker.qml qml/GalleryPicker.qml qml/LyricsView.qml qml/Welcome.qml
    qml/HomeLayout.qml qml/HomePage.qml qml/HomeHeading.qml qml/HomePerson.qml qml/HomeFriends.qml
    qml/HomeRequests.qml qml/HomeTop.qml qml/HomeStrip.qml qml/HomeSongs.qml)

target_link_libraries(musicplayer PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Concurrent Qt6::Network)

if(ANDROID)
  target_sources(musicplayer PRIVATE src/android.cpp src/android.h src/androidmedia.cpp src/androidmedia.h)
  target_link_libraries(musicplayer PRIVATE Qt6::Multimedia taglib_static)
  # Google Play wants native code that also runs on phones with 16 KB memory pages (Android 15 and newer)
  target_link_options(musicplayer PRIVATE "-Wl,-z,max-page-size=16384")

  # The Play Store build must not be able to install apps (not even its own updates), so its manifest leaves out
  # that permission. Everything else in android/ is the same.
  set(android_dir "${CMAKE_CURRENT_SOURCE_DIR}/android")
  if(PARAPLAY_STORE)
    set(android_dir "${CMAKE_CURRENT_BINARY_DIR}/android-store")
    file(REMOVE_RECURSE "${android_dir}")
    file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/android/" DESTINATION "${android_dir}")
    file(READ "${android_dir}/AndroidManifest.xml" manifest)
    string(REGEX REPLACE "[ \t]*<!-- lets the app open Android's installer[^\n]*\n" "" manifest "${manifest}")
    string(REGEX REPLACE "[ \t]*<uses-permission android:name=\"android.permission.REQUEST_INSTALL_PACKAGES\" />\n" "" manifest "${manifest}")
    if(manifest MATCHES "REQUEST_INSTALL_PACKAGES")
      message(FATAL_ERROR "Couldn't take REQUEST_INSTALL_PACKAGES out of the store manifest")
    endif()
    file(WRITE "${android_dir}/AndroidManifest.xml" "${manifest}")
  endif()

  # Version shown in Android's app info, and the number Android compares to decide a newer APK may replace an older one.
  if(NOT ANDROID_VERSION_CODE)
    set(ANDROID_VERSION_CODE 1)
  endif()
  set_target_properties(musicplayer PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR "${android_dir}"
    QT_ANDROID_PACKAGE_NAME "io.github.whozdgt.paraplay"
    QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    QT_ANDROID_VERSION_CODE "${ANDROID_VERSION_CODE}"
    QT_ANDROID_COMPILE_SDK_VERSION 36
    QT_ANDROID_TARGET_SDK_VERSION 36)      # Google Play: new apps and updates must target Android 16 (API 36)
  # The app compares this with the newest published build to know whether an update exists.
  target_compile_definitions(musicplayer PRIVATE PARAPLAY_BUILD=${ANDROID_VERSION_CODE})

  # Qt needs OpenSSL next to the app for https (sign-in, servers, updates). The workflow downloads it.
  if(ANDROID_OPENSSL_DIR)
    set_property(TARGET musicplayer APPEND PROPERTY QT_ANDROID_EXTRA_LIBS
      "${ANDROID_OPENSSL_DIR}/ssl_3/${CMAKE_ANDROID_ARCH_ABI}/libcrypto_3.so"
      "${ANDROID_OPENSSL_DIR}/ssl_3/${CMAKE_ANDROID_ARCH_ABI}/libssl_3.so")
  endif()

  # JetBrains Mono travels inside the app, because phones don't have it.
  if(ANDROID_FONT_DIR)
    set(font_files "")
    foreach(w Regular Medium SemiBold Bold)
      if(EXISTS "${ANDROID_FONT_DIR}/JetBrainsMono-${w}.ttf")
        list(APPEND font_files "${ANDROID_FONT_DIR}/JetBrainsMono-${w}.ttf")
      endif()
    endforeach()
    if(font_files)
      qt_add_resources(musicplayer fonts PREFIX "/fonts" BASE "${ANDROID_FONT_DIR}" FILES ${font_files})
    endif()
  endif()
elseif(IOS)
  # iPhone: Qt Multimedia plays through Apple's own decoders; iosmedia.mm keeps music going with the screen locked
  # and shows it on the lock screen.
  target_sources(musicplayer PRIVATE src/iosmedia.mm src/iosmedia.h)
  set_source_files_properties(src/iosmedia.mm PROPERTIES COMPILE_OPTIONS "-fobjc-arc")
  target_link_libraries(musicplayer PRIVATE Qt6::Multimedia taglib_static
    "-framework AVFoundation" "-framework MediaPlayer" "-framework UIKit")

  if(NOT IOS_BUILD_NUMBER)
    set(IOS_BUILD_NUMBER 1)
  endif()
  # The app icon, and the privacy manifest Apple asks every app for (which system features it uses, and why).
  set(ios_assets "${CMAKE_CURRENT_SOURCE_DIR}/packaging/ios/Assets.xcassets")
  set(ios_privacy "${CMAKE_CURRENT_SOURCE_DIR}/packaging/ios/PrivacyInfo.xcprivacy")
  target_sources(musicplayer PRIVATE "${ios_assets}" "${ios_privacy}")
  set_source_files_properties("${ios_assets}" "${ios_privacy}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
  set_target_properties(musicplayer PROPERTIES
    MACOSX_BUNDLE ON
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/packaging/ios/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER "io.github.whozdgt.paraplay"
    MACOSX_BUNDLE_BUNDLE_NAME "Paraplay"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${IOS_BUILD_NUMBER}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "io.github.whozdgt.paraplay"
    XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"              # iPhone (it also runs on iPad, in an iPhone-sized window)
    XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "17.0"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic")
  if(IOS_TEAM_ID)
    set_target_properties(musicplayer PROPERTIES XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${IOS_TEAM_ID}")
  endif()
  target_compile_definitions(musicplayer PRIVATE PARAPLAY_BUILD=${IOS_BUILD_NUMBER})

  if(IOS_FONT_DIR)
    set(font_files "")
    foreach(w Regular Medium SemiBold Bold)
      if(EXISTS "${IOS_FONT_DIR}/JetBrainsMono-${w}.ttf")
        list(APPEND font_files "${IOS_FONT_DIR}/JetBrainsMono-${w}.ttf")
      endif()
    endforeach()
    if(font_files)
      qt_add_resources(musicplayer fonts PREFIX "/fonts" BASE "${IOS_FONT_DIR}" FILES ${font_files})
    endif()
  endif()
else()
  target_link_libraries(musicplayer PRIVATE PkgConfig::MPV PkgConfig::TAGLIB)
  target_compile_definitions(musicplayer PRIVATE HAVE_MPV)
  if(WIN32)
    # no console window behind the player; the media keys; JetBrains Mono travels with the program
    set_target_properties(musicplayer PROPERTIES WIN32_EXECUTABLE ON)
    configure_file(packaging/windows/musicplayer.rc.in "${CMAKE_CURRENT_BINARY_DIR}/musicplayer.rc" @ONLY)
    target_sources(musicplayer PRIVATE src/winmedia.cpp src/winmedia.h "${CMAKE_CURRENT_BINARY_DIR}/musicplayer.rc")
    if(WINDOWS_FONT_DIR)
      set(font_files "")
      foreach(w Regular Medium SemiBold Bold)
        if(EXISTS "${WINDOWS_FONT_DIR}/JetBrainsMono-${w}.ttf")
          list(APPEND font_files "${WINDOWS_FONT_DIR}/JetBrainsMono-${w}.ttf")
        endif()
      endforeach()
      if(font_files)
        qt_add_resources(musicplayer fonts PREFIX "/fonts" BASE "${WINDOWS_FONT_DIR}" FILES ${font_files})
      endif()
    endif()
  endif()
  if(UNIX AND NOT APPLE)
    target_sources(musicplayer PRIVATE src/mpris.cpp src/mpris.h)
    target_link_libraries(musicplayer PRIVATE Qt6::DBus)
    target_compile_definitions(musicplayer PRIVATE HAVE_MPRIS)
    install(FILES packaging/musicplayer.desktop DESTINATION share/applications)
    install(FILES packaging/musicplayer.svg DESTINATION share/icons/hicolor/scalable/apps)
    foreach(size 48 64 128 256 512)
      install(FILES packaging/icons/musicplayer-${size}.png DESTINATION share/icons/hicolor/${size}x${size}/apps RENAME musicplayer.png)
    endforeach()
  endif()
  install(TARGETS musicplayer RUNTIME DESTINATION bin)
  # the in-app "Update now" button runs this copy of the update script
  install(PROGRAMS update.sh DESTINATION share/musicplayer RENAME musicplayer-update)
endif()
