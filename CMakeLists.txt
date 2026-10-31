cmake_minimum_required(VERSION 3.21)
project(musicplayer VERSION 0.7.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent Network)
if(ANDROID)
  # Phones: Qt Multimedia plays the audio, and TagLib is built for Android by the CI workflow (TAGLIB_PREFIX).
  find_package(Qt6 6.6 REQUIRED COMPONENTS Multimedia)
  if(NOT TAGLIB_PREFIX)
    message(FATAL_ERROR "Set -DTAGLIB_PREFIX=<folder where TagLib was installed for Android>")
  endif()
  add_library(taglib_android STATIC IMPORTED)
  set_target_properties(taglib_android PROPERTIES
    IMPORTED_LOCATION "${TAGLIB_PREFIX}/lib/libtag.a"
    INTERFACE_INCLUDE_DIRECTORIES "${TAGLIB_PREFIX}/include"
    INTERFACE_LINK_LIBRARIES z)
else()
  if(UNIX AND NOT APPLE)
    find_package(Qt6 6.6 REQUIRED COMPONENTS DBus)
  endif()
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
  pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
endif()

qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(musicplayer
  src/main.cpp src/library.cpp src/library.h src/player.cpp src/player.h
  src/cover.cpp src/cover.h src/types.h src/fuzzy.h src/lyrics.cpp src/lyrics.h
  src/artistimages.cpp src/artistimages.h src/playlists.cpp src/playlists.h
  src/account.cpp src/account.h src/backend_config.h
  src/servers.cpp src/servers.h src/updater.cpp src/updater.h src/update_config.h
  src/social.cpp src/social.h src/folders.cpp src/folders.h)

target_compile_definitions(musicplayer PRIVATE APP_VERSION="${PROJECT_VERSION}")

qt_add_qml_module(musicplayer
  URI Music
  VERSION 1.0
  QML_FILES
    qml/Main.qml qml/Icon.qml qml/IconButton.qml qml/Cover.qml qml/Progress.qml
    qml/QualityChip.qml qml/NavItem.qml qml/Sidebar.qml qml/SongList.qml
    qml/Groups.qml qml/Carousel.qml qml/PlayerBar.qml qml/ExpandedPlayer.qml qml/SettingsPanel.qml
    qml/SectionLabel.qml qml/ToggleRow.qml qml/Slider255.qml qml/ColorEditor.qml
    qml/ArtistPhoto.qml qml/SearchBar.qml qml/NamePrompt.qml
    qml/Btn.qml qml/AuthPanel.qml qml/ProfilePage.qml qml/Avatar.qml qml/ImagePopup.qml
    qml/CoverTile.qml qml/Field.qml qml/AddServerPanel.qml
    qml/PersonRow.qml qml/FollowButton.qml qml/Chip.qml qml/TwoColumns.qml qml/FriendsPage.qml
    qml/PublicProfile.qml qml/ProfilePreview.qml qml/FriendPlaylist.qml
    qml/FolderPicker.qml qml/GalleryPicker.qml qml/LyricsView.qml)

target_link_libraries(musicplayer PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Concurrent Qt6::Network)

if(ANDROID)
  target_sources(musicplayer PRIVATE src/android.cpp src/android.h src/androidmedia.cpp src/androidmedia.h)
  target_link_libraries(musicplayer PRIVATE Qt6::Multimedia taglib_android)

  # Version shown in Android's app info, and the number Android compares to decide a newer APK may replace an older one.
  if(NOT ANDROID_VERSION_CODE)
    set(ANDROID_VERSION_CODE 1)
  endif()
  set_target_properties(musicplayer PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
    QT_ANDROID_PACKAGE_NAME "io.github.whozdgt.paraplay"
    QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
    QT_ANDROID_VERSION_CODE "${ANDROID_VERSION_CODE}"
    QT_ANDROID_TARGET_SDK_VERSION 34)
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
else()
  target_link_libraries(musicplayer PRIVATE PkgConfig::MPV PkgConfig::TAGLIB)
  target_compile_definitions(musicplayer PRIVATE HAVE_MPV)
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
