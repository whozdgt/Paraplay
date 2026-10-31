cmake_minimum_required(VERSION 3.21)
project(musicplayer VERSION 0.7.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

find_package(Qt6 6.6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent Network)
if(UNIX AND NOT APPLE)
  find_package(Qt6 6.6 REQUIRED COMPONENTS DBus)
endif()
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)

qt_standard_project_setup(REQUIRES 6.6)

qt_add_executable(musicplayer
  src/main.cpp src/library.cpp src/library.h src/player.cpp src/player.h
  src/cover.cpp src/cover.h src/types.h src/fuzzy.h
  src/artistimages.cpp src/artistimages.h src/playlists.cpp src/playlists.h
  src/account.cpp src/account.h src/backend_config.h
  src/servers.cpp src/servers.h src/updater.cpp src/updater.h src/update_config.h
  src/social.cpp src/social.h)

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
    qml/PublicProfile.qml qml/ProfilePreview.qml qml/FriendPlaylist.qml)

target_link_libraries(musicplayer PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Concurrent Qt6::Network
  PkgConfig::MPV PkgConfig::TAGLIB)

if(UNIX AND NOT APPLE)
  target_sources(musicplayer PRIVATE src/mpris.cpp src/mpris.h)
  target_link_libraries(musicplayer PRIVATE Qt6::DBus)
  target_compile_definitions(musicplayer PRIVATE HAVE_MPRIS)
  install(FILES packaging/musicplayer.desktop DESTINATION share/applications)
endif()
install(TARGETS musicplayer RUNTIME DESTINATION bin)
# the in-app "Update now" button runs this copy of the update script
install(PROGRAMS update.sh DESTINATION share/musicplayer RENAME musicplayer-update)
