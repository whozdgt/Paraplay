import QtQuick

Item {
    id: root
    property string line1
    property string line2
    readonly property color pri: settings.primary
    width: 104
    height: col.implicitHeight + 4

    Rectangle { width: 3; height: parent.height; color: settings.accent }
    Column {
        id: col
        x: 11
        anchors.verticalCenter: parent.verticalCenter
        Text { text: root.line1; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.pri }
        Text { text: root.line2; font.pixelSize: 10; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72) }
    }
}
