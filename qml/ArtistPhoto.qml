import QtQuick

// An artist's picture, or a blank-user glyph when there isn't one yet.
Item {
    id: root
    property string name
    readonly property string src: { artistImages.revision; return artistImages.url(root.name) }

    Rectangle { anchors.fill: parent; color: "#cfc8d6" }
    Item {
        anchors.fill: parent
        clip: true
        visible: img.status !== Image.Ready
        Rectangle { width: parent.width * 0.34; height: width; radius: width / 2; color: "white"; x: (parent.width - width) / 2; y: parent.height * 0.2 }
        Rectangle { width: parent.width * 0.72; height: width; radius: width / 2; color: "white"; x: (parent.width - width) / 2; y: parent.height * 0.58 }
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.src
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(400, 400)
    }
}
