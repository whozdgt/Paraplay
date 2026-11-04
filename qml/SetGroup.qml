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
        font.pixelSize: 11
        font.letterSpacing: 1
        color: Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.72)
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 0
        readonly property bool isSetBody: true          // tells the rows inside that they are in a group
        readonly property bool groupHit: root.groupHit
    }
}
