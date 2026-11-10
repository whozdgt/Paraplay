import QtQuick

// A square of colour you can pick.
Item {
    id: root
    property color swatch
    property string name
    property bool selected: false
    signal picked()

    width: settings.mobile ? 48 : 40
    height: width
    Accessible.role: Accessible.RadioButton
    Accessible.name: name
    Accessible.checked: selected
    Accessible.onPressAction: root.picked()

    Rectangle {
        id: face
        anchors.centerIn: parent
        width: settings.mobile ? 40 : 32
        height: width
        color: root.swatch
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
        scale: ma.pressed ? 0.96 : (ma.containsMouse ? 1.08 : 1)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }
    Rectangle {      // the ring around the chosen one
        visible: root.selected
        anchors.centerIn: parent
        width: face.width + 8; height: width
        color: "transparent"
        border.width: 2
        border.color: settings.ink
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked() }
}
