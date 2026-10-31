import QtQuick

// The first few songs, and a link to the whole list.
Item {
    id: root
    signal seeAll()
    signal menuRequested(string path, real gx, real gy)
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        HomeHeading { width: parent.width; text: "SONGS"; link: list.count > 0 ? "See all" : ""; onActivated: root.seeAll() }
        ListView {
            id: list
            width: parent.width
            height: Math.min(count, 6) * 56
            interactive: false
            clip: true
            model: library
            delegate: Rectangle {
                id: row
                required property int index
                required property string path
                required property string title
                required property string artist
                required property string duration
                required property bool remote
                readonly property bool current: player.path === path
                width: ListView.view.width
                height: 56
                color: current ? (settings.solid ? settings.hiSel : Qt.rgba(1, 1, 1, 0.65)) : (ma.containsMouse ? (settings.solid ? settings.hiHover : Qt.rgba(1, 1, 1, 0.3)) : "transparent")
                Rectangle { visible: row.current; width: 3; height: parent.height; color: settings.accent }
                Column {
                    anchors { left: parent.left; leftMargin: 14; right: dur.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text { width: parent.width; text: row.title; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: root.pri }
                    Text { width: parent.width; text: row.artist; elide: Text.ElideRight; font.pixelSize: 12; color: root.muted }
                }
                Icon { visible: row.remote; anchors { right: dur.left; rightMargin: 10; verticalCenter: parent.verticalCenter } name: "cloud"; size: 14; color: root.muted }
                Text { id: dur; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: row.duration; font.pixelSize: 13; color: root.muted }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (m) => {
                        if (m.button === Qt.RightButton) { const p = row.mapToItem(null, m.x, m.y); root.menuRequested(row.path, p.x, p.y) }
                        else player.playRow(row.index)
                    }
                    onPressAndHold: (m) => { const p = row.mapToItem(null, m.x, m.y); root.menuRequested(row.path, p.x, p.y) }
                }
            }
        }
        Text {
            visible: list.count === 0
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 12
            color: root.muted
            text: library.scanning ? "Scanning your music…" : "No music found. Set your music folder in Settings, or add a server."
        }
    }
}
