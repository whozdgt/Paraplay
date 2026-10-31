import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    signal expand()
    readonly property bool compact: width < 560      // phone: cover, title, play/next and a thin progress line
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    height: 64
    color: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.5)
    border.width: 1
    border.color: settings.solid ? settings.boxLine : Qt.rgba(1, 1, 1, 0.8)

    RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
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
            IconButton { name: player.playing ? "pause" : "play"; box: 40; iconSize: 18; bg: root.pri; fg: "white"; onClicked: player.toggle() }
            IconButton { name: "next"; box: 36; onClicked: player.next() }
        }
        Progress { visible: !root.compact; Layout.preferredWidth: 200 }
    }

    Rectangle {     // phone: the song's progress as a thin line along the bottom
        visible: root.compact
        anchors { left: parent.left; bottom: parent.bottom }
        height: 3
        width: parent.width * (player.duration > 0 ? Math.min(1, player.position / player.duration) : 0)
        color: settings.accent
    }

}
