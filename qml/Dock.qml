import QtQuick

// Phones: the bar along the bottom. A mini player floats above four tabs (Home, Library, Friends, Search).
// Scrolling down tucks the tabs away: what is left is one button for the page you are on, the mini player and Search.
Item {
    id: root
    property bool collapsed: false
    property string current: "home"           // home | library | friends | search
    signal tab(string k)
    signal expandPlayer()
    signal untuck()                            // bring the tabs back

    readonly property bool hasTrack: player.hasTrack
    readonly property bool tucked: collapsed && hasTrack       // with nothing playing there is nothing to tuck beside
    readonly property real fullHeight: (hasTrack ? 60 + 8 : 0) + 64
    readonly property var tabs: [
        { k: "home", t: "Home", icon: "home", on: "homefill" },
        { k: "library", t: "Library", icon: "library", on: "library" },
        { k: "friends", t: "Friends", icon: "friends", on: "friends" },
        { k: "search", t: "Search", icon: "search", on: "search" }
    ]
    readonly property var easing: [0.2, 0, 0, 1, 1, 1]

    height: tucked ? 64 : fullHeight
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easing } }

    // ---- the four tabs ----
    Rectangle {
        id: tabBar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 64
        radius: settings.round ? 32 : 0
        color: settings.glass
        border.width: 1
        border.color: settings.glassLine
        opacity: root.tucked ? 0 : 1
        scale: root.tucked ? 0.92 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easing } }

        Row {
            anchors { fill: parent; margins: 5 }
            spacing: 2
            Repeater {
                model: root.tabs
                Rectangle {
                    id: tabItem
                    required property var modelData
                    readonly property bool on: root.current === modelData.k
                    width: (tabBar.width - 10 - 6) / 4
                    height: 54
                    radius: settings.round ? 27 : 0
                    color: on ? (settings.round ? Qt.rgba(1, 1, 1, 0.13) : settings.hiSel) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.t
                    Accessible.selected: on
                    Accessible.onPressAction: root.tab(modelData.k)
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: tabItem.on ? tabItem.modelData.on : tabItem.modelData.icon; size: 24; color: settings.ink }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tabItem.modelData.t
                            font.pixelSize: 11
                            font.weight: tabItem.on ? Font.Bold : Font.Normal
                            color: settings.ink
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.tab(tabItem.modelData.k) }
                }
            }
        }
    }

    // ---- tucked away: the page you are on, and Search ----
    Rectangle {
        id: here
        width: 64; height: 64
        radius: settings.round ? 32 : 0
        color: settings.glass
        border.width: 1
        border.color: settings.glassLine
        opacity: root.tucked ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Accessible.role: Accessible.Button
        Accessible.name: "Show the tabs"
        Accessible.onPressAction: root.untuck()
        Icon {
            anchors.centerIn: parent
            size: 26
            color: settings.ink
            name: root.current === "home" ? "homefill" : root.current === "friends" ? "friends" : "library"
        }
        MouseArea { anchors.fill: parent; onClicked: root.untuck() }
    }
    Rectangle {
        anchors.right: parent.right
        width: 64; height: 64
        radius: settings.round ? 32 : 0
        color: settings.glass
        border.width: 1
        border.color: settings.glassLine
        opacity: root.tucked ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Accessible.role: Accessible.Button
        Accessible.name: "Search"
        Accessible.onPressAction: root.tab("search")
        Icon { anchors.centerIn: parent; name: "search"; size: 26; color: settings.ink }
        MouseArea { anchors.fill: parent; onClicked: root.tab("search") }
    }

    // ---- the mini player ----
    PlayerBar {
        id: mini
        visible: root.hasTrack
        height: 60
        x: root.tucked ? 72 : 0
        y: root.tucked ? 2 : 0
        width: root.tucked ? root.width - 144 : root.width
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easing } }
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easing } }
        Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: root.easing } }
        onExpand: root.expandPlayer()
    }
}
