import QtQuick

// Covers in a grid, for albums, artists and playlists. Used on phones, where the Cover Flow has no room.
GridView {
    id: grid
    property string kind: "album"          // album | artist | playlist
    property bool active: true             // false = hold nothing in memory (the Cover Flow is showing instead)
    property bool searching: false         // not used here; lets the grid stand in for the Cover Flow
    signal picked(string key, string name)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property color pri: settings.primary
    readonly property var items: {
        if (!active) return []
        if (kind === "playlist") { playlists.revision; return playlists.list() }
        library.revision
        return library.groups(kind)
    }
    readonly property int cols: Math.max(2, Math.floor(width / 170))
    cellWidth: Math.floor(width / cols)
    cellHeight: cellWidth + 54
    model: items
    cacheBuffer: 400

    // A search result was chosen: scroll to it.
    function focusKey(key) {
        for (let i = 0; i < items.length; ++i)
            if (items[i].key === key) { positionViewAtIndex(i, GridView.Beginning); return }
    }

    delegate: Item {
        id: cell
        required property var modelData
        width: grid.cellWidth
        height: grid.cellHeight
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 6
            CoverTile { width: parent.width; height: width; entry: cell.modelData; kind: grid.kind }
            Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: grid.pri }
            Text { width: parent.width; text: cell.modelData.sub; elide: Text.ElideRight; font.pixelSize: 12; color: Qt.rgba(grid.pri.r, grid.pri.g, grid.pri.b, 0.72) }
        }
        MouseArea { anchors.fill: parent; onClicked: grid.picked(cell.modelData.key, cell.modelData.name) }
    }

    Text {
        anchors.centerIn: parent
        visible: grid.items.length === 0 && grid.active
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.4
        color: Qt.rgba(grid.pri.r, grid.pri.g, grid.pri.b, 0.72)
        text: library.scanning ? "Scanning your music…"
            : grid.kind === "playlist" ? "No playlists yet.\nTap “New playlist” above to make one."
            : "Nothing here yet."
    }
}
