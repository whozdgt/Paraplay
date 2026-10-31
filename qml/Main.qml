import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Window {
    id: win
    width: 1040
    height: 640
    minimumWidth: 860
    minimumHeight: 520
    visible: true
    title: "Music"
    color: "transparent"

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
    property string view: "songs"          // songs | albums | artists
    property string backView: ""
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    // Album-art glow: only while a song plays and "Adapt to album colours" is on.
    property real glowOn: (player.hasTrack && settings.adaptive) ? 1 : 0
    property color glowA: player.glowA
    property color glowB: player.glowB
    Behavior on glowOn { NumberAnimation { duration: 600 } }
    Behavior on glowA { ColorAnimation { duration: 700 } }
    Behavior on glowB { ColorAnimation { duration: 700 } }

    function pick(kind, key, label) {
        searchOpen = false
        library.setFilter(kind, key, label)
        backView = kind + "s"
        view = "songs"
    }
    function goto(v) { library.clearFilter(); searchOpen = false; backView = ""; view = v }
    function openPlaylist(key, name) {
        searchOpen = false
        currentPlaylist = key
        library.setPlaylistFilter(key, name, playlists.paths(key))
        backView = "playlists"
        view = "songs"
    }

    Rectangle {
        anchors.fill: parent
        color: settings.frosted ? Qt.rgba(1, 1, 1, 0.58) : settings.bgColor
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.75)

        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: win.width * 0.18; centerY: win.height * 0.12
                    centerRadius: win.width * 0.55
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Qt.rgba(win.glowA.r, win.glowA.g, win.glowA.b, 0.5 * win.glowOn) }
                    GradientStop { position: 1; color: Qt.rgba(win.glowA.r, win.glowA.g, win.glowA.b, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: win.width; y: 0 }
                PathLine { x: win.width; y: win.height }
                PathLine { x: 0; y: win.height }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                strokeColor: "transparent"
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: win.width * 0.85; centerY: win.height * 0.92
                    centerRadius: win.width * 0.6
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: Qt.rgba(win.glowB.r, win.glowB.g, win.glowB.b, 0.5 * win.glowOn) }
                    GradientStop { position: 1; color: Qt.rgba(win.glowB.r, win.glowB.g, win.glowB.b, 0) }
                }
                startX: 0; startY: 0
                PathLine { x: win.width; y: 0 }
                PathLine { x: win.width; y: win.height }
                PathLine { x: 0; y: win.height }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    // ---- Library view ----
    Item {
        anchors.fill: parent
        visible: !win.expanded

        Sidebar {
            id: side
            width: 230
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            view: win.view
            onSelect: (v) => win.goto(v)
            onProfileClicked: { if (account.signedIn) win.goto("profile"); else win.authOpen = true }
            onSourceSelected: (id) => {
                library.source = id
                if (win.view === "profile" || win.view === "playlists") win.goto("songs")
            }
            onAddServerRequested: win.addServerOpen = true
            onUpdateClicked: { settingsPanel.cat = "updates"; win.settingsOpen = true }
        }

        Item {
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: bar.top; bottomMargin: 12 }

            Row {
                id: heading
                x: 36; y: 26
                z: 5
                spacing: 12
                Text {
                    text: library.filterKind !== "" ? "‹ " + library.filterName
                        : (win.view === "albums" ? "Albums" : win.view === "artists" ? "Artists" : win.view === "playlists" ? "Playlists" : win.view === "profile" ? "Profile" : "Songs")
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                    color: win.pri
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.parent.width - 140)
                    MouseArea {
                        anchors.fill: parent
                        enabled: library.filterKind !== ""
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.goto(win.backView || "songs")
                    }
                }
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
                            const p = srcChip.mapToItem(null, 0, srcChip.height)
                            win.srcX = p.x
                            win.srcY = p.y
                            win.sortOpen = false
                            win.sourceOpen = !win.sourceOpen
                        }
                    }
                }
            }

            ProfilePage {
                visible: win.view === "profile"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 90 }
                onSignInRequested: win.authOpen = true
                onImageRequested: (kind) => { imagePopup.kind = kind; imagePopup.visible = true }
            }
            SongList {
                visible: win.view === "songs"
                onMenuRequested: (path, gx, gy) => { win.menuPath = path; win.menuX = gx; win.menuY = gy }
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 90 }
            }
            Carousel {
                id: albumFlow
                kind: "album"
                searching: win.searchOpen && win.view === "albums"
                visible: win.view === "albums"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 70 }
                onPicked: (key, name) => win.pick("album", key, name)
            }
            Carousel {
                id: artistFlow
                kind: "artist"
                searching: win.searchOpen && win.view === "artists"
                visible: win.view === "artists"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 70 }
                onPicked: (key, name) => win.pick("artist", key, name)
            }
            Carousel {
                id: playlistFlow
                kind: "playlist"
                searching: win.searchOpen && win.view === "playlists"
                visible: win.view === "playlists"
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 70 }
                onPicked: (key, name) => win.openPlaylist(key, name)
            }
        }

        SearchBar {
            id: searchBar
            z: 40
            visible: win.searchOpen
            kind: win.view === "albums" ? "album" : win.view === "artists" ? "artist" : "playlist"
            suggestions: win.view !== "songs"
            x: side.width + (parent.width - side.width - width) / 2
            y: 18
            onTyped: (q) => { if (win.view === "songs") library.search = q }
            onChosen: (item) => {
                (win.view === "albums" ? albumFlow : win.view === "artists" ? artistFlow : playlistFlow).focusKey(item.key)
            }
            onClosed: win.searchOpen = false
        }
        MouseArea { z: 29; anchors.fill: parent; visible: win.sortOpen || win.sourceOpen; onClicked: { win.sortOpen = false; win.sourceOpen = false } }
        Rectangle {
            z: 30
            visible: win.sortOpen && win.view === "songs"
            x: side.width + 36
            y: 72
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
            x: Math.min(win.srcX, win.width - width - 10)
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
            anchors { left: side.right; leftMargin: 20; right: parent.right; rightMargin: 20; bottom: parent.bottom; bottomMargin: 16 }
            onExpand: win.expanded = true
        }
    }

    ExpandedPlayer {
        anchors.fill: parent
        visible: win.expanded
        onCollapse: win.expanded = false
    }

    IconButton {
        z: 10
        visible: !win.settingsOpen
        anchors { right: parent.right; rightMargin: 76; top: parent.top; topMargin: 18 }
        name: "search"; box: 44; iconSize: 22
        onClicked: win.searchOpen = !win.searchOpen
    }

    IconButton {
        z: 10
        visible: !win.settingsOpen            // hidden while the settings box is open
        anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 18 }
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
        z: 20
        visible: win.settingsOpen
        width: 540
        anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 16; bottom: parent.bottom; bottomMargin: win.expanded ? 16 : 88 }
        onClose: win.settingsOpen = false
        onAddServerRequested: { win.settingsOpen = false; win.addServerOpen = true }
    }

    AuthPanel {
        id: auth
        z: 58
        anchors.fill: parent
        visible: win.authOpen
        onCloseRequested: win.authOpen = false
    }

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
        x: Math.min(win.menuX, win.width - width - 10)
        y: Math.min(win.menuY, win.height - height - 10)
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

    Shortcut { sequence: "Space"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.toggle() }
    Shortcut { sequence: "Left"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen && (win.expanded || win.view === "songs"); onActivated: player.seek(player.position - 5) }
    Shortcut { sequence: "Right"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen && (win.expanded || win.view === "songs"); onActivated: player.seek(player.position + 5) }
    Shortcut { sequence: "N"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.next() }
    Shortcut { sequence: "P"; enabled: !win.settingsOpen && !win.searchOpen && !prompt.visible && !imagePopup.visible && !win.authOpen && !win.addServerOpen; onActivated: player.prev() }
    Shortcut { sequence: "Escape"; onActivated: { if (win.addServerOpen) win.addServerOpen = false; else if (win.authOpen) win.authOpen = false; else if (imagePopup.visible) imagePopup.visible = false; else if (prompt.visible) prompt.visible = false; else if (win.menuPath !== "") win.menuPath = ""; else if (win.sourceOpen) win.sourceOpen = false; else if (win.searchOpen) win.searchOpen = false; else if (win.settingsOpen) win.settingsOpen = false; else win.expanded = false } }
}
