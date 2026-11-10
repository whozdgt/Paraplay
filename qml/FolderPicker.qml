import QtQuick
import QtQuick.Layouts

// Choose a folder without a file dialog: start at the storage places, tap a folder to go in, then "Use this folder".
Item {
    id: root
    property string startPath: ""          // opens here when it exists
    property string path: ""               // "" = the list of storage places
    signal chosen(string dir)
    signal cancelled()
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property var entries: path === "" ? folders.roots() : folders.list(path)
    readonly property int songs: path === "" ? 0 : folders.audioCount(path)

    onVisibleChanged: if (visible) path = folders.isDir(startPath) ? startPath : ""

    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: root.cancelled() }

    Rectangle {
        width: Math.min(520, root.width - 24)
        height: Math.min(640, root.height - 48)
        anchors.centerIn: parent
        color: settings.round ? settings.surface : Qt.rgba(1, 1, 1, 0.97)
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 10

            Text { text: "Choose your music folder"; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri }

            RowLayout {      // where you are, and a way back up
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    visible: root.path !== ""
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                    color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.08)
                    Text { anchors.centerIn: parent; text: "‹"; font.pixelSize: 26; color: root.pri }
                    MouseArea { anchors.fill: parent; onClicked: root.path = folders.parent(root.path) }
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    font.pixelSize: 12
                    color: root.muted
                    text: root.path === "" ? "Pick where your music is kept" : root.path
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.entries
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 52
                    color: ma.pressed ? Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.08) : "transparent"
                    Text {
                        anchors { left: parent.left; leftMargin: 8; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: parent.modelData.name
                        elide: Text.ElideRight
                        font.pixelSize: 15
                        color: root.pri
                    }
                    Text { id: chev; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } text: "›"; font.pixelSize: 22; color: root.muted }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(0, 0, 0, 0.06) }
                    MouseArea { id: ma; anchors.fill: parent; onClicked: root.path = parent.modelData.path }
                }
                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    color: root.muted
                    font.pixelSize: 13
                    text: "No folders in here.\nYou can still use this one."
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.path !== ""
                wrapMode: Text.Wrap
                font.pixelSize: 12
                color: root.songs > 0 ? settings.accent : root.muted
                text: root.songs > 0 ? root.songs + " songs directly in this folder. Folders inside it are included too."
                                     : "No songs directly in this folder. Folders inside it are included too."
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Btn { Layout.fillWidth: true; label: "Use this folder"; enabled: root.path !== ""; onClicked: root.chosen(root.path) }
                Btn { Layout.preferredWidth: 110; primary: false; label: "Cancel"; onClicked: root.cancelled() }
            }
        }
    }
}
