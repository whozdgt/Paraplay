import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property string label
    property string note
    property bool checked
    signal toggled()
    readonly property color pri: settings.primary
    Layout.fillWidth: true
    Layout.preferredHeight: Math.max(44, textCol.implicitHeight + 10)

    ColumnLayout {
        id: textCol
        Layout.fillWidth: true
        spacing: 0
        Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; font.pixelSize: 14; color: root.pri }
        Text {
            visible: root.note !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap          // a long note must wrap, or it pushes the switch off a narrow screen
            text: root.note
            font.pixelSize: 10
            color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
        }
    }
    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 40
        Layout.preferredHeight: 22
        color: root.checked ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.25)
        Rectangle {
            width: 16; height: 16; y: 3
            x: root.checked ? 21 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 150 } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
    }
}
