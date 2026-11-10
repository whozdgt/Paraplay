import QtQuick

// The "Search settings" box. What is typed lives in settings.settingsQuery, which every row in Settings reads.
Rectangle {
    id: root
    readonly property color pri: settings.ink

    implicitHeight: settings.mobile ? 48 : 40
    color: settings.round ? settings.field : settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)
    radius: settings.round ? height / 2 : 0
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? settings.accent : Qt.rgba(pri.r, pri.g, pri.b, 0.3)

    Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: root.pri }
    Text {
        visible: input.text.length === 0
        anchors { left: parent.left; leftMargin: 38; verticalCenter: parent.verticalCenter }
        text: "Search settings"
        font.pixelSize: 14
        color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.6)
    }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 38; rightMargin: 40 }
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: 14
        color: root.pri
        clip: true
        selectByMouse: true
        text: settings.settingsQuery
        onTextEdited: settings.settingsQuery = text
        Accessible.name: "Search settings"
    }
    Item {          // clears the search
        visible: input.text.length > 0
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: root.height
        Icon { anchors.centerIn: parent; name: "close"; size: 16; color: root.pri }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { settings.settingsQuery = ""; input.forceActiveFocus() } }
        Accessible.role: Accessible.Button
        Accessible.name: "Clear search"
    }
}
