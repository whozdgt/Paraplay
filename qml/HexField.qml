import QtQuick

// A box for a colour written as #rrggbb. It only changes the colour once what is typed is a whole, valid code.
Rectangle {
    id: root
    property string hex
    signal picked(string hex)
    readonly property color pri: settings.primary
    readonly property bool valid: /^#[0-9a-fA-F]{6}$/.test(input.text)

    implicitWidth: 120
    implicitHeight: Qt.platform.os === "android" ? 48 : 40
    color: settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)
    border.width: input.activeFocus ? 2 : 1
    border.color: !valid ? "#b91c1c" : (input.activeFocus ? settings.accent : Qt.rgba(pri.r, pri.g, pri.b, 0.3))

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: 14
        color: root.valid ? root.pri : "#b91c1c"
        maximumLength: 7
        clip: true
        selectByMouse: true
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        text: root.hex
        onTextEdited: { if (root.valid) root.picked(text.toLowerCase()) }
    }
}
