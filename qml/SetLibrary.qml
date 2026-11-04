import QtQuick
import QtQuick.Layouts

// Settings › Library: where the music is, the servers it streams from, and how artist names are read.
ColumnLayout {
    id: root
    property var panel                      // the SettingsPanel, for its signals and little helpers
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property color boxFill: settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)

    spacing: 0

    SetGroup {
        first: true
        title: "Music"
        section: "Library"
        SetBlock {
            label: "Music folder"
            keywords: "directory folder path scan choose files"
            Text { text: "Music folder"; font.pixelSize: 14; color: root.pri }
            Text {      // phones: just show where it points; changing it is done with the button below
                visible: Qt.platform.os === "android"
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere; font.pixelSize: 13; color: root.muted
                text: settings.musicDir
            }
            Rectangle {
                visible: Qt.platform.os !== "android"
                Layout.fillWidth: true; Layout.preferredHeight: 40
                color: root.boxFill
                border.width: pathInput.activeFocus ? 2 : 1
                border.color: pathInput.activeFocus ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                TextInput {
                    id: pathInput
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true; selectByMouse: true; font.pixelSize: 13; color: root.pri
                    text: settings.musicDir
                    onAccepted: settings.musicDir = text
                }
            }
            Btn { Layout.topMargin: 4; large: true; label: "Choose folder…"; onClicked: root.panel.chooseFolderRequested() }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.25; color: root.muted
                text: library.scanning ? "Scanning…" : (Qt.platform.os === "android" ? "Tap Choose folder to pick where your music is. It is scanned right away." : "Choose a folder, or type its path and press Enter.")
            }
        }
    }

    SetGroup {
        title: "Servers"
        section: "Library"
        SetBlock {
            label: "Servers"
            keywords: "navidrome subsonic jellyfin stream streaming server add remove sync"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "Stream from your own Navidrome, Subsonic or Jellyfin server. Songs play as the original files, never re-encoded."
            }
            Repeater {
                model: { servers.revision; return servers.list() }
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool asking: root.panel.confirmId === modelData.id
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.preferredHeight: inner.implicitHeight + 24
                    color: root.boxFill
                    ColumnLayout {
                        id: inner
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: card.modelData.name; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.pri }
                            Text { text: card.modelData.kind === "jellyfin" ? "Jellyfin" : "Navidrome / Subsonic"; font.pixelSize: 11; color: root.muted }
                        }
                        Text { Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 12; color: root.muted; text: card.modelData.url + " · " + card.modelData.user }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12
                            color: card.modelData.state === "error" ? "#b91c1c" : root.pri
                            text: root.panel.statusLine(card.modelData)
                        }
                        ToggleRow {
                            label: "Use this server"
                            checked: card.modelData.enabled
                            onToggled: servers.setEnabled(card.modelData.id, !card.modelData.enabled)
                        }
                        Flow {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 2
                            spacing: 8
                            Btn { large: true; label: "Sync now"; primary: false; enabled: card.modelData.enabled && card.modelData.state !== "syncing"; onClicked: servers.syncNow(card.modelData.id) }
                            Btn {
                                large: true
                                label: card.asking ? "Yes, remove it" : "Remove"
                                primary: false
                                onClicked: { if (card.asking) { root.panel.confirmId = ""; servers.removeServer(card.modelData.id) } else root.panel.confirmId = card.modelData.id }
                            }
                            Btn { visible: card.asking; large: true; label: "Keep it"; primary: false; onClicked: root.panel.confirmId = "" }
                        }
                    }
                }
            }
            Btn { Layout.topMargin: 8; large: true; label: "Add a server…"; onClicked: root.panel.addServerRequested() }
            Text {
                Layout.fillWidth: true; Layout.topMargin: 4; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "Your password itself is never saved. Navidrome/Subsonic keeps a one-way sign-in token and Jellyfin keeps an access token, in a private file only your user can read."
            }
        }
    }

    SetGroup {
        title: "Artist names"
        section: "Library"
        ToggleRow {
            label: "Split artists on , and &"
            note: "A song by two artists appears under both"
            keywords: "artist names split comma ampersand"
            checked: settings.artistSplit
            onToggled: settings.artistSplit = !settings.artistSplit
        }
        SetBlock {
            label: "Keep together"
            keywords: "artist names exceptions together one per line"
            Text { Layout.fillWidth: true; font.pixelSize: 13; color: root.muted; wrapMode: Text.Wrap; text: "Keep together (one name per line):" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 110
                color: root.boxFill
                border.width: te.activeFocus ? 2 : 1
                border.color: te.activeFocus ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                Flickable {
                    anchors { fill: parent; margins: 8 }
                    clip: true; contentHeight: te.paintedHeight
                    TextEdit {
                        id: te
                        width: parent.width; wrapMode: TextEdit.Wrap; selectByMouse: true
                        font.pixelSize: 13; color: root.pri
                        text: settings.artistExceptions
                        onActiveFocusChanged: if (!activeFocus) settings.artistExceptions = text
                    }
                }
            }
        }
    }
}
