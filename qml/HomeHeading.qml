import QtQuick

// The small heading above a Home section. On the right: a "See all" link, an expand arrow, or whatever you put inside.
Item {
    id: root
    property string text
    property int count: 0                 // a small number badge beside the heading
    property string link                  // for example "See all"
    property bool arrow: false
    property bool arrowOpen: false
    default property alias extra: right.data
    signal activated()
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    height: 44

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            font.pixelSize: 11
            font.letterSpacing: 1
            color: root.muted
        }
        Rectangle {
            visible: root.count > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(18, cnt.implicitWidth + 10); height: 18
            color: settings.accent
            Text { id: cnt; anchors.centerIn: parent; text: root.count; font.pixelSize: 11; color: settings.onInk }
        }
    }
    Row {
        id: right
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8
        Item {
            visible: root.link !== ""
            width: linkText.implicitWidth + 24; height: 44
            Text { id: linkText; anchors.centerIn: parent; text: root.link; font.pixelSize: 12; color: root.pri }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activated() }
        }
        Item {
            visible: root.arrow
            width: 44; height: 44
            Icon { anchors.centerIn: parent; name: root.arrowOpen ? "up" : "down"; size: 22; color: root.pri }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activated() }
        }
    }
}
