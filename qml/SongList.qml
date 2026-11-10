import QtQuick
import QtQuick.Layouts

ListView {
    id: list
    signal menuRequested(string path, real gx, real gy)
    clip: true
    model: library
    reuseItems: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property bool compact: width < 560      // phone: title over artist, no quality column
    readonly property color pri: settings.ink
    readonly property color muted: settings.round ? settings.inkSoft : Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool showHeader: settings.round && library.filterKind !== ""

    // Midnight: an album, artist or playlist page starts with its cover, name, Shuffle and Play
    header: Item {
        width: ListView.view ? ListView.view.width : 0
        height: list.showHeader ? albumHead.implicitHeight : 0
        visible: list.showHeader
        AlbumHeader { id: albumHead; width: parent.width; visible: list.showHeader }
    }

    delegate: Rectangle {
        id: row
        required property int index
        required property string path
        required property string title
        required property string artist
        required property string duration
        required property string badge
        required property bool hires
        required property bool remote
        readonly property bool current: player.path === path

        width: ListView.view.width
        height: settings.round && list.compact ? 62 : 56
        radius: settings.round ? 12 : 0
        color: current ? (settings.solid ? settings.hiSel : Qt.rgba(1, 1, 1, 0.65)) : (ma.containsMouse ? (settings.solid ? settings.hiHover : Qt.rgba(1, 1, 1, 0.3)) : "transparent")

        Rectangle { visible: row.current && !settings.round; width: 3; height: parent.height; color: settings.accent }
        RowLayout {
            z: 1          // above the row's MouseArea, so the ⋮ button gets its taps (the text lets them through)
            anchors { fill: parent; leftMargin: 14; rightMargin: settings.round && list.compact ? 4 : 14 }
            spacing: 0
            Text {
                visible: !list.compact
                Layout.fillWidth: true; Layout.preferredWidth: 100
                text: row.title; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: list.pri
            }
            Text {
                visible: !list.compact
                Layout.fillWidth: true; Layout.preferredWidth: 100
                text: row.artist; elide: Text.ElideRight; font.pixelSize: 14; color: list.muted
            }
            ColumnLayout {
                visible: list.compact
                Layout.fillWidth: true; Layout.preferredWidth: 100
                spacing: 2
                Text { Layout.fillWidth: true; text: row.title; elide: Text.ElideRight; font.pixelSize: settings.round ? 15 : 14; font.weight: settings.round ? Font.Bold : Font.Medium; color: list.pri }
                Text { Layout.fillWidth: true; text: row.artist; elide: Text.ElideRight; font.pixelSize: 12; color: list.muted }
            }
            Item {
                Layout.preferredWidth: 100; Layout.preferredHeight: 20
                visible: settings.badges && !list.compact
                Rectangle { visible: row.hires; width: 3; height: parent.height; color: settings.accent }
                Text {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    text: row.badge; font.pixelSize: 12; color: row.hires ? list.pri : list.muted
                }
            }
            Item {
                Layout.preferredWidth: 28; Layout.preferredHeight: 20
                Icon { visible: row.remote; anchors.centerIn: parent; name: "cloud"; size: 14; color: list.muted }
            }
            Text { visible: !(settings.round && list.compact); Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: row.duration; font.pixelSize: 14; color: list.muted }
            IconButton {      // Midnight, phone: the song's menu (add to a playlist…), as well as a long press
                visible: settings.round && list.compact
                z: 2
                name: "more"; box: 40; iconSize: 20
                onClicked: { const p = mapToItem(null, width / 2, height / 2); list.menuRequested(row.path, p.x, p.y) }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => {
                if (m.button === Qt.RightButton) { const p = row.mapToItem(null, m.x, m.y); list.menuRequested(row.path, p.x, p.y) }
                else player.playRow(row.index)
            }
            onPressAndHold: (m) => { const p = row.mapToItem(null, m.x, m.y); list.menuRequested(row.path, p.x, p.y) }   // touch screens
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        horizontalAlignment: Text.AlignHCenter
        color: list.muted
        text: library.scanning ? "Scanning your music…" : "No music found.\nSet your music folder in Settings, or add a server."
    }
}
