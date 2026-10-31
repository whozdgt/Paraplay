import QtQuick
import QtQuick.Layouts

Item {
    id: root
    signal collapse()
    readonly property bool phone: width < 720          // on a phone the lyrics replace the cover instead of sitting beside it
    property bool lyricsOpen: false
    readonly property bool lyricsMode: phone && settings.lyrics && lyricsOpen
    readonly property color boxBg: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.5)
    readonly property real availW: (settings.lyrics && !phone) ? width - 380 : width
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    IconButton {
        anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 18 }
        name: "down"; box: 44; iconSize: 22; bg: root.boxBg
        onClicked: root.collapse()
    }
    IconButton {
        visible: root.phone && settings.lyrics
        anchors { right: parent.right; rightMargin: 20; top: parent.top; topMargin: 18 }
        name: "lyrics"; box: 44; iconSize: 22
        bg: root.lyricsMode ? root.pri : root.boxBg
        fg: root.lyricsMode ? "white" : root.pri
        onClicked: root.lyricsOpen = !root.lyricsOpen
    }

    ColumnLayout {
        id: center
        x: (root.availW - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Cover {
            visible: !root.lyricsMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(140, Math.min(300, root.height - 340, root.availW - 64))
            Layout.preferredHeight: Layout.preferredWidth
            source: player.coverSource
            record: settings.recordCover
            spinning: player.playing
            onClicked: if (root.phone && settings.lyrics) root.lyricsOpen = true
        }
        LyricsView {
            visible: root.lyricsMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.availW - 32
            Layout.preferredHeight: Math.max(140, root.height - 410)
            centered: true
            fontSize: 18
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
                color: root.boxBg
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
        Text { id: lyrLabel; text: "LYRICS"; font.pixelSize: 11; font.letterSpacing: 1; color: root.muted }
        LyricsView {
            anchors { top: lyrLabel.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom }
            fontSize: 16
        }
    }
}
