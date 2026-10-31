import QtQuick

Rectangle {
    id: root
    property string name
    property real box: 36
    property real iconSize: 20
    property color fg: settings.primary
    property color bg: "transparent"
    property bool outlined: false
    signal clicked()

    width: box
    height: box
    color: bg
    border.width: outlined ? 1 : 0
    border.color: Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.2)

    Rectangle {
        anchors.fill: parent
        color: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.35)
        visible: ma.containsMouse
    }
    Icon {
        anchors.centerIn: parent
        name: root.name
        size: root.iconSize
        color: root.fg
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
