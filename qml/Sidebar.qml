import QtQuick

Rectangle {
    id: root
    property string view
    property bool homeOpen: true
    property bool streamOpen: false
    property bool drawer: false          // phone: slides over the page, so it needs a solid background
    signal select(string v)
    signal profileClicked()
    signal socialSelected(string tab)       // activity | find | requests
    property string socialTab: "activity"
    signal sourceSelected(string id)       // "" = all sources, "local", or a server id
    signal addServerRequested()
    signal updateClicked()
    readonly property color pri: settings.primary
    readonly property bool hasServers: servers.count > 0

    color: drawer ? settings.bgColor : Qt.rgba(1, 1, 1, 0.28)
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.55) }

    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: chip.top; leftMargin: 16; rightMargin: 16; topMargin: 26 }
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            Item {
                width: parent.width
                height: 60
                Row {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Avatar { width: 34; height: 34; source: account.signedIn ? account.avatarUrl : "" }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            width: 140; elide: Text.ElideRight
                            text: account.signedIn ? (account.displayName || account.username) : "Guest"
                            font.pixelSize: 14; font.weight: Font.DemiBold; color: root.pri
                        }
                        Text {
                            width: 140; elide: Text.ElideRight
                            text: account.signedIn ? "@" + account.username : "Not signed in"
                            font.pixelSize: 10; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                        }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.profileClicked() }
            }
            NavItem { width: parent.width; text: "Home"; chevron: true; open: root.homeOpen; onClicked: root.homeOpen = !root.homeOpen }
            Column {
                width: parent.width
                visible: root.homeOpen
                NavItem { width: parent.width; sub: true; text: "Songs"; active: root.view === "songs"; onClicked: root.select("songs") }
                NavItem { width: parent.width; sub: true; text: "Albums"; active: root.view === "albums"; onClicked: root.select("albums") }
                NavItem { width: parent.width; sub: true; text: "Artists"; active: root.view === "artists"; onClicked: root.select("artists") }
                NavItem { width: parent.width; sub: true; text: "Playlists"; active: root.view === "playlists"; onClicked: root.select("playlists") }
            }
            Text {
                text: "SOCIAL"
                font.pixelSize: 11
                font.letterSpacing: 1
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                leftPadding: 12
                topPadding: 22
                bottomPadding: 6
            }
            NavItem {
                width: parent.width; text: "Friends"
                active: (root.view === "friends" && root.socialTab === "activity") || root.view === "user" || root.view === "friendpl"
                onClicked: root.socialSelected("activity")
            }
            NavItem {
                width: parent.width; text: "Find people"
                active: root.view === "friends" && root.socialTab === "find"
                onClicked: root.socialSelected("find")
            }
            NavItem {
                width: parent.width; text: "Requests"
                active: root.view === "friends" && root.socialTab === "requests"
                onClicked: root.socialSelected("requests")
                Rectangle {      // follow requests waiting for you
                    visible: social.requestCount > 0
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: Math.max(18, cnt.implicitWidth + 10); height: 18
                    color: settings.accent
                    Text { id: cnt; anchors.centerIn: parent; text: social.requestCount; font.pixelSize: 11; color: "white" }
                }
            }
            NavItem { width: parent.width; text: "My profile"; active: root.view === "profile"; onClicked: root.profileClicked() }
            Text {
                text: "SOURCES"
                font.pixelSize: 11
                font.letterSpacing: 1
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                leftPadding: 12
                topPadding: 22
                bottomPadding: 6
            }
            NavItem {
                visible: root.hasServers
                width: parent.width; text: "All sources"
                active: library.source === ""
                onClicked: root.sourceSelected("")
            }
            NavItem {
                width: parent.width; text: "This computer"
                active: library.source === "local" || (!root.hasServers && library.source === "")
                onClicked: root.sourceSelected("local")
            }
            Repeater {
                model: { servers.revision; return servers.list() }
                NavItem {
                    id: srvItem
                    required property var modelData
                    width: col.width
                    text: modelData.name
                    dim: !modelData.enabled
                    active: library.source === modelData.id
                    onClicked: root.sourceSelected(modelData.id)
                    Rectangle {      // sign-in / sync state: green = ready, amber = loading, red = a problem
                        width: 8; height: 8
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        color: srvItem.modelData.state === "ok" ? settings.accent
                             : srvItem.modelData.state === "syncing" ? "#d97706"
                             : srvItem.modelData.state === "error" ? "#b91c1c"
                             : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                    }
                }
            }
            NavItem { width: parent.width; text: "Add a server…"; onClicked: root.addServerRequested() }
            NavItem { width: parent.width; text: "Streaming services"; chevron: true; open: root.streamOpen; onClicked: root.streamOpen = !root.streamOpen }
            Column {
                width: parent.width
                visible: root.streamOpen
                NavItem { width: parent.width; sub: true; dim: true; text: "Spotify (soon)" }
                NavItem { width: parent.width; sub: true; dim: true; text: "YouTube Music (soon)" }
            }
        }
    }

    // Shows only when a newer release is out.
    Item {
        id: chip
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: updater.available ? 56 : 0
        visible: updater.available
        Rectangle {
            anchors { fill: parent; leftMargin: 16; rightMargin: 16; topMargin: 8; bottomMargin: 8 }
            color: settings.accent
            Text {
                anchors { left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text: "Update available · v" + updater.latest
                elide: Text.ElideRight
                font.pixelSize: 13
                color: "white"
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateClicked() }
        }
    }
}
