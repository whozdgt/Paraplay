import QtQuick
import QtQuick.Effects

// A picture with rounded corners (Midnight) or square ones (Classic, radius 0, drawn as a plain Image).
Item {
    id: root
    property alias source: img.source
    property alias fillMode: img.fillMode
    property alias sourceSize: img.sourceSize
    property alias status: img.status
    property real radius: 0

    Image {
        id: img
        anchors.fill: parent
        visible: root.radius <= 0
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }
    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.radius > 0
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black"; antialiasing: true }
    }
    MultiEffect {
        anchors.fill: parent
        visible: root.radius > 0 && img.status === Image.Ready
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
