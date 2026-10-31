import QtQuick

// A small label, for example the quality of the song a friend is playing.
Rectangle {
    id: root
    property string text
    property bool accent: false
    implicitWidth: lbl.implicitWidth + (accent ? 22 : 16)
    implicitHeight: 22
    color: Qt.rgba(1, 1, 1, 0.85)
    Rectangle { visible: root.accent; width: 3; height: parent.height; color: settings.accent }
    Text { id: lbl; anchors.centerIn: parent; text: root.text; font.pixelSize: 11; color: settings.primary }
}
