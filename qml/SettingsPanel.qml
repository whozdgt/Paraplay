import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    signal close()
    signal addServerRequested()
    signal chooseFolderRequested()
    property string cat: "customisation"
    property var layout                    // HomeLayout: what the Home page shows
    property bool confirmForget: false     // "Forget my listening history" is waiting for a second press
    readonly property bool compact: width < 560      // phone: the sections become a row of tabs along the top
    property string confirmId: ""          // server whose Remove button is waiting for a second press
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property var cats: [
        { k: "directories", t: "Directories", s: "Folders" }, { k: "servers", t: "Servers", s: "Servers" }, { k: "audio", t: "Audio", s: "Audio" },
        { k: "customisation", t: "Customisation", s: "Look" }, { k: "home", t: "Home page", s: "Home" }, { k: "cover", t: "Cover art", s: "Covers" },
        { k: "theme", t: "Theme colours", s: "Colours" }, { k: "updates", t: "Updates", s: "Updates" }]

    function ago(ms) {
        if (!ms) return "never"
        const s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 60) return "just now"
        if (s < 3600) return Math.round(s / 60) + " min ago"
        if (s < 86400) return Math.round(s / 3600) + " h ago"
        return Math.round(s / 86400) + " days ago"
    }
    function statusLine(sv) {
        if (!sv.enabled) return "Off. Its songs are hidden."
        if (sv.state === "syncing") return "Loading songs… " + sv.progress
        if (sv.state === "error") return sv.error !== "" ? sv.error : "Couldn't reach the server."
        if (sv.state === "ok") return sv.count + " songs" + (sv.detail !== "" ? " · " + sv.detail : "") + " · updated " + ago(sv.lastSync)
        return sv.count > 0 ? sv.count + " songs (saved copy)" : "Waiting…"
    }

    color: compact ? settings.bgColor : Qt.rgba(1, 1, 1, 0.85)
    MouseArea { anchors.fill: parent }   // clicks inside must not reach the close-overlay

    Flickable {
        id: tabStrip
        visible: root.compact
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: root.compact ? 48 : 0
        contentWidth: tabRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Row {
            id: tabRow
            leftPadding: 8
            Repeater {
                model: root.cats
                Item {
                    required property var modelData
                    readonly property bool on: root.cat === modelData.k
                    width: tabLabel.implicitWidth + 22
                    height: 48
                    Text { id: tabLabel; anchors.centerIn: parent; text: parent.modelData.s; font.pixelSize: 13; font.weight: parent.on ? Font.DemiBold : Font.Normal; color: root.pri }
                    Rectangle {
                        anchors.bottom: parent.bottom; width: parent.width
                        height: parent.on ? 3 : 1
                        color: parent.on ? settings.accent : Qt.rgba(0, 0, 0, 0.12)
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.cat = parent.modelData.k }
                }
            }
        }
    }

    Column {
        id: nav
        visible: !root.compact
        width: 170
        height: parent.height
        topPadding: 20
        leftPadding: 10
        Text { text: "Settings"; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri; leftPadding: 12; bottomPadding: 14 }
        Repeater {
            model: root.cats
            NavItem {
                required property var modelData
                width: nav.width - 20
                text: modelData.t
                active: root.cat === modelData.k
                onClicked: root.cat = modelData.k
            }
        }
    }
    Rectangle { visible: !root.compact; x: nav.width; width: 1; height: parent.height; color: Qt.rgba(0, 0, 0, 0.08) }

    Item {
        anchors { left: root.compact ? parent.left : nav.right; right: parent.right; top: root.compact ? tabStrip.bottom : parent.top; bottom: parent.bottom; margins: root.compact ? 14 : 20 }
        RowLayout {
            id: head
            width: parent.width
            Text {
                Layout.fillWidth: true
                text: { for (const c of root.cats) if (c.k === root.cat) return c.t; return "" }
                font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri
            }
            IconButton { name: "close"; box: 36; iconSize: 18; onClicked: root.close() }
        }
        Flickable {
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: 6 }
            contentWidth: width
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: body
                width: parent.width

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "directories"
                    SectionLabel { text: "MUSIC FOLDER" }
                    Text {      // phones: just show where it points; changing it is done with the button below
                        visible: Qt.platform.os === "android"
                        Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; font.pixelSize: 13; color: root.pri
                        text: settings.musicDir
                    }
                    Rectangle {
                        visible: Qt.platform.os !== "android"
                        Layout.fillWidth: true; Layout.preferredHeight: 36
                        color: (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)); border.width: 1
                        border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                        TextInput {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true; selectByMouse: true; font.pixelSize: 13; color: root.pri
                            text: settings.musicDir
                            onAccepted: settings.musicDir = text
                        }
                    }
                    Btn { Layout.topMargin: 6; label: "Choose folder…"; onClicked: root.chooseFolderRequested() }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; color: root.muted
                        text: library.scanning ? "Scanning…" : (Qt.platform.os === "android" ? "Tap Choose folder to pick where your music is. It is scanned right away." : "Choose a folder, or type its path and press Enter.")
                    }
                    SectionLabel { text: "ARTIST NAMES" }
                    ToggleRow {
                        label: "Split artists on , and &"
                        note: "A song by two artists appears under both"
                        checked: settings.artistSplit
                        onToggled: settings.artistSplit = !settings.artistSplit
                    }
                    Text { Layout.fillWidth: true; font.pixelSize: 12; color: root.muted; wrapMode: Text.Wrap; text: "Keep together (one name per line):" }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 110; Layout.topMargin: 4
                        color: (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)); border.width: 1
                        border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                        Flickable {
                            anchors { fill: parent; margins: 8 }
                            clip: true; contentHeight: te.paintedHeight
                            TextEdit {
                                id: te
                                width: parent.width; wrapMode: TextEdit.Wrap; selectByMouse: true
                                font.pixelSize: 12; color: root.pri
                                text: settings.artistExceptions
                                onActiveFocusChanged: if (!activeFocus) settings.artistExceptions = text
                            }
                        }
                    }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "servers"
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.4; color: root.muted
                        text: "Stream from your own Navidrome, Subsonic or Jellyfin server. Songs play as the original files, never re-encoded."
                    }
                    Repeater {
                        model: { servers.revision; return servers.list() }
                        Rectangle {
                            id: card
                            required property var modelData
                            readonly property bool asking: root.confirmId === modelData.id
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            Layout.preferredHeight: inner.implicitHeight + 24
                            color: (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6))
                            ColumnLayout {
                                id: inner
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 2
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: card.modelData.name; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.pri }
                                    Text { text: card.modelData.kind === "jellyfin" ? "Jellyfin" : "Navidrome / Subsonic"; font.pixelSize: 10; color: root.muted }
                                }
                                Text { Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 11; color: root.muted; text: card.modelData.url + " · " + card.modelData.user }
                                Text {
                                    Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12
                                    color: card.modelData.state === "error" ? "#b91c1c" : root.pri
                                    text: root.statusLine(card.modelData)
                                }
                                ToggleRow {
                                    label: "Use this server"
                                    checked: card.modelData.enabled
                                    onToggled: servers.setEnabled(card.modelData.id, !card.modelData.enabled)
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Btn { label: "Sync now"; primary: false; enabled: card.modelData.enabled && card.modelData.state !== "syncing"; onClicked: servers.syncNow(card.modelData.id) }
                                    Btn {
                                        label: card.asking ? "Yes, remove it" : "Remove"
                                        primary: false
                                        onClicked: { if (card.asking) { root.confirmId = ""; servers.removeServer(card.modelData.id) } else root.confirmId = card.modelData.id }
                                    }
                                    Btn { visible: card.asking; label: "Keep it"; primary: false; onClicked: root.confirmId = "" }
                                }
                            }
                        }
                    }
                    Btn { Layout.topMargin: 12; label: "Add a server…"; onClicked: root.addServerRequested() }
                    Text {
                        Layout.fillWidth: true; Layout.topMargin: 6; wrapMode: Text.Wrap; font.pixelSize: 10; lineHeight: 1.4; color: root.muted
                        text: "Your password itself is never saved. Navidrome/Subsonic keeps a one-way sign-in token and Jellyfin keeps an access token, in a private file only your user can read."
                    }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "audio"
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.4; color: root.muted
                        text: "FLAC · ALAC · WAV · MP3 · AAC · OGG · OPUS\nGapless playback, native sample rate"
                    }
                    ToggleRow { label: "Bit-perfect output"; note: "No ReplayGain. Volume below 100% changes the samples"; checked: settings.bitPerfect; onToggled: settings.bitPerfect = !settings.bitPerfect }
                    ToggleRow { label: "Match track sample rate"; note: "Applies on next start"; checked: settings.matchRate; onToggled: settings.matchRate = !settings.matchRate }
                    ToggleRow { label: "Show quality badges"; checked: settings.badges; onToggled: settings.badges = !settings.badges }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "customisation"
                    ToggleRow { visible: Qt.platform.os === "linux"; label: "Frosted glass"; checked: settings.frosted; onToggled: settings.frosted = !settings.frosted }
                    ToggleRow { label: "Adapt to album colours"; checked: settings.adaptive; onToggled: settings.adaptive = !settings.adaptive }
                    ToggleRow { label: "Show lyrics"; checked: settings.lyrics; onToggled: settings.lyrics = !settings.lyrics }
                    ToggleRow { label: "Look up lyrics online"; note: "For songs without lyrics of their own, sends the artist, title and length to lrclib.net. Found lyrics are kept on this device"; checked: settings.onlineLyrics; onToggled: settings.onlineLyrics = !settings.onlineLyrics }
                    ToggleRow { label: "Fetch artist pictures online"; note: "Sends artist names to Deezer"; checked: settings.onlineArtistPhotos; onToggled: settings.onlineArtistPhotos = !settings.onlineArtistPhotos }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "home"
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.4; color: root.muted
                        text: "Switch sections on or off, and use the arrows to move them up or down. Changes show straight away."
                    }
                    Repeater {
                        model: root.layout ? root.layout.listed : []
                        Rectangle {
                            id: hrow
                            required property string modelData
                            required property int index
                            readonly property bool on: root.layout.isOn(modelData)
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            Layout.preferredHeight: hline.implicitHeight + 8
                            color: settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6)
                            opacity: on ? 1 : 0.75
                            RowLayout {
                                id: hline
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 6 }
                                spacing: 2
                                ToggleRow {
                                    label: root.layout.titles[hrow.modelData]
                                    note: root.layout.notes[hrow.modelData]
                                    checked: hrow.on
                                    onToggled: root.layout.toggle(hrow.modelData)
                                }
                                IconButton { Layout.leftMargin: 8; name: "up"; box: 36; iconSize: 18; enabled: hrow.index > 0; opacity: enabled ? 1 : 0.3; onClicked: root.layout.move(hrow.modelData, -1) }
                                IconButton { name: "down"; box: 36; iconSize: 18; enabled: hrow.index < root.layout.listed.length - 1; opacity: enabled ? 1 : 0.3; onClicked: root.layout.move(hrow.modelData, 1) }
                            }
                        }
                    }
                    Text {
                        visible: !account.signedIn
                        Layout.fillWidth: true; Layout.topMargin: 6; wrapMode: Text.Wrap; font.pixelSize: 11; lineHeight: 1.4; color: root.muted
                        text: "Your friends and follow requests join this list once you sign in."
                    }
                    Btn {
                        Layout.topMargin: 12
                        label: "Reset to the default layout"
                        primary: false
                        enabled: settings.homeCustom
                        onClicked: root.layout.reset()
                    }
                    SectionLabel { text: "LISTENING HISTORY" }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.4; color: root.muted
                        text: "Your top artists come from what you play. It is counted and kept on this device only, and never uploaded. "
                              + stats.total + (stats.total === 1 ? " play" : " plays") + " counted so far."
                    }
                    Flow {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 8
                        Btn {
                            label: root.confirmForget ? "Yes, forget it" : "Forget my listening history"
                            primary: false
                            enabled: stats.total > 0
                            onClicked: { if (root.confirmForget) { stats.clear(); root.confirmForget = false } else root.confirmForget = true }
                        }
                        Btn { visible: root.confirmForget; label: "Keep it"; primary: false; onClicked: root.confirmForget = false }
                    }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "cover"
                    SectionLabel { text: "STYLE" }
                    Row {
                        Repeater {
                            model: [{ t: "Square", rec: false }, { t: "Spinning record", rec: true }]
                            Rectangle {
                                required property var modelData
                                readonly property bool sel: settings.recordCover === modelData.rec
                                width: lbl.implicitWidth + 28; height: 36
                                color: sel ? root.pri : "transparent"
                                border.width: 1
                                border.color: sel ? root.pri : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                                Text { id: lbl; anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 13; color: parent.sel ? "white" : root.pri }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.recordCover = parent.modelData.rec }
                            }
                        }
                    }
                    Text {
                        visible: settings.recordCover
                        Layout.fillWidth: true; Layout.topMargin: 6; wrapMode: Text.Wrap; font.pixelSize: 10; lineHeight: 1.4; color: root.muted
                        text: "In the full-screen player, turn the record with your finger or mouse: clockwise speeds the song up, anticlockwise slows it down. Let go and it eases back to normal."
                    }
                    SectionLabel { text: "RINGS AROUND THE COVER" }
                    RowLayout {
                        Layout.fillWidth: true
                        Slider255 { Layout.fillWidth: true; maxValue: 6; value: settings.ringCount; onMoved: (v) => settings.ringCount = v }
                        Text { Layout.preferredWidth: 20; horizontalAlignment: Text.AlignRight; text: settings.ringCount; font.pixelSize: 13; color: root.pri }
                    }
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; color: root.muted; text: "Fewer rings means a bigger cover. 0 shows the cover edge to edge." }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "theme"
                    ColorEditor { title: "Primary"; value: settings.primary; onEdited: (c) => settings.primary = c }
                    ColorEditor { title: "Accent"; value: settings.accent; onEdited: (c) => settings.accent = c }
                    ColorEditor { visible: settings.solid; title: Qt.platform.os === "linux" ? "Background (frosted glass off)" : "Background"; value: settings.bgColor; onEdited: (c) => settings.bgColor = c }
                    SectionLabel { visible: settings.solid; text: "SELECTION AND BOXES" }
                    Text {
                        visible: settings.solid
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; lineHeight: 1.4; color: root.muted
                        text: "The colour behind the song that's playing, the menu item you're on, and boxes like the profile fields. You pick the colour and how strong it is."
                    }
                    ColorEditor { visible: settings.solid; title: "Highlight colour"; value: settings.highlight; onEdited: (c) => settings.highlight = c }
                    Text { visible: settings.solid; Layout.topMargin: 8; text: "Selection strength: " + settings.highlightOpacity + "%"; font.pixelSize: 13; color: root.pri }
                    Slider255 { visible: settings.solid; Layout.fillWidth: true; maxValue: 50; value: settings.highlightOpacity; onMoved: (v) => settings.highlightOpacity = v }
                    Text { visible: settings.solid; Layout.topMargin: 8; text: "Boxes and fields strength: " + settings.boxOpacity + "%"; font.pixelSize: 13; color: root.pri }
                    Slider255 { visible: settings.solid; Layout.fillWidth: true; maxValue: 30; value: settings.boxOpacity; onMoved: (v) => settings.boxOpacity = v }
                    Rectangle {      // a live sample of the selection colour
                        visible: settings.solid
                        Layout.fillWidth: true; Layout.topMargin: 8; Layout.preferredHeight: 44
                        color: settings.hiSel
                        Rectangle { width: 3; height: parent.height; color: settings.accent }
                        Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: "Now playing looks like this"; font.pixelSize: 13; color: root.pri }
                    }
                }

                ColumnLayout {
                    width: parent.width
                    visible: root.cat === "updates"
                    SectionLabel { text: "VERSION" }
                    Text { text: (Qt.platform.os === "android" ? "Paraplay " : "Music ") + updater.current; font.pixelSize: 14; color: root.pri }
                    Text {
                        visible: updater.status !== ""
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; color: root.muted
                        text: updater.status
                    }
                    ToggleRow {
                        label: "Check for updates on start"
                        note: Qt.platform.os === "android" ? "Asks GitHub for a newer build, at most once an hour" : "Asks GitHub for the newest version, at most twice a day"
                        checked: settings.autoUpdateCheck
                        onToggled: settings.autoUpdateCheck = !settings.autoUpdateCheck
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Btn { label: updater.checking ? "Checking…" : "Check now"; primary: false; enabled: !updater.checking && !updater.installing; onClicked: updater.check(true) }
                        Btn {
                            visible: updater.available && updater.canInstall && !updater.installed
                            label: updater.installing ? "Updating…" : "Update now"
                            enabled: !updater.installing
                            onClicked: updater.install()
                        }
                        Btn { visible: updater.installed; label: "Restart"; onClicked: updater.restart() }
                        Btn { visible: updater.available && !updater.canInstall; label: "Open release page"; primary: false; onClicked: updater.openReleasePage() }
                    }
                    Text {
                        visible: updater.available && !updater.canInstall
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; lineHeight: 1.4; color: root.muted
                        text: !updater.configured ? "This build isn't linked to a release page yet."
                            : Qt.platform.os === "windows" ? "Download the new installer from the release page and run it. Your settings and library stay as they are."
                            : "To update from inside the player, install it once with ./update.sh --here from the project folder."
                    }
                    Rectangle {
                        visible: updater.installing && Qt.platform.os === "android"
                        Layout.fillWidth: true; height: 4; color: Qt.rgba(1, 1, 1, 0.12)
                        Rectangle { width: parent.width * updater.progress; height: parent.height; color: settings.accent }
                    }
                    Text {
                        visible: updater.installing && Qt.platform.os !== "android"
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 10; lineHeight: 1.4; color: root.muted
                        text: "The new version is built on this computer at low priority, so music keeps playing. This can take a few minutes."
                    }
                    SectionLabel { visible: updater.notes !== ""; text: "WHAT'S NEW" }
                    Text {
                        visible: updater.notes !== ""
                        Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.4; color: root.pri
                        text: updater.notes
                    }
                }
            }
        }
    }
}
