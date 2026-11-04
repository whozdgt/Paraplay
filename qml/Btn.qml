import QtQuick

Rectangle {
    id: root
    property string label
    property bool primary: true
    property bool large: false           // a taller button (44, or 48 on a phone), as in Settings
    signal clicked()
    implicitWidth: lbl.implicitWidth + 36
    implicitHeight: large ? (Qt.platform.os === "android" ? 48 : 44) : 40
    color: primary ? settings.primary : "transparent"
    border.width: primary ? 0 : 1
    border.color: settings.primary
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: root.clicked()

    Rectangle {      // a little lighter or darker while the pointer is over it, and more while it is pressed
        anchors.fill: parent
        color: root.primary ? "white" : settings.primary
        opacity: ma.pressed ? 0.22 : (ma.containsMouse ? 0.10 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Text { id: lbl; anchors.centerIn: parent; text: root.label; font.pixelSize: 14; color: root.primary ? "white" : settings.primary }
    Rectangle { visible: root.visualFocus; anchors.fill: parent; anchors.margins: -3; color: "transparent"; border.width: 2; border.color: settings.accent }
    MouseArea { id: ma; anchors.fill: parent; enabled: root.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
