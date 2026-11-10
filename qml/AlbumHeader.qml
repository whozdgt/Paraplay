import QtQuick

// Midnight: the top of an album, artist or playlist page. The cover (or the artist's photo) in the middle,
// the name under it, and Shuffle and Play.
Item {
    id: root
    readonly property string kind: library.filterKind          // album | artist | playlist
    readonly property var entry: {
        library.revision
        playlists.revision
        if (kind === "") return null
        const list = kind === "playlist" ? playlists.list() : library.groups(kind)
        for (let i = 0; i < list.length; ++i)
            if (list[i].name === library.filterName) return list[i]
        return null
    }
    readonly property real art: Math.min(240, width - 120)
    implicitHeight: col.implicitHeight + 28

    Column {
        id: col
        width: parent.width
        spacing: 0

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.art; height: root.art
            CoverTile {
                visible: root.kind !== "artist"
                anchors.fill: parent
                entry: root.entry
                kind: root.kind === "playlist" ? "playlist" : "album"
            }
            ArtistPhoto {
                visible: root.kind === "artist"
                anchors.fill: parent
                name: root.kind === "artist" ? library.filterName : ""
            }
        }
        Text {
            topPadding: 18
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: library.filterName
            font.pixelSize: 24
            font.weight: Font.Black
            font.letterSpacing: -0.5
            color: settings.ink
        }
        Text {
            visible: text !== ""
            topPadding: 2
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.kind === "album" && root.entry ? root.entry.sub
                : root.kind === "artist" ? "Artist"
                : root.kind === "playlist" ? "Playlist" : ""
            font.pixelSize: 15
            color: settings.inkSoft
        }
        Item { width: 1; height: 18 }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                name: "shuffle"; box: 52; iconSize: 22; filled: true
                Accessible.name: "Shuffle"
                onClicked: player.playShuffled()
            }
            Rectangle {
                id: playBtn
                width: 168; height: 52
                radius: 26
                color: "white"
                Accessible.role: Accessible.Button
                Accessible.name: "Play"
                Accessible.onPressAction: player.playRow(0)
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "play"; size: 18; color: "black" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Play"; font.pixelSize: 17; font.weight: Font.Black; color: "black" }
                }
                Rectangle { anchors.fill: parent; radius: parent.radius; color: "black"; opacity: playMa.pressed ? 0.12 : 0 }
                MouseArea { id: playMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.playRow(0) }
            }
        }
    }
}
