import QtQuick
import QtQuick.Layouts

// A friend's playlist. Their songs arrive as text only; every song you also own plays from your own copy.
Item {
    id: root
    readonly property int gut: width < 600 ? 16 : 36      // side margin; smaller on a phone
    readonly property var pl: social.playlist
    readonly property var prof: social.profile
    readonly property bool ready: !!pl.id && pl.loading !== true && pl.missing !== true
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool knownOwner: prof.username === pl.owner
    property bool saved: false

    onPlChanged: saved = false

    function playAt(row) {
        if (row < 0) return
        library.setPlaylistFilter("friend", pl.name, social.matchedPaths())
        player.playRow(row)
    }

    Item {
        x: root.gut
        width: root.width - 2 * root.gut
        height: root.height

        Row {
            id: by
            spacing: 12
            height: 28
            visible: root.ready
            Avatar { anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; source: root.knownOwner ? (root.prof.avatar || "") : "" }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12; color: root.muted
                text: "by " + (root.knownOwner ? root.prof.name + " · " : "") + "@" + root.pl.owner + " · " + root.pl.total + (root.pl.total === 1 ? " song" : " songs")
            }
        }

        Text {
            visible: root.pl.loading === true
            text: "Loading…"
            font.pixelSize: 14; color: root.muted
        }
        Text {
            visible: root.pl.missing === true
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 14; color: root.muted
            text: "This playlist isn't available. It may have been made private or deleted."
        }

        Rectangle {
            id: box
            visible: root.ready
            y: by.height + 14
            width: parent.width
            height: 64
            color: (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6))
            Column {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 32 - btns.width - 16
                spacing: 8
                Text { text: "You have " + root.pl.have + " of " + root.pl.total + " songs"; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.pri }
                Rectangle {
                    width: parent.width; height: 6
                    color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.12)
                    Rectangle { width: root.pl.total > 0 ? parent.width * root.pl.have / root.pl.total : 0; height: 6; color: settings.accent }
                }
            }
            Row {
                id: btns
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                spacing: 10
                Btn { label: "Play all (" + root.pl.have + ")"; height: 36; enabled: root.pl.have > 0; onClicked: root.playAt(0) }
                Btn {
                    primary: false
                    label: root.saved ? "Saved" : "Save to my playlists"
                    height: 36
                    enabled: root.pl.have > 0 && !root.saved
                    onClicked: { playlists.createWith(root.pl.name, social.matchedPaths()); root.saved = true }
                }
            }
        }

        ListView {
            id: list
            visible: root.ready
            anchors { left: parent.left; right: parent.right; top: box.bottom; topMargin: 10; bottom: foot.top; bottomMargin: 6 }
            clip: true
            model: root.ready ? root.pl.tracks : []
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool current: modelData.matched === true && player.path === social.matchedPaths()[modelData.row]
                width: ListView.view.width
                height: 46
                color: current ? (settings.solid ? settings.hiSel : Qt.rgba(1, 1, 1, 0.65)) : (ma.containsMouse && modelData.matched ? (settings.solid ? settings.hiHover : Qt.rgba(1, 1, 1, 0.3)) : "transparent")
                opacity: modelData.matched ? 1 : 0.5
                Rectangle { visible: row.current; width: 3; height: parent.height; color: settings.accent }
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 12
                    Text { Layout.fillWidth: true; Layout.preferredWidth: 100; text: row.modelData.title; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.Medium; color: root.pri }
                    Text { Layout.fillWidth: true; Layout.preferredWidth: 80; text: row.modelData.artist; elide: Text.ElideRight; font.pixelSize: 12; color: root.muted }
                    Text {
                        Layout.preferredWidth: 200
                        text: row.modelData.matched ? row.modelData.badge + " · " + row.modelData.where : "Not in your library"
                        elide: Text.ElideRight
                        font.pixelSize: 11; color: root.muted
                    }
                    Text { Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight; text: row.modelData.time; font.pixelSize: 12; color: root.muted }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: row.modelData.matched === true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.playAt(row.modelData.row)
                }
            }
        }

        Text {
            id: foot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            visible: root.ready
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 11; color: root.muted
            text: "Songs are matched by title, artist, album and length. Your own copy plays, at its own quality. @" + root.pl.owner + "'s files are never sent."
        }
    }
}
