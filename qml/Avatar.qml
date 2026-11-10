import QtQuick
import QtQuick.Effects

// A profile picture. Shows a blank-user glyph until there is one. Round in Midnight.
Item {
    id: root
    property string source
    property real radius: settings.round ? Math.min(width, height) / 2 : 0

    Item {
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: shape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        Rectangle { anchors.fill: parent; color: settings.round ? "#3a3a3c" : "#cfc8d6" }
        Item {
            anchors.fill: parent
            clip: true
            visible: img.status !== Image.Ready
            Rectangle { width: parent.width * 0.34; height: width; radius: width / 2; color: settings.round ? "#8e8e93" : "white"; x: (parent.width - width) / 2; y: parent.height * 0.2 }
            Rectangle { width: parent.width * 0.72; height: width; radius: width / 2; color: settings.round ? "#8e8e93" : "white"; x: (parent.width - width) / 2; y: parent.height * 0.58 }
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
    Item {
        id: shape
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black"; antialiasing: true }
    }
}
