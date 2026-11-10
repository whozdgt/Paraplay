import QtQuick
import QtQuick.Layouts

// A name with a value beside it that you only read.
SettingItem {
    id: root
    property string value
    readonly property color pri: settings.ink

    implicitHeight: inGroup ? (touch ? 60 : 52) : 44

    Rectangle { visible: root.inGroup; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.pri; opacity: 0.08 }
    RowLayout {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 12
        Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; font.pixelSize: 14; color: root.pri }
        Text { text: root.value; font.pixelSize: 13; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72) }
    }
}
