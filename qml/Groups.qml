import QtQuick

GridView {
    id: grid
    property string kind: "album"        // album | artist
    signal picked(string key, string name)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property color pri: settings.primary
    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 190)))
    cellHeight: cellWidth + 44
    model: { library.revision; return library.groups(kind) }

    delegate: Item {
        id: cell
        required property var modelData
        width: grid.cellWidth
        height: grid.cellHeight
        Column {
            anchors { fill: parent; margins: 8 }
            spacing: 6
            Rectangle {
                width: parent.width
                height: width
                color: Qt.rgba(1, 1, 1, 0.5)
                Image {
                    anchors.fill: parent
                    source: cell.modelData.art
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 256)
                }
            }
            Text { width: parent.width; text: cell.modelData.name; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: grid.pri }
            Text { width: parent.width; text: cell.modelData.sub; elide: Text.ElideRight; font.pixelSize: 12; color: Qt.rgba(grid.pri.r, grid.pri.g, grid.pri.b, 0.72) }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: grid.picked(cell.modelData.key, cell.modelData.name) }
    }
}
