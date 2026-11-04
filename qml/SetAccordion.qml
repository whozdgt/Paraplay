import QtQuick
import QtQuick.Layouts

// A row that opens to show more underneath. The content eases open and closed.
SettingItem {
    id: root
    property bool open: false
    property color chip: "transparent"          // a small square of colour beside the arrow
    default property alias content: body.data
    readonly property color pri: settings.primary
    readonly property real headH: inGroup ? (touch ? 64 : 56) : (touch ? 56 : 48)
    readonly property real bleed: inGroup ? 12 : 0

    activeFocusOnTab: true
    implicitHeight: headH + wrap.height
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: root.open = !root.open
    Keys.onSpacePressed: (e) => { root.open = !root.open; e.accepted = true }
    Keys.onReturnPressed: (e) => { root.open = !root.open; e.accepted = true }

    Rectangle {
        x: -root.bleed; width: root.width + 2 * root.bleed; height: root.headH
        color: root.pri
        opacity: ma.pressed ? 0.10 : (ma.containsMouse ? 0.06 : 0)
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }
    Rectangle { visible: root.visualFocus; width: parent.width; height: root.headH; color: "transparent"; border.width: 2; border.color: settings.accent }
    MouseArea {
        id: ma
        width: parent.width; height: root.headH
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.open = !root.open }
    }
    RowLayout {
        width: parent.width; height: root.headH
        spacing: 12
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text { Layout.fillWidth: true; text: root.label; elide: Text.ElideRight; font.pixelSize: 14; color: root.pri }
            Text {
                visible: root.note !== ""
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.note
                font.pixelSize: 12
                lineHeight: 1.25
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
            }
        }
        Rectangle {
            visible: root.chip.a > 0
            Layout.preferredWidth: 18; Layout.preferredHeight: 18
            color: root.chip
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.25)
        }
        Icon {
            name: "chevron"; size: 16; color: root.pri
            rotation: root.open ? 90 : 0
            Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }
    Item {
        id: wrap
        y: root.headH
        width: parent.width
        height: root.open ? body.implicitHeight : 0
        clip: height !== body.implicitHeight
        visible: height > 0
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] } }
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 0
        }
    }
    Rectangle { visible: root.inGroup; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: root.pri; opacity: 0.08 }
}
