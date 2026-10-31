import QtQuick

// A profile picture. Shows a blank-user glyph until there is one.
Item {
    id: root
    property string source

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
        source: root.source
        cache: false
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 256
    }
}
