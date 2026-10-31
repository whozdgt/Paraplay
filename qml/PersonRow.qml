import QtQuick

// One person in a list: picture, name, a line under it, and whatever buttons the page puts on the right.
Rectangle {
    id: root
    property var person: ({})
    property string sub
    property bool small: false
    default property alias actions: acts.data
    signal opened()
    readonly property color pri: settings.primary

    height: small ? 52 : 62
    color: ma.containsMouse ? (settings.dark ? Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.55)) : (settings.dark ? Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.07) : Qt.rgba(1, 1, 1, 0.35))

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened() }
    Avatar {
        id: av
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.small ? 32 : 40
        height: width
        source: root.person.avatar || ""
    }
    Column {
        anchors { left: av.right; leftMargin: 12; right: acts.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
        Text {
            width: parent.width
            text: root.person.name || ""
            elide: Text.ElideRight
            font.pixelSize: 14; font.weight: Font.DemiBold; color: root.pri
        }
        Text {
            width: parent.width
            visible: root.sub !== ""
            text: root.sub
            elide: Text.ElideRight
            font.pixelSize: 11; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
        }
    }
    Row {
        id: acts
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
}
