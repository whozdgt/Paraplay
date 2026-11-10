import QtQuick
import QtQuick.Layouts

// A named setting that is a number on a slider.
SettingItem {
    id: root
    property int value
    property int minValue: 0
    property int maxValue: 100
    property int step: 1
    property string valueText
    property color fill: settings.accent
    readonly property bool pressed: slider.pressed
    signal moved(int v)
    signal committed(int v)
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    implicitHeight: col.implicitHeight + 20

    Rectangle { visible: root.inGroup; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.pri; opacity: 0.08 }
    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; font.pixelSize: 14; color: root.pri }
            Text { text: root.valueText !== "" ? root.valueText : String(root.value); font.pixelSize: 13; color: root.muted }
        }
        Text {
            visible: root.note !== ""
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: root.note
            font.pixelSize: 12
            lineHeight: 1.25
            color: root.muted
        }
        SetSlider {
            id: slider
            Layout.fillWidth: true
            Layout.topMargin: 6
            value: root.value
            minValue: root.minValue
            maxValue: root.maxValue
            step: root.step
            fill: root.fill
            valueText: root.valueText
            onMoved: (v) => root.moved(v)
            onCommitted: (v) => root.committed(v)
        }
    }
}
