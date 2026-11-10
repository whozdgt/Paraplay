import QtQuick

// One section in the list down the left of Settings.
Rectangle {
    id: root
    property string text
    property string icon
    property bool active: false
    signal clicked()
    readonly property color pri: settings.ink

    height: 44
    Accessible.role: Accessible.PageTab
    Accessible.name: text
    Accessible.selected: active
    Accessible.onPressAction: root.clicked()
    color: active ? (settings.solid ? settings.hiSel : Qt.rgba(1, 1, 1, 0.65))
                  : Qt.rgba(pri.r, pri.g, pri.b, ma.pressed ? 0.10 : (ma.containsMouse ? 0.06 : 0))
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle { visible: root.active; width: 3; height: parent.height; color: settings.accent }
    Row {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; name: root.icon; size: 18; color: root.pri }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: 14
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, root.active ? 1 : 0.78)
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
