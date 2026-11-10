import QtQuick

Rectangle {
    id: root
    property string label
    property bool primary: true
    property bool large: false           // a taller button (44, or 48 on a phone), as in Settings
    signal clicked()
    implicitWidth: lbl.implicitWidth + 36
    implicitHeight: large ? (settings.mobile ? 48 : 44) : 40
    radius: settings.round ? height / 2 : 0           // Midnight: a pill
    color: primary ? settings.ink : (settings.round ? settings.roundButton : "transparent")
    border.width: primary || settings.round ? 0 : 1
    border.color: settings.ink
    opacity: enabled ? 1 : 0.5
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: root.clicked()

    Rectangle {      // a little lighter or darker while the pointer is over it, and more while it is pressed
        anchors.fill: parent
        radius: root.radius
        color: root.primary ? "white" : settings.ink
        opacity: ma.pressed ? 0.22 : (ma.containsMouse ? 0.10 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Text { id: lbl; anchors.centerIn: parent; text: root.label; font.pixelSize: 14; font.weight: settings.round ? Font.DemiBold : Font.Normal; color: root.primary ? settings.onInk : settings.ink }
    MouseArea { id: ma; anchors.fill: parent; enabled: root.enabled; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
