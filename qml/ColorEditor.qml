import QtQuick
import QtQuick.Layouts

// One colour as three sliders: red, green and blue.
ColumnLayout {
    id: root
    property string title
    property color value
    signal edited(color c)
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property var channels: [{ n: "R", c: "#dc2626" }, { n: "G", c: "#16a34a" }, { n: "B", c: "#2563eb" }]

    Layout.fillWidth: true
    spacing: 0

    function part(i) { return Math.round([value.r, value.g, value.b][i] * 255) }
    function channel(i, v) {
        const c = [part(0), part(1), part(2)]
        c[i] = v
        edited(Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1))
    }

    RowLayout {
        Layout.topMargin: 12
        Layout.fillWidth: true
        spacing: 10
        Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 18; color: root.value; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.25) }
        Text { Layout.fillWidth: true; text: root.title; font.pixelSize: 14; color: root.pri }
        Text { text: root.value.toString(); font.pixelSize: 13; color: root.muted }
    }
    Repeater {
        model: root.channels
        RowLayout {
            id: line
            required property int index
            required property var modelData
            Layout.fillWidth: true
            spacing: 10
            Text { Layout.preferredWidth: 12; text: line.modelData.n; font.pixelSize: 13; color: root.muted }
            SetSlider {
                Layout.fillWidth: true
                maxValue: 255
                value: root.part(line.index)
                fill: line.modelData.c
                onMoved: (v) => root.channel(line.index, v)
            }
            Text { Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight; text: root.part(line.index); font.pixelSize: 13; color: root.muted }
        }
    }
}
