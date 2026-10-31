import QtQuick
import QtQuick.Layouts

ListView {
    id: list
    signal menuRequested(string path, real gx, real gy)
    clip: true
    model: library
    reuseItems: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    delegate: Rectangle {
        id: row
        required property int index
        required property string path
        required property string title
        required property string artist
        required property string duration
        required property string badge
        required property bool hires
        required property bool remote
        readonly property bool current: player.path === path

        width: ListView.view.width
        height: 56
        color: current ? Qt.rgba(1, 1, 1, 0.65) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : "transparent")

        Rectangle { visible: row.current; width: 3; height: parent.height; color: settings.accent }
        RowLayout {
            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
            spacing: 0
            Text {
                Layout.fillWidth: true; Layout.preferredWidth: 100
                text: row.title; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.Medium; color: list.pri
            }
            Text {
                Layout.fillWidth: true; Layout.preferredWidth: 100
                text: row.artist; elide: Text.ElideRight; font.pixelSize: 14; color: list.muted
            }
            Item {
                Layout.preferredWidth: 100; Layout.preferredHeight: 20
                visible: settings.badges
                Rectangle { visible: row.hires; width: 3; height: parent.height; color: settings.accent }
                Text {
                    x: 8; anchors.verticalCenter: parent.verticalCenter
                    text: row.badge; font.pixelSize: 12; color: row.hires ? list.pri : list.muted
                }
            }
            Item {
                Layout.preferredWidth: 28; Layout.preferredHeight: 20
                Icon { visible: row.remote; anchors.centerIn: parent; name: "cloud"; size: 14; color: list.muted }
            }
            Text { Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; text: row.duration; font.pixelSize: 14; color: list.muted }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (m) => {
                if (m.button === Qt.RightButton) { const p = row.mapToItem(null, m.x, m.y); list.menuRequested(row.path, p.x, p.y) }
                else player.playRow(row.index)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: list.count === 0
        horizontalAlignment: Text.AlignHCenter
        color: list.muted
        text: library.scanning ? "Scanning your music…" : "No music found.\nSet your music folder in Settings, or add a server."
    }
}
