import QtQuick

// Change the profile picture or the banner: drop an image file on the window, or paste its path.
Item {
    id: root
    property string kind: "avatar"                 // avatar | banner
    readonly property bool isBanner: kind === "banner"
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    property string chosen: ""                     // file:// URL of the picked file
    property string note: ""
    readonly property string current: isBanner ? account.bannerUrl : account.avatarUrl
    readonly property string shown: chosen !== "" ? chosen : current
    readonly property bool shownIsGif: shown.toLowerCase().endsWith(".gif")

    function pickFile(text) {
        const u = account.localFileUrl(text)
        if (u === "") { note = "Couldn't find that file."; chosen = ""; return }
        note = ""
        chosen = u
    }
    function send() {
        const u = chosen !== "" ? chosen : account.localFileUrl(pathIn.text)
        if (u === "") { note = "Drop a picture onto this window, or paste its path, first."; return }
        note = ""
        account.uploadImage(kind, u)
    }
    onVisibleChanged: if (visible) { pathIn.text = ""; chosen = ""; note = ""; pathIn.forceActiveFocus() }

    Connections {
        target: account
        function onImageDone(k, ok, text) {
            if (!root.visible || k !== root.kind) return
            if (ok) root.visible = false
            else root.note = text
        }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(1, 1, 1, 0.35) }
    MouseArea { anchors.fill: parent; onClicked: root.visible = false }
    DropArea {
        anchors.fill: parent
        onDropped: (e) => { if (e.hasUrls) root.pickFile(String(e.urls[0])) }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(460, root.width - 24)
        height: content.implicitHeight + 40
        color: Qt.rgba(1, 1, 1, 0.94)
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 14

            Text {
                text: root.isBanner ? "Change banner" : "Change profile picture"
                font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri
            }

            // What it will look like (the middle of the picture is shown).
            Rectangle {
                width: root.isBanner ? parent.width : 120
                height: 120
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.07)
                clip: true

                Avatar {
                    anchors.fill: parent
                    visible: !root.isBanner && root.chosen === ""
                    source: root.current
                }
                Image {
                    anchors.fill: parent
                    visible: root.shown !== "" && (!root.isBanner ? root.chosen !== "" : !root.shownIsGif)
                    source: visible ? root.shown : ""
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 640
                }
                AnimatedImage {
                    anchors.fill: parent
                    visible: root.isBanner && root.shown !== "" && root.shownIsGif
                    source: visible ? root.shown : ""
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    playing: visible
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.isBanner && root.shown === ""
                    text: "No banner yet"
                    font.pixelSize: 12; color: root.muted
                }
            }

            Text {
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 11; color: root.muted
                text: root.isBanner
                    ? "Drop a picture onto this window, or paste its file path below and press Enter. Wide pictures work best (about 1400 × 400). PNG, JPEG, WebP or GIF. A GIF banner is uploaded as it is and can be up to 3 MB and 1200 × 600."
                    : "Drop a picture onto this window, or paste its file path below and press Enter. PNG, JPEG or WebP. The middle square is used and it is shrunk for you."
            }

            Rectangle {
                width: parent.width; height: 40
                color: Qt.rgba(1, 1, 1, 0.8); border.width: 1
                border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                TextInput {
                    id: pathIn
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter
                    font.pixelSize: 13; color: root.pri; clip: true; selectByMouse: true
                    onAccepted: root.pickFile(text)
                    Keys.onEscapePressed: root.visible = false
                }
                Text {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    visible: pathIn.text === ""
                    text: "/home/you/Pictures/me.png"
                    font.pixelSize: 13; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.35)
                }
            }

            Text {
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 12
                visible: text !== ""
                color: account.uploading ? root.muted : Qt.rgba(0.7, 0.15, 0.15, 1)
                text: account.uploading ? "Uploading…" : root.note
            }

            Row {
                spacing: 10
                Btn { label: "Upload"; enabled: !account.uploading; onClicked: root.send() }
                Btn {
                    primary: false; label: "Remove"
                    visible: root.current !== "" && root.chosen === ""
                    enabled: !account.uploading
                    onClicked: account.removeImage(root.kind)
                }
                Btn { primary: false; label: "Cancel"; onClicked: root.visible = false }
            }

            Text {
                width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 10; color: root.muted
                text: "Only use pictures you are allowed to share. Other people can see them, depending on your privacy settings."
            }
        }
    }
}
