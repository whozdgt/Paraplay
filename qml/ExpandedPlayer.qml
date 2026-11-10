import QtQuick
import QtQuick.Layouts

Item {
    id: root
    signal collapse()
    readonly property bool phone: width < 720          // on a phone the lyrics replace the cover instead of sitting beside it
    property bool lyricsOpen: false
    readonly property bool lyricsMode: phone && settings.lyrics && lyricsOpen
    readonly property color boxBg: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.5)
    readonly property bool lyricsButton: phone && settings.lyrics
    readonly property real extra: lyricsButton ? 66 : 0     // room taken by the lyrics button under the controls
    readonly property real availW: (settings.lyrics && !phone) ? width - 380 : width
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    IconButton {
        anchors { left: parent.left; leftMargin: 20; top: parent.top; topMargin: 18 }
        filled: true
        name: "down"; box: 44; iconSize: 22
        onClicked: root.collapse()
    }

    ColumnLayout {
        id: center
        x: (root.availW - width) / 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: 26

        Cover {
            visible: !root.lyricsMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(140, Math.min(settings.round ? 360 : 300, root.height - 340 - root.extra, root.availW - 64))
            Layout.preferredHeight: Layout.preferredWidth
            source: player.coverSource
            record: settings.recordCover
            spinning: player.playing
            turnable: settings.recordCover
            onClicked: if (root.phone && settings.lyrics) root.lyricsOpen = true
        }
        LyricsView {
            visible: root.lyricsMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.availW - 32
            Layout.preferredHeight: Math.max(140, root.height - 410 - root.extra)
            centered: true
            fontSize: 18
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: root.availW - 40; elide: Text.ElideRight; text: player.hasTrack ? player.title : "Nothing playing"; font.pixelSize: root.phone ? 22 : 26; font.weight: settings.round ? Font.Black : Font.DemiBold; color: root.pri }
            Text { Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: root.availW - 40; elide: Text.ElideRight; text: player.artist; font.pixelSize: 15; color: settings.round ? settings.inkSoft : root.muted }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                visible: settings.badges && player.hasTrack
                implicitWidth: chip.implicitWidth + 24
                implicitHeight: chip.implicitHeight + (settings.round ? 14 : 10)
                radius: settings.round ? height / 2 : 0
                color: settings.round ? settings.chipFill : root.boxBg
                Rectangle { visible: !settings.round; width: 3; height: parent.height; color: settings.accent }
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
            IconButton { anchors.verticalCenter: parent.verticalCenter; name: settings.round ? "rw" : "prev"; box: settings.round ? 56 : 44; iconSize: settings.round ? 32 : 22; onClicked: player.prev() }
            IconButton { anchors.verticalCenter: parent.verticalCenter; name: player.playing ? "pause" : "play"; box: settings.round ? 80 : 64; iconSize: settings.round ? 30 : 26; bg: root.pri; fg: settings.onInk; onClicked: player.toggle() }
            IconButton { anchors.verticalCenter: parent.verticalCenter; name: settings.round ? "ff" : "next"; box: settings.round ? 56 : 44; iconSize: settings.round ? 32 : 22; onClicked: player.next() }
        }
        Rectangle {
            visible: root.lyricsButton
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.max(168, btnRow.implicitWidth + 40)
            Layout.preferredHeight: settings.round ? 44 : 40
            radius: settings.round ? height / 2 : 0
            color: root.lyricsMode ? root.pri : (settings.round ? settings.glass : "transparent")
            border.width: settings.round ? 0 : 1
            border.color: root.pri
            Row {
                id: btnRow
                anchors.centerIn: parent
                spacing: 10
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "lyrics"; size: 18; color: root.lyricsMode ? settings.onInk : root.pri }
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Lyrics"; font.pixelSize: 14; font.weight: settings.round ? Font.Bold : Font.Normal; color: root.lyricsMode ? settings.onInk : root.pri }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.lyricsOpen = !root.lyricsOpen }
        }
        RowLayout {
            visible: !settings.mobile        // phones have volume keys
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
