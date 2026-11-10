import QtQuick

// The words of the song that is playing. Synced lyrics follow the music (tap a line to jump to it);
// plain lyrics just scroll. Used on the right of the expanded player on a computer, and in place
// of the cover on a phone.
Item {
    id: root
    property bool centered: false
    property real fontSize: 16
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.62)
    readonly property bool synced: player.lyricSynced
    readonly property bool android: settings.mobile
    readonly property string message: {
        const s = player.lyricState
        if (s === "searching") return "Looking for lyrics…"
        if (s === "offline") return "Couldn't reach the lyrics service.\nIt will try again next time the song plays."
        if (s === "instrumental") return "Instrumental"
        if (settings.onlineLyrics) return "No lyrics found for this song."
        return android ? "No lyrics found.\nTurn on “Look up lyrics online” in Settings to search for them."
                       : "No lyrics found.\nPut a .lrc file with the same name next to the song, or turn on “Look up lyrics online” in Settings."
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 20
        visible: player.lyricLines.length === 0
        horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
        wrapMode: Text.Wrap
        lineHeight: 1.3
        font.pixelSize: 14
        color: root.muted
        text: root.message
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: player.lyricLines.length > 0
        clip: true
        model: player.lyricLines
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.synced ? player.lyricIndex : -1
        highlightRangeMode: root.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.36
        preferredHighlightEnd: height * 0.56
        highlightMoveDuration: 420
        header: Item { width: list.width; height: list.height * 0.36 }
        footer: Item {
            width: list.width
            height: list.height * 0.6
            Text {
                visible: player.lyricState === "online"
                y: 14
                x: root.centered ? (parent.width - width) / 2 : 17
                text: "Lyrics from LRCLIB"
                font.pixelSize: 11
                color: root.muted
            }
        }
        delegate: Item {
            id: row
            required property int index
            required property string modelData
            readonly property bool active: root.synced && index === player.lyricIndex
            readonly property string shown: modelData !== "" ? modelData : (root.synced ? "♪" : "")
            width: list.width
            height: shown === "" ? 16 : label.implicitHeight + 16
            Text {
                id: label
                x: root.centered ? 10 : 17
                width: parent.width - (root.centered ? 20 : 17)
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
                wrapMode: Text.Wrap
                text: row.shown
                font.pixelSize: row.active ? root.fontSize + 3 : root.fontSize
                font.weight: row.active ? Font.DemiBold : Font.Normal
                color: (row.active || !root.synced) ? root.pri : root.muted
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Rectangle {
                visible: row.active && !root.centered && row.shown !== ""
                width: 3; height: label.height
                anchors.verticalCenter: parent.verticalCenter
                color: settings.accent
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.synced
                onClicked: player.seekToLyric(row.index)
            }
        }
    }

    // A new song starts at the top.
    Connections {
        target: player
        function onLyricsChanged() { Qt.callLater(list.positionViewAtBeginning) }
    }
}
