import QtQuick

// Two columns side by side when there is room, one under the other when there is not. Scrolls.
Flickable {
    id: root
    property real leftWidth: 520
    default property alias leftItems: leftCol.data
    property alias rightItems: rightCol.data
    readonly property bool wide: width >= leftWidth + 28 + 190

    contentWidth: width
    contentHeight: (wide ? Math.max(leftCol.height, rightCol.height) : leftCol.height + 16 + rightCol.height) + 24
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: leftCol
        width: root.wide ? root.leftWidth : root.width
    }
    Column {
        id: rightCol
        x: root.wide ? root.leftWidth + 28 : 0
        y: root.wide ? 0 : leftCol.height + 16
        width: root.wide ? root.width - x : root.width
    }
}
