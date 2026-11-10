import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    signal expand()
    readonly property bool compact: width < 560      // phone: cover, title, play/next and a thin progress line
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    height: 64
    radius: settings.round ? height / 2 : 0           // Midnight: a frosted pill floating over the page
    color: settings.glass
    border.width: 1
    border.color: settings.glassLine

    MouseArea {      // tap anywhere on the bar (not a button) to open the player
        anchors.fill: parent
        onClicked: root.expand()
    }

    RowLayout {
        anchors { fill: parent; leftMargin: settings.round ? 12 : 10; rightMargin: settings.round ? 14 : 10 }
        spacing: 14

        Cover {
            z: 2
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            source: player.coverSource
            record: settings.recordCover
            spinning: player.playing
            hoverScale: 1.7
            onClicked: root.expand()
        }
        ColumnLayout {
            Layout.preferredWidth: root.compact ? 100 : 150
            Layout.fillWidth: root.compact
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: player.hasTrack ? player.title : "Nothing playing"
                elide: Text.ElideRight
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: root.pri
            }
            Text {
                Layout.fillWidth: true
                text: player.source !== "" ? player.artist + "  ·  " + player.source : player.artist
                elide: Text.ElideRight; font.pixelSize: 12; color: root.muted
            }
        }
        QualityChip {
            visible: settings.badges && player.hasTrack && !root.compact
            line1: player.hires ? "HI-RES " + player.codec : player.codec
            line2: player.quality
        }
        Item { Layout.fillWidth: true; visible: !root.compact }
        Row {
            spacing: 4
            IconButton { visible: !root.compact; name: "prev"; box: 36; onClicked: player.prev() }
            IconButton { name: player.playing ? "pause" : "play"; box: 40; iconSize: 18; bg: root.pri; fg: settings.onInk; onClicked: player.toggle() }
            IconButton { name: "next"; box: 36; onClicked: player.next() }
        }
        Progress { visible: !root.compact; Layout.preferredWidth: 200 }
    }

    Rectangle {     // phone: the song's progress as a thin line along the bottom
        visible: root.compact
        readonly property real inset: settings.round ? root.radius : 0
        x: inset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: settings.round ? 3 : 0
        height: settings.round ? 2 : 3
        radius: settings.round ? 1 : 0
        width: (parent.width - 2 * inset) * (player.duration > 0 ? Math.min(1, player.position / player.duration) : 0)
        color: settings.accent
    }

}
