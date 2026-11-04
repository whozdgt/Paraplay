import QtQuick
import QtQuick.Layouts

// A row that can hold anything: a text box, a list of servers, a few buttons.
SettingItem {
    id: root
    default property alias content: body.data
    property real vpad: 8

    implicitHeight: body.implicitHeight + 2 * vpad

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: root.vpad }
        spacing: 6
    }
}
