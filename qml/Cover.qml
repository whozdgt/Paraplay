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

    // Turn the record by hand (record style, expanded player): clockwise winds the song up, anticlockwise slows it down.
    // Letting go eases it back to normal. The pitch follows the speed, like a real record.
    property bool turnable: false
    property real rate: 1
    property real extra: 0               // degrees the hand has added to the record's own spin
    property bool turning: false
    property bool turned: false          // this press really was a turn, not a tap
    property real omega: 0               // how fast the hand turns it, degrees per second, clockwise positive
    property real moved: 0
    property real lastAngle: 0
    property real lastT: 0
    readonly property real perDoubling: 120      // a hand turning 120 degrees a second doubles the speed

    onRateChanged: if (turnable) player.setSpeed(rate)
    onTurnableChanged: if (!turnable) { settle.stop(); turning = false; rate = 1; player.setSpeed(1) }
    Component.onDestruction: if (rate !== 1) player.setSpeed(1)
    NumberAnimation { id: settle; target: root; property: "rate"; to: 1; duration: 450; easing.type: Easing.OutCubic }
    Timer {      // a hand that stops moving stops changing the speed
        id: decay
        interval: 40; repeat: true
        onTriggered: {
            if (Date.now() - root.lastT > 90) {
                root.omega *= 0.7
                if (root.turning) root.rate = Math.max(0.5, Math.min(2, 1 + root.omega / root.perDoubling))
            }
        }
    }

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
            id: turner
            anchors.fill: parent
            rotation: root.extra
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
    }
    Rectangle {      // the speed, while the record is being turned
        visible: root.turning
        anchors.centerIn: parent
        width: rateText.implicitWidth + 24
        height: 30
        color: Qt.rgba(0, 0, 0, 0.62)
        Text { id: rateText; anchors.centerIn: parent; text: root.rate.toFixed(2) + "×"; font.pixelSize: 14; color: "white" }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function angleAt(x, y) { return Math.atan2(y - height / 2, x - width / 2) * 180 / Math.PI }
        onPressed: (m) => {
            if (!root.turnable) return
            settle.stop()
            root.turned = false
            root.moved = 0
            root.omega = 0
            root.lastAngle = angleAt(m.x, m.y)
            root.lastT = Date.now()
            decay.start()
        }
        onPositionChanged: (m) => {
            if (!pressed || !root.turnable) return
            if (Math.hypot(m.x - width / 2, m.y - height / 2) < width * 0.08) return      // too near the middle to tell which way
            const a = angleAt(m.x, m.y)
            let d = a - root.lastAngle
            if (d > 180) d -= 360
            if (d < -180) d += 360
            const now = Date.now()
            const dt = Math.max(8, now - root.lastT) / 1000
            root.lastAngle = a
            root.lastT = now
            root.moved += Math.abs(d)
            if (root.moved > 10) root.turned = true
            if (!root.turned) return
            root.turning = true
            root.extra += d
            root.omega = root.omega * 0.6 + (d / dt) * 0.4
            root.rate = Math.max(0.5, Math.min(2, 1 + root.omega / root.perDoubling))
        }
        onReleased: { decay.stop(); if (root.turning) { root.turning = false; settle.start() } }
        onCanceled: { decay.stop(); if (root.turning) { root.turning = false; settle.start() } }
        onClicked: if (!root.turned) root.clicked()
    }
}
