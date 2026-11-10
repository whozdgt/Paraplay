import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    spacing: 10
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    property real dragFrac: -1
    readonly property real frac: dragFrac >= 0 ? dragFrac
        : (player.duration > 0 ? Math.min(1, player.position / player.duration) : 0)
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2)
    }

    Text { text: root.fmt(root.frac * player.duration); font.pixelSize: 12; color: root.muted }
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 20
        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 4
            color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.18)
            Rectangle { width: parent.width * root.frac; height: parent.height; color: settings.accent }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (m) => root.dragFrac = Math.max(0, Math.min(1, m.x / width))
            onPositionChanged: (m) => { if (pressed) root.dragFrac = Math.max(0, Math.min(1, m.x / width)) }
            onReleased: {
                if (root.dragFrac >= 0) player.seek(root.dragFrac * player.duration)
                root.dragFrac = -1
            }
        }
    }
    Text { text: root.fmt(player.duration); font.pixelSize: 12; color: root.muted }
}
