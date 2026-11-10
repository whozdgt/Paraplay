import QtQuick

Item {
    id: root
    property int value: 0
    property int maxValue: 255
    signal moved(int v)
    height: 20
    readonly property color pri: settings.ink

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4
        color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.2)
    }
    Rectangle {
        x: (root.value / root.maxValue) * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 12
        color: "white"
        border.width: 2
        border.color: root.pri
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(mx) { root.moved(Math.round(Math.max(0, Math.min(1, (mx - 6) / (root.width - 12))) * root.maxValue)) }
        onPressed: (m) => set(m.x)
        onPositionChanged: (m) => { if (pressed) set(m.x) }
    }
}
