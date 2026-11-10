import QtQuick

Rectangle {
    id: root
    property string name
    property real box: 36
    property real iconSize: 20
    property color fg: settings.ink
    property color bg: "transparent"
    property bool outlined: false
    property bool filled: false         // Midnight: a grey circle behind the icon, like the buttons beside a page title
    signal clicked()

    width: box
    height: box
    radius: settings.round ? width / 2 : 0
    color: root.bg.a > 0 ? root.bg : (root.filled && settings.round ? settings.roundButton : "transparent")
    border.width: outlined ? 1 : 0
    border.color: Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.2)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.35)
        opacity: ma.containsMouse ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Rectangle {      // a little darker while pressed
        anchors.fill: parent
        radius: root.radius
        color: settings.ink
        opacity: ma.pressed ? 0.10 : 0
        Behavior on opacity { NumberAnimation { duration: 80 } }
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
