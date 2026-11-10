import QtQuick

// A short celebration for a brand-new account: confetti fired up from both bottom corners and a
// "Heya <name>!" card. It takes no clicks, so the app stays usable underneath.
Item {
    id: root
    property string name
    property bool running: false
    property real clock: 0                  // seconds since the confetti went off
    readonly property real total: 4.4
    readonly property var palette: ["#f2994a", "#eb5757", "#f2c94c", "#27ae60", "#2d9cdb", "#9b51e0", "#ff7eb6", "#56ccf2"]

    visible: running

    function play(who) {
        name = who
        running = true
        clockAnim.restart()
        cardAnim.restart()
    }

    NumberAnimation { id: clockAnim; target: root; property: "clock"; from: 0; to: root.total; duration: root.total * 1000; onFinished: root.running = false }

    Repeater {
        model: root.running ? 120 : 0
        Rectangle {
            id: piece
            required property int index
            readonly property bool fromLeft: index % 2 === 0
            readonly property real startX: fromLeft ? root.width * 0.04 : root.width * 0.96
            readonly property real g: root.height * 1.25                                    // pull of gravity, px per second squared
            readonly property real peak: root.height * (0.4 + Math.random() * 0.5)          // how high it flies
            readonly property real up: Math.sqrt(2 * g * peak)
            readonly property real drift: root.width * (0.06 + Math.random() * 0.26) * (fromLeft ? 1 : -1)
            readonly property real sway: 4 + Math.random() * 10
            readonly property real swayRate: 3 + Math.random() * 4
            readonly property real spin: (Math.random() < 0.5 ? -1 : 1) * (120 + Math.random() * 480)
            readonly property real flip: 4 + Math.random() * 7
            readonly property real born: Math.random() * 0.25                                // a few pieces leave a moment later
            readonly property real t: Math.max(0, root.clock - born)

            width: 7 + Math.random() * 5
            height: width * (1.3 + Math.random() * 0.8)
            color: root.palette[index % root.palette.length]
            x: startX + drift * t + Math.sin(t * swayRate + index) * sway
            y: root.height - up * t + 0.5 * g * t * t
            rotation: index * 37 + spin * t
            opacity: root.clock > root.total - 0.8 ? Math.max(0, (root.total - root.clock) / 0.8) : 1
            visible: root.clock >= born && y < root.height + 40
            transform: Scale {
                origin.x: piece.width / 2
                origin.y: piece.height / 2
                yScale: 0.25 + 0.75 * Math.abs(Math.cos(piece.t * piece.flip + piece.index))
            }
        }
    }

    Item {
        id: card
        readonly property bool phone: root.width < 720
        anchors.centerIn: parent
        width: Math.min(root.width - 32, hello.implicitWidth + 72)
        height: hello.implicitHeight + sub.implicitHeight + 52
        opacity: 0
        scale: 0.6

        Rectangle { anchors.fill: parent; color: settings.ground; opacity: 0.94 }
        Rectangle { width: 4; height: parent.height; color: settings.accent }
        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                id: hello
                width: card.width - 72
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Heya " + root.name + "!"
                font.pixelSize: card.phone ? 30 : 40
                font.weight: Font.DemiBold
                color: settings.ink
            }
            Text {
                id: sub
                width: hello.width
                horizontalAlignment: Text.AlignHCenter
                text: "Your account is ready."
                font.pixelSize: 14
                color: Qt.rgba(settings.ink.r, settings.ink.g, settings.ink.b, 0.72)
            }
        }

        SequentialAnimation {
            id: cardAnim
            ScriptAction { script: { card.opacity = 0; card.scale = 0.6 } }
            ParallelAnimation {
                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 300 }
                NumberAnimation { target: card; property: "scale"; to: 1; duration: 520; easing.type: Easing.OutBack }
            }
            PauseAnimation { duration: 2800 }
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 600 }
        }
    }
}
