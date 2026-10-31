import QtQuick

Item {
    id: root
    property bool creating: false
    signal closeRequested()
    readonly property color pri: settings.primary
    readonly property bool themed: settings.solid                 // phones, or frosted glass switched off: use the chosen colours
    readonly property color hint: themed ? Qt.rgba(pri.r, pri.g, pri.b, 0.5) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color fieldFill: themed ? settings.boxFill : Qt.rgba(1, 1, 1, 0.85)
    readonly property color fieldLine: themed ? settings.boxLine : Qt.rgba(0, 0, 0, 0.2)
    function submit() {
        if (creating) account.signUp(userIn.text, passIn.text)
        else account.signIn(userIn.text, passIn.text)
    }
    onVisibleChanged: if (visible) { userIn.text = ""; passIn.text = ""; userIn.forceActiveFocus() }
    Connections { target: account; function onChanged() { if (account.signedIn) root.closeRequested() } }

    Rectangle { anchors.fill: parent; color: root.themed ? Qt.rgba(0, 0, 0, 0.5) : Qt.rgba(1, 1, 1, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(420, root.width - 24)
        height: col.implicitHeight + 56
        color: root.themed ? settings.bgColor : Qt.rgba(1, 1, 1, 0.93)
        border.width: root.themed ? 1 : 0
        border.color: settings.boxLine
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            x: 20; y: 28
            width: parent.width - 40
            spacing: 12
            Row {
                width: parent.width
                Repeater {
                    model: [{ t: "Sign in", c: false }, { t: "Create account", c: true }]
                    Rectangle {
                        required property var modelData
                        width: parent.width / 2; height: 40; color: "transparent"
                        Text { anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 14; font.weight: root.creating === parent.modelData.c ? Font.DemiBold : Font.Normal; color: root.pri }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: root.creating === parent.modelData.c ? 3 : 1
                            color: root.creating === parent.modelData.c ? settings.accent : (root.themed ? settings.boxLine : Qt.rgba(0, 0, 0, 0.15))
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.creating = parent.modelData.c }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 44; color: root.fieldFill; border.width: 1; border.color: root.fieldLine
                Text { visible: userIn.text.length === 0; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Username"; font.pixelSize: 14; color: root.hint }
                TextInput {
                    id: userIn
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter; font.pixelSize: 14; color: root.pri; clip: true; maximumLength: 20
                    onAccepted: passIn.forceActiveFocus()
                }
            }
            Rectangle {
                width: parent.width; height: 44; color: root.fieldFill; border.width: 1; border.color: root.fieldLine
                Text { visible: passIn.text.length === 0; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Password"; font.pixelSize: 14; color: root.hint }
                TextInput {
                    id: passIn
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    verticalAlignment: TextInput.AlignVCenter; font.pixelSize: 14; color: root.pri; clip: true
                    echoMode: TextInput.Password
                    onAccepted: root.submit()
                }
            }
            Text {
                visible: text !== ""
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 12; color: root.pri
                text: account.signedIn ? "" : account.message
            }
            Btn { width: parent.width; label: root.creating ? "Create account" : "Sign in"; enabled: !account.busy; onClicked: root.submit() }
            Btn { width: parent.width; primary: false; label: "Continue without an account"; onClicked: root.closeRequested() }
            Text {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11; lineHeight: 1.4
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                text: "Your music files never leave this computer.\nThere is no password reset, so keep your password safe."
            }
        }
    }
}
