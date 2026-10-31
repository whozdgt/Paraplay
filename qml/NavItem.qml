import QtQuick

Rectangle {
    id: root
    property string text
    property bool active: false
    property bool sub: false
    property bool chevron: false
    property bool open: true
    property bool dim: false
    signal clicked()
    readonly property color pri: settings.primary

    height: sub ? 36 : 40
    color: active ? (settings.dark ? Qt.rgba(settings.accent.r, settings.accent.g, settings.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.65)) : (ma.containsMouse && !dim ? (settings.dark ? Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.08) : Qt.rgba(1, 1, 1, 0.3)) : "transparent")

    Rectangle { visible: root.active; width: 3; height: parent.height; color: settings.accent }
    Text {
        anchors { left: parent.left; leftMargin: root.sub ? 28 : 12; right: parent.right; rightMargin: 36; verticalCenter: parent.verticalCenter }
        text: root.text
        elide: Text.ElideRight
        font.pixelSize: root.sub ? 13 : 14
        color: root.active ? root.pri : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, root.dim ? 0.5 : 0.78)
    }
    Icon {
        visible: root.chevron
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        name: root.open ? "up" : "down"
        size: 16
        color: root.pri
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: !root.dim
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
