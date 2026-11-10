import QtQuick

// A row of albums or playlists to flick through, with a link to the whole page.
Item {
    id: root
    property string kind: "album"           // album | playlist
    property string heading
    property bool compact: false
    signal picked(string key, string name)
    signal seeAll()
    readonly property int tile: compact ? 124 : 156
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property var items: {
        if (kind === "playlist") { playlists.revision; return playlists.list() }
        library.revision
        return library.groups(kind)
    }
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        HomeHeading { width: parent.width; text: root.heading; link: root.items.length > 0 ? "See all" : ""; onActivated: root.seeAll() }
        ListView {
            visible: root.items.length > 0
            width: parent.width
            height: root.tile + 48
            orientation: ListView.Horizontal
            spacing: 14
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.items.slice(0, 20)
            delegate: Item {
                id: cell
                required property var modelData
                width: root.tile
                height: ListView.view.height
                Column {
                    width: parent.width
                    spacing: 6
                    CoverTile { width: root.tile; height: root.tile; entry: cell.modelData; kind: root.kind }
                    Column {
                        width: parent.width
                        Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; color: root.pri }
                        Text { width: parent.width; text: cell.modelData.sub; elide: Text.ElideRight; font.pixelSize: 11; color: root.muted }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(cell.modelData.key, cell.modelData.name) }
            }
        }
        Text {
            visible: root.items.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 12
            color: root.muted
            text: root.kind === "playlist" ? "No playlists yet. Open Playlists to make one."
                : library.scanning ? "Scanning your music…"
                : "No albums yet. Set your music folder in Settings, or add a server."
        }
    }
}
