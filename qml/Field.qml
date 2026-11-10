import QtQuick

// A one-line text box with a hint that fades once you type.
Rectangle {
    id: root
    property string placeholder
    property bool secret: false
    property alias text: input.text
    property Item nextField: null          // Tab jumps here
    signal accepted()
    function focusInput() { input.forceActiveFocus() }
    function clear() { input.text = "" }

    readonly property color pri: settings.ink
    implicitWidth: 200
    implicitHeight: 44
    color: settings.round ? settings.field : Qt.rgba(1, 1, 1, 0.85); radius: settings.round ? 10 : 0
    border.width: 1
    border.color: input.activeFocus ? Qt.rgba(pri.r, pri.g, pri.b, 0.6) : Qt.rgba(0, 0, 0, 0.2)

    Text {
        visible: input.text.length === 0
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.placeholder
        font.pixelSize: 14
        color: Qt.rgba(0, 0, 0, 0.5)
    }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: 14
        color: root.pri
        clip: true
        selectByMouse: true
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        onAccepted: root.accepted()
        Keys.onTabPressed: (e) => { if (root.nextField) root.nextField.focusInput(); e.accepted = true }
    }
}
