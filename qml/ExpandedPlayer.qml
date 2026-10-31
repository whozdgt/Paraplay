import QtQuick
import QtQuick.Layouts

Item {
    id: root
    signal collapse()
    readonly property bool phone: width < 720          // lyrics move out of the way on a phone
    readonly property real availW: (settings.lyrics && !phone) ? width - 380 : width
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    IconButton {
        anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 18 }
        name: "down"; box: 44; iconSize: 22; bg: Qt.rgba(1, 1, 1, 0.5)
        onClicked: root.collapse()
    }

    ColumnLayout {
        id: center
        x: (root.availW - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Cover {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(140, Math.min(300, root.height - 340, root.availW - 64))
            Layout.preferredHeight: Layout.preferredWidth
            source: player.coverSource
            record: settings.recordCover
            spinning: player.playing
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: root.availW - 40; elide: Text.ElideRight; text: player.hasTrack ? player.title : "Nothing playing"; font.pixelSize: root.phone ? 22 : 26; font.weight: Font.DemiBold; color: root.pri }
            Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: root.availW - 40; elide: Text.ElideRight; text: player.artist; font.pixelSize: 15; color: root.muted }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                visible: settings.badges && player.hasTrack
                implicitWidth: chip.implicitWidth + 24
                implicitHeight: chip.implicitHeight + 10
                color: Qt.rgba(1, 1, 1, 0.5)
                Rectangle { width: 3; height: parent.height; color: settings.accent }
                Text {
                    id: chip
                    anchors.centerIn: parent
                    text: (player.hires ? player.codec + " · " + player.quality + " · HI-RES" : player.codec + " · " + player.quality)
                    font.pixelSize: 11
                    color: root.pri
                }
            }
        }
        Progress { Layout.preferredWidth: Math.min(440, root.availW - 48); Layout.alignment: Qt.AlignHCenter }
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 28
            IconButton { name: "prev"; box: 44; iconSize: 22; onClicked: player.prev() }
            IconButton { name: player.playing ? "pause" : "play"; box: 64; iconSize: 26; bg: root.pri; fg: "white"; onClicked: player.toggle() }
            IconButton { name: "next"; box: 44; iconSize: 22; onClicked: player.next() }
        }
        RowLayout {
            visible: Qt.platform.os !== "android"        // phones have volume keys
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            Icon { name: "volume"; size: 20; color: root.pri }
            Slider255 { Layout.preferredWidth: 180; maxValue: 100; value: settings.volume; onMoved: (v) => settings.volume = v }
            Text { text: settings.volume + "%"; font.pixelSize: 12; color: root.muted }
        }
    }

    Item {
        id: lyr
        visible: settings.lyrics && !root.phone
        width: 340
        anchors { right: parent.right; rightMargin: 48; top: parent.top; topMargin: 88; bottom: parent.bottom; bottomMargin: 72 }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 18
            Text { text: "LYRICS"; font.pixelSize: 11; font.letterSpacing: 1; color: root.muted }
            Repeater {
                model: player.lyricLines.length > 0 ? 7 : 0
                Text {
                    required property int index
                    readonly property int idx: player.lyricIndex - 3 + index
                    readonly property bool active: index === 3
                    width: lyr.width
                    leftPadding: 17
                    wrapMode: Text.Wrap
                    text: idx >= 0 && idx < player.lyricLines.length ? player.lyricLines[idx] : ""
                    font.pixelSize: active ? 20 : 16
                    font.weight: active ? Font.DemiBold : Font.Normal
                    color: active ? root.pri : root.muted
                    Rectangle { visible: parent.active && parent.text !== ""; width: 3; height: parent.height; color: settings.accent }
                }
            }
            Text {
                visible: player.lyricLines.length === 0
                width: parent.width
                wrapMode: Text.Wrap
                color: root.muted
                font.pixelSize: 14
                text: "No lyrics found.\nPut a .lrc file with the same name next to the song."
            }
        }
    }
}
