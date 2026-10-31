import QtQuick

// One person on the Home page: picture, name, and what they are playing.
// With `request` set it shows Accept / Decline instead.
Rectangle {
    id: root
    property var person: ({})
    property bool request: false
    property bool compact: false
    signal opened()
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool live: !!root.person.live
    readonly property bool recent: !live && (root.person.title || "") !== ""

    width: compact ? 176 : 224
    height: request ? 126 : 140
    color: ma.containsMouse ? (settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.55)) : (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.35))
    border.width: 1
    border.color: settings.solid ? settings.boxLine : Qt.rgba(1, 1, 1, 0.7)

    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.opened() }

    Column {
        anchors { fill: parent; margins: 14 }
        spacing: 12
        Row {
            width: parent.width
            spacing: 12
            Avatar { id: av; width: 48; height: 48; source: root.person.avatar || "" }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - av.width - parent.spacing
                Text { width: parent.width; text: root.person.name || ""; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.pri }
                Text { width: parent.width; text: "@" + (root.person.username || ""); elide: Text.ElideRight; font.pixelSize: 11; color: root.muted }
            }
        }
        Item {      // what they are playing
            visible: !root.request
            width: parent.width
            height: 50
            Rectangle { width: 3; height: parent.height; color: root.live ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3) }
            Column {
                x: 13
                width: parent.width - 13
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    font.pixelSize: 10
                    font.letterSpacing: 1
                    color: root.muted
                    text: root.live ? "NOW PLAYING" : root.recent ? "LAST PLAYED · " + String(root.person.when).toUpperCase() : "NOT LISTENING"
                }
                Text {
                    visible: root.live || root.recent
                    width: parent.width; elide: Text.ElideRight
                    font.pixelSize: 13; font.weight: root.live ? Font.DemiBold : Font.Normal; color: root.pri
                    text: root.person.title || ""
                }
                Text {
                    visible: root.live || root.recent
                    width: parent.width; elide: Text.ElideRight
                    font.pixelSize: 12; color: root.muted
                    text: (root.person.artist || "") + (root.live && (root.person.quality || "") !== "" ? " · " + root.person.quality : "")
                }
            }
        }
        Row {       // follow requests
            visible: root.request
            width: parent.width
            spacing: 8
            Btn { width: (parent.width - parent.spacing) / 2; height: 36; label: "Accept"; primary: false; onClicked: social.respond(root.person.id, true) }
            Btn { width: (parent.width - parent.spacing) / 2; height: 36; label: "Decline"; primary: false; opacity: 0.7; onClicked: social.respond(root.person.id, false) }
        }
    }
}
