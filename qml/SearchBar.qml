import QtQuick

Item {
    id: root
    property string kind: "album"
    property bool suggestions: true
    property bool picked: false
    readonly property var items: (!suggestions || picked || input.text.length === 0) ? []
        : (kind === "playlist" ? playlists.suggest(input.text, 5) : library.suggest(kind, input.text, 5))
    signal typed(string q)
    signal chosen(var item)
    signal closed()
    width: 440
    height: 44 + (items.length > 0 ? items.length * 40 + 4 : 0)
    // On a solid theme (phones) the box must hide whatever is behind it, and be a shade that the chosen text colour can be read on.
    readonly property color fill: settings.solid ? Qt.tint(settings.ground, settings.hiSel) : Qt.rgba(1, 1, 1, 0.88)
    readonly property color rowFill: settings.solid ? fill : Qt.rgba(1, 1, 1, 0.86)
    readonly property color rowHover: settings.solid ? Qt.tint(fill, settings.hiSel) : Qt.rgba(1, 1, 1, 0.97)
    readonly property color muted: Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.6)

    function open() { picked = false; input.text = ""; input.forceActiveFocus() }
    function choose(item) { picked = true; input.text = item.name; root.chosen(item) }

    Rectangle {
        width: parent.width
        height: 44
        color: root.fill
        radius: settings.round ? height / 2 : 0
        border.width: 1
        border.color: settings.solid ? settings.boxLine : Qt.rgba(1, 1, 1, 0.8)
        Icon { x: 14; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: settings.ink }
        Text {
            visible: input.text.length === 0
            anchors { left: parent.left; leftMargin: 44; verticalCenter: parent.verticalCenter }
            text: "Search…"; font.pixelSize: 14; color: root.muted
        }
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 44; rightMargin: 14 }
            verticalAlignment: TextInput.AlignVCenter
            font.pixelSize: 14
            color: settings.ink
            clip: true
            selectByMouse: true
            onTextChanged: root.typed(text)
            onTextEdited: root.picked = false
            onAccepted: { if (root.items.length > 0) root.choose(root.items[0]) }
            Keys.onEscapePressed: root.closed()
        }
    }
    Column {
        y: 48
        width: parent.width
        Repeater {
            model: root.items
            Rectangle {
                required property var modelData
                width: parent.width
                height: 40
                color: ma.containsMouse ? root.rowHover : root.rowFill
                Text {
                    anchors { left: parent.left; leftMargin: 14; right: subText.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    text: parent.modelData.name; elide: Text.ElideRight; font.pixelSize: 14; color: settings.ink
                }
                Text {
                    id: subText
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    width: Math.min(implicitWidth, 130); elide: Text.ElideRight
                    text: parent.modelData.sub; font.pixelSize: 12; color: root.muted
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.choose(parent.modelData) }
            }
        }
    }
}
