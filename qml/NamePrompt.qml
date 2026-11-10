import QtQuick

Item {
    id: root
    property string title: "New playlist"
    signal accepted(string name)
    signal cancelled()
    onVisibleChanged: if (visible) { input.text = ""; input.forceActiveFocus() }

    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(380, root.width - 24)
        height: 170
        color: settings.surface; radius: settings.round ? 18 : 0
        MouseArea { anchors.fill: parent }
        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 14
            Text { text: root.title; font.pixelSize: 18; font.weight: Font.DemiBold; color: settings.ink }
            Rectangle {
                width: parent.width; height: 40
                color: settings.field; radius: settings.round ? 10 : 0; border.width: 1
                border.color: Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.3)
                TextInput {
                    id: input
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 14; color: settings.ink; clip: true
                    onAccepted: root.accepted(text)
                    Keys.onEscapePressed: root.cancelled()
                }
            }
            Row {
                spacing: 10
                Rectangle {
                    width: 120; height: 40; color: settings.ink
                    Text { anchors.centerIn: parent; text: "Create"; color: settings.onInk; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.accepted(input.text) }
                }
                Rectangle {
                    width: 120; height: 40; color: "transparent"; border.width: 1; border.color: settings.ink
                    Text { anchors.centerIn: parent; text: "Cancel"; color: settings.ink; font.pixelSize: 14 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.cancelled() }
                }
            }
        }
    }
}
