import QtQuick
import QtQuick.Layouts

// A setting that is on or off. The whole row is the button; the switch only shows the state.
SettingItem {
    id: root
    property bool checked
    signal toggled()
    default property alias accessories: acc.data         // small buttons shown beside the switch
    readonly property color pri: settings.ink
    readonly property real bleed: inGroup ? 12 : 0       // the hover tint reaches a little past the row

    implicitHeight: Math.max(inGroup ? (touch ? 60 : 52) : 44, textCol.implicitHeight + 16)
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    Accessible.onPressAction: root.toggled()

    Rectangle {
        x: -root.bleed; width: root.width + 2 * root.bleed; height: root.height
        color: root.pri
        opacity: ma.pressed ? 0.10 : (ma.containsMouse ? 0.06 : 0)
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
    Rectangle { visible: root.inGroup; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.pri; opacity: 0.08 }

    // under the row's own buttons, so they still get their clicks
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    RowLayout {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 12
        ColumnLayout {
            id: textCol
            Layout.fillWidth: true
            spacing: 0
            Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; font.pixelSize: 14; color: root.pri }
            Text {
                visible: root.note !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap             // a long note must wrap, or it pushes the switch off a narrow screen
                text: root.note
                font.pixelSize: root.inGroup ? 12 : 11
                lineHeight: 1.25
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
            }
        }
        Row { id: acc; visible: children.length > 0; Layout.alignment: Qt.AlignVCenter; spacing: 0 }
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 24
            color: root.checked ? settings.accent : "transparent"
            border.width: 2
            border.color: root.checked ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.5)
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Rectangle {
                y: 4; width: 16; height: 16
                x: root.checked ? 24 : 4
                color: root.checked ? "white" : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.5)
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
