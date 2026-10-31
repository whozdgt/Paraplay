import QtQuick

// The artists you play most. Counted on this device only (see PlayStats).
Item {
    id: root
    property bool compact: false
    signal openArtist(string name)
    readonly property int tile: compact ? 112 : 140
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property var artists: { stats.revision; return stats.topArtists(settings.homeTop === "all" ? 0 : 28, 12) }
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        HomeHeading {
            width: parent.width
            text: "YOUR TOP ARTISTS"
            Repeater {
                model: [{ k: "4w", t: root.compact ? "4 weeks" : "Last 4 weeks" }, { k: "all", t: "All time" }]
                Rectangle {
                    required property var modelData
                    readonly property bool on: settings.homeTop === modelData.k
                    width: lbl.implicitWidth + 24
                    height: 36
                    color: on ? (settings.solid ? settings.hiSel : Qt.rgba(1, 1, 1, 0.65)) : "transparent"
                    border.width: 1
                    border.color: on ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.25)
                    Text { id: lbl; anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 12; color: on ? root.pri : root.muted }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.homeTop = parent.modelData.k }
                }
            }
        }
        ListView {
            visible: root.artists.length > 0
            width: parent.width
            height: root.tile + 52
            orientation: ListView.Horizontal
            spacing: 16
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.artists
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: root.tile
                height: ListView.view.height
                Column {
                    width: parent.width
                    spacing: 8
                    Item {
                        width: root.tile; height: root.tile
                        ArtistPhoto { anchors.fill: parent; name: cell.modelData.name }
                        Rectangle {
                            width: Math.max(28, rank.implicitWidth + 12); height: 28
                            color: Qt.rgba(0, 0, 0, 0.72)
                            Text { id: rank; anchors.centerIn: parent; text: cell.index + 1; font.pixelSize: 13; font.weight: Font.DemiBold; color: "white" }
                        }
                    }
                    Column {
                        width: parent.width
                        Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.pri }
                        Text { width: parent.width; text: cell.modelData.plays + (cell.modelData.plays === 1 ? " play" : " plays"); font.pixelSize: 11; color: root.muted }
                    }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openArtist(cell.modelData.name) }
            }
        }
        Text {
            visible: root.artists.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 12
            color: root.muted
            text: stats.total === 0
                ? "Play some music and the artists you listen to most will show up here. This is counted on this device and never uploaded."
                : "Nothing played in the last 4 weeks. Try “All time”."
        }
    }
}
