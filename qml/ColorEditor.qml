import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string title
    property color value
    signal edited(color c)
    readonly property color pri: settings.primary
    Layout.fillWidth: true
    spacing: 2

    function channel(i, v) {
        const c = [Math.round(value.r * 255), Math.round(value.g * 255), Math.round(value.b * 255)]
        c[i] = v
        edited(Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1))
    }

    RowLayout {
        Layout.topMargin: 6
        spacing: 10
        Rectangle { width: 18; height: 18; color: root.value; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25) }
        Text { text: root.title; font.pixelSize: 13; color: root.pri }
    }
    Repeater {
        model: ["R", "G", "B"]
        RowLayout {
            required property int index
            required property string modelData
            Layout.fillWidth: true
            spacing: 10
            Text { Layout.preferredWidth: 10; text: parent.modelData; font.pixelSize: 12; color: root.pri }
            Slider255 {
                Layout.fillWidth: true
                value: Math.round([root.value.r, root.value.g, root.value.b][parent.index] * 255)
                onMoved: (v) => root.channel(parent.index, v)
            }
            Text {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
                text: Math.round([root.value.r, root.value.g, root.value.b][parent.index] * 255)
                font.pixelSize: 12
                color: root.pri
            }
        }
    }
}
