import QtQuick

Item {
    id: root
    property string line1
    property string line2
    readonly property color pri: settings.ink
    width: 104
    height: col.implicitHeight + (settings.round ? 10 : 4)

    Rectangle {      // Classic: a stripe of accent; Midnight: a soft pill
        width: settings.round ? parent.width : 3
        height: parent.height
        radius: settings.round ? 12 : 0
        color: settings.round ? settings.chipFill : settings.accent
    }
    Column {
        id: col
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        Text { text: root.line1; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.pri }
        Text { text: root.line2; font.pixelSize: 10; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72) }
    }
}
