import QtQuick
import QtQuick.Effects

// Square cover art, or a spinning black record with the art as its label.
Item {
    id: root
    property url source
    property bool record: false
    property bool spinning: false
    property real hoverScale: 1
    readonly property real labelRatio: 0.95 - settings.ringCount * 0.095   // fewer rings = bigger cover art
    signal clicked()
    width: 44
    height: 44

    Item {
        id: zoom
        anchors.fill: parent
        transformOrigin: Item.Bottom
        scale: (ma.containsMouse && root.hoverScale > 1) ? root.hoverScale : 1
        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

        Rectangle {
            anchors.fill: parent
            visible: !root.record
            color: settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.5)
            Image {
                anchors.fill: parent
                source: root.source
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Math.max(128, root.width * 3), Math.max(128, root.width * 3))
            }
        }

        Item {
            id: disc
            anchors.fill: parent
            visible: root.record
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 6000; loops: Animation.Infinite
                running: root.record && root.spinning && root.visible
            }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#0d0b10" }
            Repeater {
                model: settings.ringCount
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: disc.width * (root.labelRatio + (index + 1) * 0.095)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: "#2a2531"
                    border.width: 1
                }
            }
            Item {
                id: label
                anchors.centerIn: parent
                width: disc.width * root.labelRatio
                height: width
                Rectangle { anchors.fill: parent; radius: width / 2; color: settings.accent }
                Image {
                    id: labImg
                    anchors.fill: parent
                    source: root.source
                    visible: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(256, 256)
                }
                Item {
                    id: maskItem
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle { anchors.fill: parent; radius: width / 2 }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: labImg
                    visible: labImg.status === Image.Ready
                    maskEnabled: true
                    maskSource: maskItem
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(3, parent.width * 0.14)
                    height: width
                    radius: width / 2
                    color: "#e6e0ea"
                }
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
