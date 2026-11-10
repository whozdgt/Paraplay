import QtQuick

// A small label, for example the quality of the song a friend is playing.
Rectangle {
    id: root
    property string text
    property bool accent: false
    implicitWidth: lbl.implicitWidth + (accent ? 22 : 16)
    implicitHeight: 22
    radius: settings.round ? height / 2 : 0
    color: settings.round ? settings.chipFill : settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.85)
    Rectangle { visible: root.accent && !settings.round; width: 3; height: parent.height; color: settings.accent }
    Text { id: lbl; anchors.centerIn: parent; text: root.text; font.pixelSize: 11; color: settings.ink }
}
