import QtQuick
import QtQuick.Layouts

// Phones: the Library tab. What you have (playlists, artists, albums, songs), where it comes from, and settings.
Flickable {
    id: root
    property int gutter: 16
    signal showView(string view)            // songs | albums | artists | playlists
    signal addServer()
    signal openSettings(string section)
    readonly property color pri: settings.ink

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 34
    boundsBehavior: Flickable.StopAtBounds

    // one line in a list: an icon, a name and, on the right, a count or a tick
    component LibRow: Rectangle {
        id: row
        property string icon
        property string label
        property string detail
        property bool ticked: false
        signal picked()
        width: parent ? parent.width : 0
        height: 54
        color: ma.pressed ? Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.08) : "transparent"
        radius: settings.round ? 12 : 0
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: row.picked()
        Rectangle { anchors { left: parent.left; leftMargin: 44; right: parent.right; bottom: parent.bottom } height: 1; color: settings.ink; opacity: 0.08 }
        Icon { x: 4; anchors.verticalCenter: parent.verticalCenter; name: row.icon; size: 24; color: settings.ink }
        Text {
            x: 44; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 80
            text: row.label; elide: Text.ElideRight
            font.pixelSize: 17
            color: settings.ink
        }
        Text {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: row.ticked ? "✓" : row.detail
            font.pixelSize: row.ticked ? 17 : 13
            color: row.ticked ? settings.accent : settings.inkSoft
        }
        MouseArea { id: ma; anchors.fill: parent; onClicked: row.picked() }
    }

    Column {
        id: col
        x: root.gutter
        y: 10
        width: root.width - 2 * root.gutter
        spacing: 0

        LibRow {
            icon: "playlist"; label: "Playlists"
            detail: { playlists.revision; return String(playlists.list().length) }
            onPicked: root.showView("playlists")
        }
        LibRow { icon: "artist"; label: "Artists"; onPicked: root.showView("artists") }
        LibRow { icon: "album"; label: "Albums"; onPicked: root.showView("albums") }
        LibRow { icon: "song"; label: "Songs"; onPicked: root.showView("songs") }

        Text {
            topPadding: 30; bottomPadding: 6; leftPadding: 4
            text: "SOURCES"
            font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1
            color: settings.inkSoft
        }
        Repeater {
            model: {
                servers.revision
                return [{ id: "", name: "Everything" }, { id: "local", name: "This phone" }]
                    .concat(servers.list().filter(function(x) { return x.enabled }))
            }
            LibRow {
                required property var modelData
                icon: modelData.id === "" ? "wave" : modelData.id === "local" ? "folder" : "server"
                label: modelData.name
                ticked: library.source === modelData.id
                onPicked: library.source = modelData.id
            }
        }
        LibRow { icon: "plus"; label: "Add a server"; onPicked: root.addServer() }

        Text {
            topPadding: 30; bottomPadding: 6; leftPadding: 4
            text: "MORE"
            font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1
            color: settings.inkSoft
        }
        LibRow { icon: "folder"; label: "Music folder"; detail: ""; onPicked: root.openSettings("library") }
        LibRow { icon: "gear"; label: "Settings"; onPicked: root.openSettings("") }
    }
}
