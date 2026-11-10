import QtQuick

// A row of albums or playlists to flick through, with a link to the whole page.
Item {
    id: root
    property string kind: "album"           // album | playlist
    property string heading
    property bool compact: false
    signal picked(string key, string name)
    signal seeAll()
    // Midnight shows albums as big cards with the name over the picture, and everything else as bigger squares
    readonly property bool cards: settings.round && kind === "album"
    readonly property int tile: cards ? (compact ? 220 : 236) : settings.round ? (compact ? 150 : 170) : (compact ? 124 : 156)
    readonly property int tileH: cards ? Math.round(tile * 1.28) : tile
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
            height: root.cards ? root.tileH : root.tile + 48
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
                    visible: !root.cards
                    width: parent.width
                    spacing: 6
                    CoverTile { width: root.tile; height: root.tile; entry: cell.modelData; kind: root.kind }
                    Column {
                        width: parent.width
                        Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: settings.round ? 14 : 13; font.weight: settings.round ? Font.Bold : Font.Medium; color: root.pri }
                        Text { width: parent.width; text: cell.modelData.sub; elide: Text.ElideRight; font.pixelSize: settings.round ? 13 : 11; color: settings.round ? settings.inkSoft : root.muted }
                    }
                }
                Item {      // Midnight: a big card, the name over the bottom of the picture
                    visible: root.cards
                    width: root.tile; height: root.tileH
                    CoverTile { anchors.fill: parent; entry: cell.modelData; kind: root.kind }
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: parent.height * 0.5
                        radius: settings.round ? 18 : 0
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                            GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) }
                        }
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                        spacing: 2
                        Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: 17; font.weight: Font.Black; color: "white" }
                        Text { width: parent.width; text: cell.modelData.sub; elide: Text.ElideRight; font.pixelSize: 13; color: Qt.rgba(1, 1, 1, 0.82) }
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
