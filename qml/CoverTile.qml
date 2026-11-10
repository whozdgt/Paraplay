import QtQuick

// One cover in a carousel: the album or playlist picture, or an artist's photo.
// A little cloud in the corner marks music that streams from a server.
Rectangle {
    id: root
    property var entry: null                 // { name, sub, art, key, remote }
    property string kind: "album"            // album | artist | playlist

    color: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.5)
    radius: settings.round ? (root.kind === "artist" ? width / 2 : Math.min(18, Math.max(8, width * 0.07))) : 0
    clip: false

    RoundImage {
        visible: root.kind !== "artist"
        anchors.fill: parent
        radius: root.radius
        source: root.entry ? (root.entry.art || "") : ""
        sourceSize: Qt.size(400, 400)
    }
    ArtistPhoto {
        visible: root.kind === "artist"
        anchors.fill: parent
        name: root.kind === "artist" && root.entry ? root.entry.name : ""
    }
    Rectangle {
        visible: root.entry ? !!root.entry.remote : false
        anchors { right: parent.right; bottom: parent.bottom }
        anchors.margins: settings.round ? 6 : 0
        width: 26
        height: 26
        radius: settings.round ? 13 : 0
        color: Qt.rgba(0, 0, 0, 0.55)
        Icon { anchors.centerIn: parent; name: "cloud"; size: 15; color: "white" }
    }
}
