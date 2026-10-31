import QtQuick

// "Add a server": stream from your own Navidrome / Subsonic or Jellyfin server.
Item {
    id: root
    property string kind: "subsonic"            // subsonic | jellyfin
    property bool resultOk: false
    property string resultText: ""
    signal closeRequested()
    readonly property color pri: settings.primary
    readonly property bool jelly: kind === "jellyfin"

    function reset() {
        nameIn.clear(); urlIn.clear(); userIn.clear(); passIn.clear()
        selfSigned = false
        resultText = ""
        resultOk = false
    }
    property bool selfSigned: false
    function go(addIt) {
        resultText = ""
        servers.connectServer(kind, nameIn.text, urlIn.text, userIn.text, passIn.text, selfSigned, addIt)
    }
    onVisibleChanged: if (visible) { reset(); urlIn.focusInput() }
    Connections {
        target: servers
        function onConnectResult(ok, text, added) {
            if (!root.visible) return
            root.resultOk = ok
            root.resultText = text
            if (ok && added) root.closeRequested()
        }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: root.closeRequested() }
    Rectangle {
        anchors.centerIn: parent
        width: 460
        height: col.implicitHeight + 56
        color: Qt.rgba(1, 1, 1, 0.93)
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            x: 20; y: 28
            width: parent.width - 40
            spacing: 12
            Text { text: "Add a server"; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri }
            Row {
                width: parent.width
                Repeater {
                    model: [{ t: "Navidrome / Subsonic", k: "subsonic" }, { t: "Jellyfin", k: "jellyfin" }]
                    Rectangle {
                        required property var modelData
                        readonly property bool sel: root.kind === modelData.k
                        width: parent.width / 2; height: 40; color: "transparent"
                        Text { anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 14; font.weight: parent.sel ? Font.DemiBold : Font.Normal; color: root.pri }
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: parent.sel ? 3 : 1
                            color: parent.sel ? settings.accent : Qt.rgba(0, 0, 0, 0.15)
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.kind = parent.modelData.k }
                    }
                }
            }
            Field { id: urlIn; width: parent.width; nextField: userIn; placeholder: root.jelly ? "Address, e.g. https://jellyfin.example.com" : "Address, e.g. http://192.168.1.20:4533"; onAccepted: userIn.focusInput() }
            Field { id: userIn; width: parent.width; nextField: passIn; placeholder: "Username"; onAccepted: passIn.focusInput() }
            Field { id: passIn; width: parent.width; nextField: nameIn; placeholder: "Password"; secret: true; onAccepted: root.go(true) }
            Field { id: nameIn; width: parent.width; nextField: urlIn; placeholder: "Name (optional), e.g. Home server"; onAccepted: root.go(true) }
            ToggleRow {
                width: parent.width
                label: "Allow a self-signed certificate"
                note: "For a server on your own network that has no public certificate"
                checked: root.selfSigned
                onToggled: root.selfSigned = !root.selfSigned
            }
            Text {
                visible: root.resultText !== ""
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 12
                color: root.resultOk ? settings.accent : "#b91c1c"
                text: root.resultText
            }
            Text {
                visible: servers.testing
                width: parent.width; font.pixelSize: 12; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                text: "Connecting…"
            }
            Row {
                spacing: 8
                Btn { label: "Add server"; enabled: !servers.testing; onClicked: root.go(true) }
                Btn { label: "Test connection"; primary: false; enabled: !servers.testing; onClicked: root.go(false) }
                Btn { label: "Cancel"; primary: false; onClicked: root.closeRequested() }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 11; lineHeight: 1.4
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
                text: "Songs play as the original files, never re-encoded.\nSign-in details are kept in a private file on this computer."
            }
        }
    }
}
