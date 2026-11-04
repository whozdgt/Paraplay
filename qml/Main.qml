import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Window {
    id: win
    width: 1040
    height: 640
    minimumWidth: android ? 0 : 860
    minimumHeight: android ? 0 : 520
    visible: true
    title: "Music"
    color: opaque ? settings.bgColor : "transparent"     // phones and Windows can't blur what is behind the window

    readonly property bool android: Qt.platform.os === "android"
    readonly property bool opaque: android || Qt.platform.os === "windows"
    // Settings > Look > Interface size. A bigger size needs a bigger window (a phone down to 300 wide, a computer down to 800),
    // so when the window is too small for it, the size is held back until the window grows.
    readonly property real uiS: Math.max(0.8, Math.min(settings.uiScale / 100, Math.max(1, width / (android ? 300 : 800))))
    readonly property real lw: width / uiS             // the width and height the app lays itself out in
    readonly property real lh: height / uiS
    readonly property bool phone: lw < 720             // one column, menu slides in from the left
    readonly property int gutter: phone ? 16 : 36
    // where the page content starts: below the title, and below the row of buttons (sort, source…) when there is one
    readonly property real contentTop: phone ? 56 + (chips.height > 0 ? chips.height + 12 : 4) : 90
    property bool drawerOpen: false

    Item {      // Android's Back key lands here when nothing else has the keyboard
        anchors.fill: parent
        focus: true
        Keys.onBackPressed: (e) => { e.accepted = win.handleBack() }
    }

    property bool expanded: false
    property bool settingsOpen: false
    property bool sortOpen: false
    property bool searchOpen: false
    property bool authOpen: false
    property bool addServerOpen: false
    property bool sourceOpen: false         // the "All sources / This computer / <server>" dropdown
    property real srcX: 0
    property real srcY: 0
    property string menuPath: ""
    property real menuX: 0
    property real menuY: 0
    property string promptPath: ""
    property string currentPlaylist: ""
    onSearchOpenChanged: { if (searchOpen) searchBar.open(); else library.search = "" }
    property string view: "home"           // home | songs | albums | artists | playlists | profile | friends | user | friendpl
    property string backView: ""
    property string userBack: "home"        // where "back" goes from someone's profile
    property string profileMode: "edit"     // edit | preview (your own profile page)
    property string plBack: "friends"        // where "back" goes from a friend's playlist
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    // Album-art glow: only while a song plays and "Adapt to album colours" is on.
    property real glowOn: (player.hasTrack && settings.adaptive) ? 1 : 0
    property color glowA: player.glowA
    property color glowB: player.glowB
    Behavior on glowOn { NumberAnimation { duration: 600 } }
    Behavior on glowA { ColorAnimation { duration: 700 } }
    Behavior on glowB { ColorAnimation { duration: 700 } }

    function groupView(v) {
        const grid = phone && settings.phoneGrid
        if (v === "albums") return grid ? albumGrid : albumFlow
        if (v === "artists") return grid ? artistGrid : artistFlow
        return grid ? playlistGrid : playlistFlow
    }
    // The phone's Back button / swipe: close the top-most thing, or go up one level. False = nothing left to close.
    function handleBack() {
        if (folderPicker.visible) { folderPicker.visible = false; return true }
        if (addServerOpen) { addServerOpen = false; return true }
        if (authOpen) { authOpen = false; return true }
        if (imagePopup.visible) { imagePopup.visible = false; return true }
        if (prompt.visible) { prompt.visible = false; return true }
        if (menuPath !== "") { menuPath = ""; return true }
        if (sourceOpen || sortOpen) { sourceOpen = false; sortOpen = false; return true }
        if (drawerOpen) { drawerOpen = false; return true }
        if (searchOpen) { searchOpen = false; return true }
        if (settingsOpen) { if (!settingsPanel.goBack()) settingsOpen = false; return true }      // a section or a search first, then Settings itself
        if (expanded) { expanded = false; return true }
        if (view === "user" || view === "friendpl") { back(); return true }
        if (library.filterKind !== "") { navigate(backView || "home"); return true }
        if (view !== "home") { navigate("home"); return true }
        return false
    }
    onClosing: (close) => { if (android && handleBack()) close.accepted = false }

    // from = the page "back" returns to; left out, it is the list the item came from (albums, artists…)
    function pick(kind, key, label, from) {
        searchOpen = false
        drawerOpen = false
        library.setFilter(kind, key, label)
        backView = from || (kind + "s")
        view = "songs"
    }
    function navigate(v) { library.clearFilter(); searchOpen = false; drawerOpen = false; backView = ""; view = v }
    function openUser(name) {
        searchOpen = false
        if (view !== "user" && view !== "friendpl") userBack = view
        social.openProfile(name, false)
        view = "user"
    }
    function openFriendPlaylist(pid, name, owner, fromUser) {
        searchOpen = false
        if (!fromUser && view !== "friendpl") userBack = view
        plBack = fromUser ? "user" : "friends"
        social.openPlaylist(pid, name, owner)
        view = "friendpl"
    }
    function back() {
        if (view === "friendpl" && plBack === "user") view = "user"
        else navigate(userBack || "home")
    }
    function openPlaylist(key, name, from) {
        searchOpen = false
        drawerOpen = false
        currentPlaylist = key
        library.setPlaylistFilter(key, name, playlists.paths(key))
        backView = from || "playlists"
        view = "songs"
    }
    function openFindPeople() {
        navigate("friends")
        friendsPage.tab = "find"
        Qt.callLater(friendsPage.focusSearch)
    }

    // The Home and Friends pages show what your friends are playing, so keep that fresh while one of them is open.
    readonly property bool watchSocial: account.signedIn && (view === "home" || view === "friends")
    onWatchSocialChanged: social.watch(watchSocial)
    Component.onCompleted: social.watch(watchSocial)

    HomeLayout { id: homeLayout }

    // Everything you see lives on this surface. Settings › Look › Interface size scales it, so text, buttons and spacing all grow or shrink together.
    Item {
        id: ui
        width: win.lw
        height: win.lh
        scale: win.uiS
        transformOrigin: Item.TopLeft

        Rectangle {
            anchors.fill: parent
            color: (settings.frosted && !win.opaque) ? Qt.rgba(1, 1, 1, 0.58) : settings.bgColor
            border.width: win.opaque ? 0 : 1
            border.color: Qt.rgba(1, 1, 1, 0.75)

            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: "transparent"
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: win.lw * 0.18; centerY: win.lh * 0.12
                        centerRadius: win.lw * 0.55
                        focalX: centerX; focalY: centerY
                        GradientStop { position: 0; color: Qt.rgba(win.glowA.r, win.glowA.g, win.glowA.b, 0.5 * win.glowOn) }
                        GradientStop { position: 1; color: Qt.rgba(win.glowA.r, win.glowA.g, win.glowA.b, 0) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: win.lw; y: 0 }
                    PathLine { x: win.lw; y: win.lh }
                    PathLine { x: 0; y: win.lh }
                    PathLine { x: 0; y: 0 }
                }
                ShapePath {
                    strokeColor: "transparent"
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: win.lw * 0.85; centerY: win.lh * 0.92
                        centerRadius: win.lw * 0.6
                        focalX: centerX; focalY: centerY
                        GradientStop { position: 0; color: Qt.rgba(win.glowB.r, win.glowB.g, win.glowB.b, 0.5 * win.glowOn) }
                        GradientStop { position: 1; color: Qt.rgba(win.glowB.r, win.glowB.g, win.glowB.b, 0) }
                    }
                    startX: 0; startY: 0
                    PathLine { x: win.lw; y: 0 }
                    PathLine { x: win.lw; y: win.lh }
                    PathLine { x: 0; y: win.lh }
                    PathLine { x: 0; y: 0 }
                }
            }
        }

        // ---- Library view ----
        Item {
            anchors.fill: parent
            visible: !win.expanded

            Rectangle {      // dims the page while the menu is out
                z: 33
                anchors.fill: parent
                color: "black"
                opacity: win.phone && win.drawerOpen ? 0.35 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                MouseArea { anchors.fill: parent; onClicked: win.drawerOpen = false }
            }
            Sidebar {
                id: side
                z: 35
                drawer: win.phone
                width: win.phone ? Math.min(300, win.lw * 0.84) : 230
                x: win.phone && !win.drawerOpen ? -width : 0
                visible: !win.phone || x > -width
                Behavior on x { enabled: win.phone; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                anchors { top: parent.top; bottom: parent.bottom }
                view: win.view
                onSelect: (v) => win.navigate(v)
                onProfileClicked: { win.drawerOpen = false; if (account.signedIn) win.navigate("profile"); else win.authOpen = true }
                onSourceSelected: (id) => {
                    win.drawerOpen = false
                    library.source = id
                    if (win.view === "profile" || win.view === "playlists" || win.view === "friends" || win.view === "user" || win.view === "friendpl") win.navigate("songs")
                }
                onAddServerRequested: { win.drawerOpen = false; win.addServerOpen = true }
                onUpdateClicked: { win.drawerOpen = false; settingsPanel.show("about"); win.settingsOpen = true }
            }

            Item {
                anchors { left: win.phone ? parent.left : side.right; right: parent.right; top: parent.top; bottom: bar.top; bottomMargin: 12 }

                Text {
                    id: title
                    z: 5
                    x: win.gutter + (win.phone ? 44 : 0)      // phone: the menu button sits to its left
                    y: win.phone ? 12 : 26
                    height: win.phone ? 32 : implicitHeight
                    verticalAlignment: Text.AlignVCenter
                        visible: win.view !== "home"
                        text: win.view === "friends" ? "‹ Friends"
                            : win.view === "user" ? "‹ " + (social.profile.name || social.profile.username || "Profile")
                            : win.view === "friendpl" ? "‹ " + (social.playlist.name || "Playlist")
                            : library.filterKind !== "" ? "‹ " + library.filterName
                            : (win.view === "albums" ? "Albums" : win.view === "artists" ? "Artists" : win.view === "playlists" ? "Playlists" : win.view === "profile" ? "Profile" : "Songs")
                        font.pixelSize: win.phone ? 20 : 28
                        font.weight: Font.DemiBold
                        color: win.pri
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, win.phone ? parent.width - x - 104 : parent.width - 140)
                        MouseArea {
                            anchors.fill: parent
                            enabled: library.filterKind !== "" || win.view === "user" || win.view === "friendpl" || win.view === "friends"
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (win.view === "user" || win.view === "friendpl") win.back()
                                else if (win.view === "friends") win.navigate("home")
                                else win.navigate(win.backView || "songs")
                            }
                        }
                    }
                Row {      // sort, source, share…: beside the title on a computer, under it on a phone
                    id: chips
                    z: 5
                    spacing: 12
                    x: win.phone ? win.gutter : title.x + title.width + 12
                    y: win.phone ? title.y + title.height + 12 : title.y + (title.height - height) / 2
                    Item {   // sort button, next to the "Songs" heading
                        visible: win.view === "songs" && library.filterKind === ""
                        height: 36
                        width: sortRow.implicitWidth + 24
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: sortRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: "sort"; size: 18; color: win.pri }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: library.sortMode === "newest" ? "Latest to oldest" : library.sortMode === "oldest" ? "Oldest to latest" : "A–Z"
                                font.pixelSize: 13
                                color: win.pri
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.sortOpen = !win.sortOpen }
                    }
                    Item {   // "New playlist", next to the Playlists heading
                        visible: win.view === "playlists" && library.filterKind === ""
                        height: 36
                        width: newRow.implicitWidth + 24
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: newRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: "plus"; size: 18; color: win.pri }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "New playlist"
                                font.pixelSize: 13
                                color: win.pri
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.promptPath = ""; prompt.visible = true } }
                    }
                    Item {   // phone: covers you flick through, or a grid of them
                        visible: win.phone && library.filterKind === "" && (win.view === "albums" || win.view === "artists" || win.view === "playlists")
                        height: 36
                        width: gridText.implicitWidth + 24
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: gridText
                            anchors.centerIn: parent
                            text: settings.phoneGrid ? "Show as flow" : "Show as grid"
                            font.pixelSize: 13
                            color: win.pri
                        }
                        MouseArea { anchors.fill: parent; onClicked: settings.phoneGrid = !settings.phoneGrid }
                    }
                    Row {   // Edit | Preview, on your own profile page
                        visible: win.view === "profile" && account.signedIn
                        anchors.verticalCenter: parent.verticalCenter
                        Repeater {
                            model: [{ k: "edit", t: "Edit" }, { k: "preview", t: "Preview" }]
                            Rectangle {
                                required property var modelData
                                readonly property bool sel: win.profileMode === modelData.k
                                width: 84; height: 32
                                color: sel ? win.pri : "transparent"
                                border.width: 1
                                border.color: win.pri
                                Text { anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 13; color: parent.sel ? "white" : win.pri }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.profileMode = parent.modelData.k }
                            }
                        }
                    }
                    Item {   // lets you list a playlist on your public profile
                        visible: win.view === "songs" && library.filterKind === "playlist" && account.signedIn && win.currentPlaylist !== ""
                        height: 36
                        width: shareRow.implicitWidth + 24
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: shareRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: "cloud"; size: 18; color: win.pri }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: { playlists.revision; return playlists.isShared(win.currentPlaylist) ? "Shared on your profile" : "Share on your profile" }
                                font.pixelSize: 13
                                color: win.pri
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playlists.setShared(win.currentPlaylist, !playlists.isShared(win.currentPlaylist))
                        }
                    }
                    Item {   // which source the list shows; only once you have added a server
                        id: srcChip
                        visible: servers.count > 0 && library.filterKind === "" && (win.view === "songs" || win.view === "albums" || win.view === "artists")
                        height: 36
                        width: srcRow.implicitWidth + 24
                        anchors.verticalCenter: parent.verticalCenter
                        Row {
                            id: srcRow
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: "cloud"; size: 18; color: win.pri }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: { servers.revision; return servers.sourceName(library.source) }
                                font.pixelSize: 13
                                color: win.pri
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const p = srcChip.mapToItem(ui, 0, srcChip.height)
                                win.srcX = p.x
                                win.srcY = p.y
                                win.sortOpen = false
                                win.sourceOpen = !win.sourceOpen
                            }
                        }
                    }
                }

                HomePage {
                    id: homePage
                    visible: win.view === "home"
                    layout: homeLayout
                    gutter: win.gutter
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.phone ? 56 : 18 }
                    onOpenUser: (username) => win.openUser(username)
                    onOpenArtist: (name) => win.pick("artist", name, name, "home")
                    onOpenAlbum: (key, name) => win.pick("album", key, name, "home")
                    onOpenPlaylist: (key, name) => win.openPlaylist(key, name, "home")
                    onShowView: (v) => win.navigate(v)
                    onMenuRequested: (path, gx, gy) => { win.menuPath = path; win.menuX = gx / win.uiS; win.menuY = gy / win.uiS }
                    onOpenProfile: win.navigate("profile")
                    onSignInRequested: win.authOpen = true
                }
                ProfilePage {
                    id: profilePage
                    visible: win.view === "profile"
                    editing: win.profileMode === "edit"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onSignInRequested: win.authOpen = true
                    onImageRequested: (kind) => { imagePopup.kind = kind; imagePopup.visible = true }
                }
                ProfilePreview {
                    visible: win.view === "profile" && win.profileMode === "preview" && account.signedIn
                    dirty: profilePage.dirty
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                }
                FriendsPage {
                    id: friendsPage
                    visible: win.view === "friends"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onSignInRequested: win.authOpen = true
                    onOpenUser: (username) => win.openUser(username)
                    onOpenPlaylist: (pid, name, owner) => win.openFriendPlaylist(pid, name, owner, false)
                }
                PublicProfile {
                    visible: win.view === "user"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onOpenPlaylist: (pid, name, owner) => win.openFriendPlaylist(pid, name, owner, true)
                }
                FriendPlaylist {
                    visible: win.view === "friendpl"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                }
                SongList {
                    visible: win.view === "songs"
                    onMenuRequested: (path, gx, gy) => { win.menuPath = path; win.menuX = gx / win.uiS; win.menuY = gy / win.uiS }
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                }
                Groups {
                    id: albumGrid
                    kind: "album"
                    active: win.phone && settings.phoneGrid && win.view === "albums"
                    visible: active
                    anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onPicked: (key, name) => win.pick("album", key, name)
                }
                Groups {
                    id: artistGrid
                    kind: "artist"
                    active: win.phone && settings.phoneGrid && win.view === "artists"
                    visible: active
                    anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onPicked: (key, name) => win.pick("artist", key, name)
                }
                Groups {
                    id: playlistGrid
                    kind: "playlist"
                    active: win.phone && settings.phoneGrid && win.view === "playlists"
                    visible: active
                    anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; top: parent.top; bottom: parent.bottom; topMargin: win.contentTop }
                    onPicked: (key, name) => win.openPlaylist(key, name)
                }
                Carousel {
                    id: albumFlow
                    kind: "album"
                    active: !(win.phone && settings.phoneGrid)
                    phone: win.phone
                    searching: win.searchOpen && win.view === "albums"
                    visible: active && win.view === "albums"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.phone ? win.contentTop : 70 }
                    onPicked: (key, name) => win.pick("album", key, name)
                }
                Carousel {
                    id: artistFlow
                    kind: "artist"
                    active: !(win.phone && settings.phoneGrid)
                    phone: win.phone
                    searching: win.searchOpen && win.view === "artists"
                    visible: active && win.view === "artists"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.phone ? win.contentTop : 70 }
                    onPicked: (key, name) => win.pick("artist", key, name)
                }
                Carousel {
                    id: playlistFlow
                    kind: "playlist"
                    active: !(win.phone && settings.phoneGrid)
                    phone: win.phone
                    searching: win.searchOpen && win.view === "playlists"
                    visible: active && win.view === "playlists"
                    anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: win.phone ? win.contentTop : 70 }
                    onPicked: (key, name) => win.openPlaylist(key, name)
                }
            }

            SearchBar {
                id: searchBar
                z: 40
                visible: win.searchOpen
                kind: win.view === "albums" ? "album" : win.view === "artists" ? "artist" : "playlist"
                suggestions: win.view !== "songs"
                width: win.phone ? parent.width - 68 : 440
                x: win.phone ? 8 : side.width + (parent.width - side.width - width) / 2
                y: win.phone ? 6 : 18
                onTyped: (q) => { if (win.view === "songs") library.search = q }
                onChosen: (item) => {
                    win.groupView(win.view).focusKey(item.key)
                }
                onClosed: win.searchOpen = false
            }
            MouseArea { z: 29; anchors.fill: parent; visible: win.sortOpen || win.sourceOpen; onClicked: { win.sortOpen = false; win.sourceOpen = false } }
            Rectangle {
                z: 30
                visible: win.sortOpen && win.view === "songs"
                x: win.phone ? win.gutter : side.width + 36
                y: win.phone ? chips.y + chips.height + 4 : 72
                width: 210
                height: sortCol.implicitHeight
                color: Qt.rgba(1, 1, 1, 0.94)
                Column {
                    id: sortCol
                    Repeater {
                        model: [{ k: "az", t: "A–Z" }, { k: "newest", t: "Latest to oldest" }, { k: "oldest", t: "Oldest to latest" }]
                        Rectangle {
                            required property var modelData
                            width: 210; height: 40
                            color: ma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                text: parent.modelData.t; font.pixelSize: 13; color: win.pri
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                visible: library.sortMode === parent.modelData.k; text: "✓"; color: settings.accent
                            }
                            MouseArea {
                                id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { library.sortMode = parent.modelData.k; win.sortOpen = false }
                            }
                        }
                    }
                }
            }

            Rectangle {   // source dropdown
                z: 30
                visible: win.sourceOpen
                x: Math.max(10, Math.min(win.srcX, win.lw - width - 10))
                y: win.srcY + 4
                width: 240
                height: srcCol.implicitHeight
                color: Qt.rgba(1, 1, 1, 0.94)
                Column {
                    id: srcCol
                    Repeater {
                        model: {
                            servers.revision
                            return [{ id: "", name: "All sources" }, { id: "local", name: "This computer" }]
                                .concat(servers.list().filter(function(x) { return x.enabled }))
                        }
                        Rectangle {
                            required property var modelData
                            width: 240; height: 40
                            color: sma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                            Text {
                                anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
                                text: parent.modelData.name; elide: Text.ElideRight; font.pixelSize: 13; color: win.pri
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                visible: library.source === parent.modelData.id; text: "✓"; color: settings.accent
                            }
                            MouseArea {
                                id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { library.source = parent.modelData.id; win.sourceOpen = false }
                            }
                        }
                    }
                }
            }

            PlayerBar {
                id: bar
                anchors { left: win.phone ? parent.left : side.right; leftMargin: win.phone ? 8 : 20; right: parent.right; rightMargin: win.phone ? 8 : 20; bottom: parent.bottom; bottomMargin: win.phone ? 8 : 16 }
                onExpand: win.expanded = true
            }
        }

        ExpandedPlayer {
            anchors.fill: parent
            visible: win.expanded
            onCollapse: win.expanded = false
        }

        IconButton {      // phone: opens the menu
            z: 10
            visible: win.phone && !win.expanded && !win.settingsOpen && !win.drawerOpen && !win.searchOpen
            anchors { left: parent.left; leftMargin: 6; top: parent.top; topMargin: 6 }
            name: "menu"; box: 44; iconSize: 24
            onClicked: win.drawerOpen = true
            Rectangle {      // a newer build is waiting: the menu has the "Update available" chip
                visible: updater.available
                width: 10; height: 10; radius: 5; color: settings.accent
                anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 6 }
            }
        }

        IconButton {      // phone: closes the search box
            z: 41
            visible: win.phone && win.searchOpen && !win.expanded
            anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 6 }
            name: "close"; box: 44; iconSize: 20
            onClicked: win.searchOpen = false
        }

        IconButton {
            z: 10
            visible: !win.settingsOpen && !(win.phone && (win.drawerOpen || win.searchOpen)) && win.view !== "friends" && win.view !== "user" && win.view !== "friendpl"
            anchors { right: parent.right; rightMargin: win.phone ? 52 : 76; top: parent.top; topMargin: win.phone ? 6 : 18 }
            name: "search"; box: 44; iconSize: 22
            onClicked: {
                if (win.view === "home") { win.navigate("songs"); win.searchOpen = true }      // the home page has nothing to search: use the song list
                else win.searchOpen = !win.searchOpen
            }
        }

        IconButton {      // Home: find people to follow
            z: 10
            visible: win.view === "home" && account.signedIn && !win.expanded && !win.settingsOpen && !(win.phone && (win.drawerOpen || win.searchOpen))
            anchors { right: parent.right; rightMargin: win.phone ? 98 : 132; top: parent.top; topMargin: win.phone ? 6 : 18 }
            name: "personplus"; box: 44; iconSize: 22
            onClicked: win.openFindPeople()
        }

        IconButton {
            z: 10
            visible: !win.settingsOpen && !(win.phone && (win.drawerOpen || win.searchOpen))      // hidden while the settings box is open
            anchors { right: parent.right; rightMargin: win.phone ? 6 : 20; top: parent.top; topMargin: win.phone ? 6 : 18 }
            name: "gear"; box: 44; iconSize: 22
            onClicked: win.settingsOpen = !win.settingsOpen
        }

        MouseArea {                      // click outside the settings box closes it
            z: 15
            anchors.fill: parent
            visible: win.settingsOpen
            onClicked: win.settingsOpen = false
        }

        SettingsPanel {
            id: settingsPanel
            layout: homeLayout
            z: 20
            opacity: win.settingsOpen ? 1 : 0           // eases in and out, sliding a little from the right
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            transform: Translate {
                x: win.settingsOpen ? 0 : (win.phone ? 36 : 24)
                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            width: win.phone ? win.lw : 540
            anchors { right: parent.right; rightMargin: win.phone ? 0 : 20; top: parent.top; topMargin: win.phone ? 0 : 16; bottom: parent.bottom; bottomMargin: win.phone ? 0 : (win.expanded ? 16 : 88) }
            onClose: win.settingsOpen = false
            onAddServerRequested: { win.settingsOpen = false; win.addServerOpen = true }
            onChooseFolderRequested: folderPicker.visible = true
        }

        FolderPicker {
            id: folderPicker
            z: 62
            anchors.fill: parent
            visible: false
            startPath: settings.musicDir
            onChosen: (dir) => { settings.musicDir = dir; visible = false }
            onCancelled: visible = false
        }

        AuthPanel {
            id: auth
            z: 58
            anchors.fill: parent
            visible: win.authOpen
            onCloseRequested: win.authOpen = false
        }

        // Confetti and a greeting after a new account is made. Above everything, takes no clicks.
        Welcome { id: welcome; z: 100; anchors.fill: parent }
        Connections { target: account; function onSignedUp(name) { welcome.play(name) } }

        AddServerPanel {
            id: addServer
            z: 59
            anchors.fill: parent
            visible: win.addServerOpen
            onCloseRequested: win.addServerOpen = false
        }

        // Right-click a song: add it to a playlist.
        MouseArea { z: 55; anchors.fill: parent; visible: win.menuPath !== ""; onClicked: win.menuPath = "" }
        Rectangle {
            z: 56
            visible: win.menuPath !== ""
            x: Math.min(win.menuX, win.lw - width - 10)
            y: Math.min(win.menuY, win.lh - height - 10)
            width: 260
            height: mcol.implicitHeight
            color: Qt.rgba(1, 1, 1, 0.96)
            Column {
                id: mcol
                width: parent.width
                Text { text: "Add to playlist"; font.pixelSize: 11; font.letterSpacing: 1; color: win.muted; leftPadding: 14; topPadding: 12; bottomPadding: 6 }
                Repeater {
                    model: { playlists.revision; return playlists.list() }
                    Rectangle {
                        required property var modelData
                        width: mcol.width; height: 38
                        color: pma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                        Text { anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: parent.modelData.name; elide: Text.ElideRight; font.pixelSize: 13; color: win.pri }
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { playlists.addTrack(parent.modelData.key, win.menuPath); win.menuPath = "" } }
                    }
                }
                Rectangle {
                    width: mcol.width; height: 38
                    color: nma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                    Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "+ New playlist…"; font.pixelSize: 13; color: win.pri }
                    MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.promptPath = win.menuPath; win.menuPath = ""; prompt.visible = true } }
                }
                Rectangle {
                    visible: library.filterKind === "playlist"
                    width: mcol.width; height: 38
                    color: rma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                    Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "Remove from this playlist"; font.pixelSize: 13; color: win.pri }
                    MouseArea {
                        id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playlists.removeTrack(win.currentPlaylist, win.menuPath)
                            library.setPlaylistFilter(win.currentPlaylist, library.filterName, playlists.paths(win.currentPlaylist))
                            win.menuPath = ""
                        }
                    }
                }
            }
        }
        NamePrompt {
            id: prompt
            z: 60
            anchors.fill: parent
            visible: false
            onAccepted: (name) => {
                const id = playlists.create(name)
                if (win.promptPath !== "") playlists.addTrack(id, win.promptPath)
                win.promptPath = ""
                visible = false
            }
            onCancelled: { win.promptPath = ""; visible = false }
        }
        ImagePopup {
            id: imagePopup
            z: 61
            anchors.fill: parent
            visible: false
        }
    }

    Shortcut { sequence: "Space"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.toggle() }
    Shortcut { sequence: "Left"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen && (win.expanded || win.view === "songs"); onActivated: player.seek(player.position - 5) }
    Shortcut { sequence: "Right"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen && (win.expanded || win.view === "songs"); onActivated: player.seek(player.position + 5) }
    Shortcut { sequence: "N"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.next() }
    Shortcut { sequence: "P"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.prev() }
    Shortcut { sequence: "Escape"; onActivated: { if (folderPicker.visible) folderPicker.visible = false; else if (win.addServerOpen) win.addServerOpen = false; else if (win.authOpen) win.authOpen = false; else if (imagePopup.visible) imagePopup.visible = false; else if (prompt.visible) prompt.visible = false; else if (win.menuPath !== "") win.menuPath = ""; else if (win.sourceOpen) win.sourceOpen = false; else if (win.searchOpen) win.searchOpen = false; else if (win.settingsOpen) { if (!settingsPanel.goBack()) win.settingsOpen = false } else if (!win.expanded && (win.view === "user" || win.view === "friendpl")) win.back(); else win.expanded = false } }
}
