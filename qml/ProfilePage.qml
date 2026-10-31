import QtQuick
import QtQuick.Layouts

Flickable {
    id: root
    signal signInRequested()
    signal imageRequested(string kind)      // "avatar" or "banner"
    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property string who: account.username
    property string vis: "private"
    property bool disc: false
    property bool showPl: false
    property bool confirmDelete: false

    function load() {
        nameIn.text = account.displayName; bioIn.text = account.bio
        vis = account.visibility; disc = account.discoverable; showPl = account.showPlaylists
        confirmDelete = false
    }
    onVisibleChanged: if (visible) load()
    onWhoChanged: load()

    ColumnLayout {
        id: col
        x: 36
        width: Math.min(560, root.width - 72)
        spacing: 0

        ColumnLayout {
            visible: !account.signedIn
            Layout.fillWidth: true
            spacing: 14
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 14; color: root.pri; text: "You're using the app as a guest. Your playlists stay on this computer." }
            Btn { label: "Sign in or create an account"; onClicked: root.signInRequested() }
        }

        ColumnLayout {
            visible: account.signedIn
            Layout.fillWidth: true
            spacing: 0
            // Banner (a still picture or a GIF), then the profile picture and name underneath.
            Item {
                id: head
                Layout.fillWidth: true
                Layout.preferredHeight: 160 + 16 + 88

                Rectangle {
                    id: bannerBox
                    width: parent.width; height: 160
                    clip: true
                    color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.07)
                    readonly property bool has: account.bannerUrl !== ""
                    readonly property bool animated: account.bannerAnimated

                    // The picture is only loaded while this page is showing, and a GIF only plays
                    // while the window is in front, so it costs nothing the rest of the time.
                    Image {
                        anchors.fill: parent
                        visible: bannerBox.has && !bannerBox.animated
                        source: visible ? account.bannerUrl : ""
                        cache: false
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 1120
                    }
                    AnimatedImage {
                        anchors.fill: parent
                        visible: bannerBox.has && bannerBox.animated
                        source: visible ? account.bannerUrl : ""
                        cache: false
                        fillMode: Image.PreserveAspectCrop
                        playing: visible && Window.active
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !bannerBox.has
                        text: "No banner yet"
                        font.pixelSize: 12; color: root.muted
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.imageRequested("banner") }
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                        width: bannerBtn.implicitWidth + 28; height: 32
                        color: Qt.rgba(1, 1, 1, 0.88)
                        Row {
                            id: bannerBtn
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "camera"; size: 16; color: root.pri }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "Change banner"; font.pixelSize: 12; color: root.pri }
                        }
                    }
                }

                Item {
                    id: avatarBox
                    x: 0; y: 160 + 16
                    width: 88; height: 88
                    Avatar { anchors.fill: parent; source: account.avatarUrl }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.imageRequested("avatar") }
                    Rectangle {
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: 28; height: 28
                        color: root.pri
                        Icon { anchors.centerIn: parent; name: "camera"; size: 15; color: "white" }
                    }
                }
                Column {
                    x: avatarBox.width + 16
                    anchors.verticalCenter: avatarBox.verticalCenter
                    spacing: 2
                    Text {
                        width: Math.min(implicitWidth, head.width - 120); elide: Text.ElideRight
                        text: account.displayName || account.username
                        font.pixelSize: 22; font.weight: Font.DemiBold; color: root.pri
                    }
                    Text { text: "@" + account.username; font.pixelSize: 13; color: root.muted }
                }
            }

            SectionLabel { text: "DISPLAY NAME" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                color: Qt.rgba(1, 1, 1, 0.6); border.width: 1; border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                TextInput { id: nameIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; clip: true; selectByMouse: true; maximumLength: 40; font.pixelSize: 14; color: root.pri }
            }
            SectionLabel { text: "BIO" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                color: Qt.rgba(1, 1, 1, 0.6); border.width: 1; border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                TextInput { id: bioIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 } verticalAlignment: TextInput.AlignVCenter; clip: true; selectByMouse: true; maximumLength: 160; font.pixelSize: 14; color: root.pri }
            }

            SectionLabel { text: "WHO CAN SEE MY PROFILE" }
            Row {
                Repeater {
                    model: [{ k: "private", t: "Private" }, { k: "friends", t: "Friends" }, { k: "public", t: "Public" }]
                    Rectangle {
                        required property var modelData
                        readonly property bool sel: root.vis === modelData.k
                        width: 100; height: 36
                        color: sel ? root.pri : "transparent"
                        border.width: 1; border.color: sel ? root.pri : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                        Text { anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 13; color: parent.sel ? "white" : root.pri }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.vis = parent.modelData.k; if (root.vis === "public") root.disc = true }
                        }
                    }
                }
            }
            Text { Layout.topMargin: 6; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 11; color: root.muted; text: "Private is the default. Nothing is shared until you choose." }

            ToggleRow { Layout.topMargin: 8; label: "Appear in search"; checked: root.disc; onToggled: root.disc = !root.disc }
            ToggleRow { label: "Show my playlists to others"; checked: root.showPl; onToggled: root.showPl = !root.showPl }
            ToggleRow { label: "Sync my playlists"; note: "Keeps them on all your computers"; checked: account.syncPlaylists; onToggled: account.syncPlaylists = !account.syncPlaylists }

            Row {
                Layout.topMargin: 14
                spacing: 10
                Btn { label: "Save profile"; enabled: !account.busy; onClicked: account.saveProfile(nameIn.text, bioIn.text, root.vis, root.disc, root.showPl) }
                Btn { primary: false; label: "Sync now"; enabled: !account.busy; onClicked: account.syncNow() }
                Btn { primary: false; label: "Sign out"; onClicked: account.signOut() }
            }
            Text {
                Layout.topMargin: 10; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: root.muted
                text: account.message + (account.lastSync !== "" ? "   Last synced " + account.lastSync : "")
            }
            Row {
                Layout.topMargin: 18
                spacing: 10
                Btn { primary: false; label: "Download my data"; onClicked: account.exportData() }
                Btn { primary: false; label: root.confirmDelete ? "Tap again to delete everything" : "Delete account…"; onClicked: { if (root.confirmDelete) account.deleteAccount(); else root.confirmDelete = true } }
            }
        }
    }
}
