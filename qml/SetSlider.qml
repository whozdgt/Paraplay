import QtQuick

// A slider with a filled track, a knob that grows when held, and a small bubble with the value while you drag.
Item {
    id: root
    property int value: 0
    property int minValue: 0
    property int maxValue: 255
    property int step: 1
    property color fill: settings.accent
    property string valueText                     // what the bubble says; the number itself when empty
    readonly property bool pressed: ma.pressed
    signal moved(int v)                           // while dragging
    signal committed(int v)                       // when let go
    readonly property color pri: settings.ink
    readonly property real knob: settings.mobile ? 22 : 18
    readonly property real frac: maxValue > minValue ? Math.max(0, Math.min(1, (value - minValue) / (maxValue - minValue))) : 0

    implicitHeight: settings.mobile ? 44 : 36

    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4
        radius: settings.round ? 2 : 0
        color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.2)
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: handle.x + handle.width / 2
        height: 4
        radius: settings.round ? 2 : 0
        color: root.fill
    }
    Rectangle {
        id: handle
        x: root.frac * (root.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: root.knob; height: root.knob
        radius: settings.round ? width / 2 : 0
        color: "white"
        border.width: 2
        border.color: root.pri
        scale: ma.pressed ? 1.2 : (ma.containsMouse ? 1.1 : 1)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        id: bubble
        opacity: ma.pressed ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
        x: Math.max(0, Math.min(root.width - width, handle.x + handle.width / 2 - width / 2))
        y: -height - 2
        width: bubbleText.implicitWidth + 16
        height: 24
        radius: settings.round ? 12 : 0
        color: root.pri
        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: root.valueText !== "" ? root.valueText : String(root.value)
            font.pixelSize: 12
            color: settings.solid ? settings.ground : "white"
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true                      // dragging sideways must not scroll the page
        cursorShape: Qt.PointingHandCursor
        function pick(mx) {
            const f = Math.max(0, Math.min(1, (mx - root.knob / 2) / Math.max(1, root.width - root.knob)))
            const v = root.minValue + Math.round(f * (root.maxValue - root.minValue) / root.step) * root.step
            return Math.max(root.minValue, Math.min(root.maxValue, v))
        }
        onPressed: (m) => root.moved(pick(m.x))
        onPositionChanged: (m) => { if (pressed) root.moved(pick(m.x)) }
        onReleased: (m) => root.committed(pick(m.x))
    }
}
