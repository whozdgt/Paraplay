import QtQuick
import QtQuick.Layouts

// A titled run of rows. While searching, the title reads "Section › Group", and the whole group goes away when none of its rows match.
ColumnLayout {
    id: root
    property string title
    property string section
    property bool first: false                 // the first group on a page has no space above it
    default property alias content: body.data
    readonly property string query: String(settings.settingsQuery).trim().toLowerCase()
    readonly property bool searching: query !== ""
    readonly property bool groupHit: searching && matchesTitle()
    readonly property int hits: countHits()

    Layout.fillWidth: true
    Layout.topMargin: first ? 0 : 24
    spacing: 0
    visible: !searching || hits > 0

    function matchesTitle() {
        const hay = (title + " " + section).toLowerCase()
        for (const w of query.split(" "))
            if (w !== "" && hay.indexOf(w) < 0) return false
        return true
    }
    function countHits() {
        let n = 0
        for (let i = 0; i < body.children.length; ++i)
            if (body.children[i].shown === true) n++
        return n
    }

    Text {
        visible: root.title !== ""
        Layout.fillWidth: true
        Layout.bottomMargin: 6
        elide: Text.ElideRight
        text: (root.searching && root.section !== "" ? root.section + " › " : "") + root.title.toUpperCase()
        leftPadding: settings.round ? 16 : 0
        font.pixelSize: settings.round ? 12 : 11
        font.weight: settings.round ? Font.Bold : Font.Normal
        font.letterSpacing: 1
        color: settings.round ? settings.inkSoft : Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.72)
    }
    Item {      // Midnight: the rows sit on a softly tinted card
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + (settings.round ? 8 : 0)
        Rectangle { anchors.fill: parent; visible: settings.round; radius: 18; color: settings.cardFill }
        ColumnLayout {
            id: body
            x: settings.round ? 16 : 0
            y: settings.round ? 4 : 0
            width: parent.width - 2 * x
            spacing: 0
            readonly property bool isSetBody: true          // tells the rows inside that they are in a group
            readonly property bool groupHit: root.groupHit
        }
    }
}
