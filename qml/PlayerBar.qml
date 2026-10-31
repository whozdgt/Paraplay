import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    signal expand()
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    height: 64
    color: Qt.rgba(1, 1, 1, 0.5)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.8)

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
            Layout.preferredWidth: 150
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
            visible: settings.badges && player.hasTrack
            line1: player.hires ? "HI-RES " + player.codec : player.codec
            line2: player.quality
        }
        Item { Layout.fillWidth: true }
        Row {
            spacing: 4
            IconButton { name: "prev"; box: 36; onClicked: player.prev() }
            IconButton { name: player.playing ? "pause" : "play"; box: 40; iconSize: 18; bg: root.pri; fg: "white"; onClicked: player.toggle() }
            IconButton { name: "next"; box: 36; onClicked: player.next() }
        }
        Progress { Layout.preferredWidth: 200 }
    }

}
