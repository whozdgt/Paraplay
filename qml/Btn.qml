import QtQuick

Rectangle {
    id: root
    property string label
    property bool primary: true
    signal clicked()
    implicitWidth: lbl.implicitWidth + 36
    implicitHeight: 40
    color: primary ? settings.primary : "transparent"
    border.width: primary ? 0 : 1
    border.color: settings.primary
    opacity: enabled ? 1 : 0.5
    Text { id: lbl; anchors.centerIn: parent; text: root.label; font.pixelSize: 14; color: root.primary ? "white" : settings.primary }
    MouseArea { anchors.fill: parent; enabled: root.enabled; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
