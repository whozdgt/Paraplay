import QtQuick

// Someone's profile, exactly as the database lets this viewer see it. Also used for "Preview" of your own.
Flickable {
    id: root
    readonly property int gut: width < 600 ? 16 : 36      // side margin; smaller on a phone
    signal openPlaylist(string pid, string name, string owner)

    readonly property var p: social.profile
    readonly property bool ready: !!p.id && p.loading !== true && p.missing !== true
    readonly property bool anyCount: p.followers >= 0 || p.following >= 0 || p.playlistCount >= 0
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool compact: col.width < 560      // phone: buttons go under the name instead of beside it
    property string menu: ""              // "" | "main" | "report"
    property bool confirmBlock: false

    contentWidth: width
    contentHeight: col.implicitHeight + 40
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onVisibleChanged: if (visible) contentY = 0
    onMenuChanged: confirmBlock = false

    function pick(k) {
        if (k === "block") {
            if (confirmBlock) { social.block(p.id); confirmBlock = false; menu = "" }
            else confirmBlock = true
        } else if (k === "report") {
            menu = "report"
        } else {
            social.report(p.id, k)
            menu = ""
        }
    }

    MouseArea { z: 3; width: root.contentWidth; height: root.contentHeight; visible: root.menu !== ""; onClicked: root.menu = "" }

    Column {
        id: col
        z: 4          // above the click-away area, so the menu and cards still get their clicks
        x: root.gut
        width: Math.min(720, root.width - 2 * root.gut)

        Text {
            visible: root.p.loading === true
            text: "Loading…"
            font.pixelSize: 14; color: root.muted
        }
        Text {
            visible: root.p.missing === true
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 14; color: root.muted
            text: "That profile isn't available. It may not exist, or one of you has blocked the other."
        }

        Column {
            visible: root.ready
            width: parent.width

            Rectangle {   // banner
                width: parent.width; height: 130
                clip: true
                color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.07)
                Image {
                    anchors.fill: parent
                    visible: !!root.p.banner && root.p.animated !== true
                    source: visible ? root.p.banner : ""
                    cache: false
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1120
                }
                AnimatedImage {
                    anchors.fill: parent
                    visible: !!root.p.banner && root.p.animated === true
                    source: visible ? root.p.banner : ""
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    playing: visible && Window.active
                }
            }

            Item {   // picture, name and buttons
                id: head
                z: 5
                width: parent.width
                height: root.compact && root.p.self !== true ? 96 + 44 : 96

                Rectangle {
                    id: frame
                    y: -34
                    width: 84; height: 84
                    color: "white"
                    Avatar { anchors.fill: parent; anchors.margins: 4; source: root.p.avatar || "" }
                }
                Column {
                    x: 100; y: 8
                    width: root.compact ? parent.width - 100 : parent.width - 100 - actionsRow.width - 12
                    Text {
                        width: parent.width
                        text: root.p.name || ""
                        elide: Text.ElideRight
                        font.pixelSize: 22; font.weight: Font.DemiBold; color: root.pri
                    }
                    Flow {
                        width: parent.width
                        spacing: 8
                        Text { height: 18; verticalAlignment: Text.AlignVCenter; text: "@" + (root.p.username || ""); font.pixelSize: 13; color: root.muted }
                        Rectangle {
                            readonly property bool pub: root.p.visibility === "public"
                            width: tag.implicitWidth + 12; height: 18
                            color: pub ? root.pri : "transparent"
                            border.width: pub ? 0 : 1
                            border.color: root.pri
                            Text { id: tag; anchors.centerIn: parent; text: parent.pub ? "PUBLIC" : "PRIVATE"; font.pixelSize: 10; color: parent.pub ? "white" : root.pri }
                        }
                    }
                }
                Row {
                    id: actionsRow
                    visible: root.p.self !== true
                    anchors.left: root.compact ? parent.left : undefined
                    anchors.right: root.compact ? undefined : parent.right
                    anchors.top: parent.top
                    anchors.topMargin: root.compact ? 100 : 8
                    spacing: 8
                    opacity: root.p.preview === true ? 0.5 : 1
                    FollowButton { person: root.p; enabled: root.p.preview !== true }
                    Btn { label: "..."; primary: false; width: 44; height: 32; enabled: root.p.preview !== true; onClicked: root.menu = root.menu === "" ? "main" : "" }
                }
                Rectangle {   // the "..." menu: block, report
                    visible: root.menu !== ""
                    anchors { right: parent.right; top: actionsRow.bottom; topMargin: 6 }
                    width: 250
                    height: menuCol.implicitHeight
                    color: Qt.rgba(1, 1, 1, 0.97)
                    Column {
                        id: menuCol
                        width: parent.width
                        Text {
                            visible: root.menu === "report"
                            leftPadding: 14; topPadding: 12; bottomPadding: 6
                            text: "WHAT'S WRONG?"
                            font.pixelSize: 11; font.letterSpacing: 1; color: root.muted
                        }
                        Repeater {
                            model: root.menu === "main"
                                ? [{ k: "block", t: root.confirmBlock ? "Tap again to block" : "Block" }, { k: "report", t: "Report…" }]
                                : root.menu === "report"
                                ? [{ k: "Spam or a fake account", t: "Spam or a fake account" }, { k: "Harassment", t: "Harassment" },
                                   { k: "Inappropriate picture or text", t: "Inappropriate picture or text" }, { k: "Something else", t: "Something else" }]
                                : []
                            Rectangle {
                                required property var modelData
                                width: menuCol.width; height: 40
                                color: mma.containsMouse ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                                Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter } text: parent.modelData.t; font.pixelSize: 13; color: root.pri }
                                MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pick(parent.modelData.k) }
                            }
                        }
                    }
                }
            }

            Text {   // bio
                visible: root.p.locked !== true && (root.p.bio || "") !== ""
                width: parent.width
                topPadding: 4
                wrapMode: Text.Wrap
                lineHeight: 1.35
                text: root.p.bio || ""
                font.pixelSize: 13; color: root.pri
            }
            Row {   // counts
                visible: root.p.locked !== true && root.anyCount
                topPadding: 12
                spacing: 24
                Text { visible: root.p.followers >= 0; textFormat: Text.StyledText; text: "<b>" + root.p.followers + "</b> followers"; font.pixelSize: 12; color: root.pri }
                Text { visible: root.p.following >= 0; textFormat: Text.StyledText; text: "<b>" + root.p.following + "</b> following"; font.pixelSize: 12; color: root.pri }
                Text { visible: root.p.playlistCount >= 0; textFormat: Text.StyledText; text: "<b>" + root.p.playlistCount + "</b> shared playlists"; font.pixelSize: 12; color: root.pri }
            }
            Text {
                visible: root.p.locked === true || !root.anyCount
                topPadding: 12
                text: "Counts hidden"
                font.pixelSize: 12; color: root.muted
            }

            Rectangle {   // a private profile that you may not see yet
                visible: root.p.locked === true
                width: parent.width
                height: lockCol.implicitHeight + 56
                color: (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.6))
                Column {
                    id: lockCol
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 10
                    Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "This profile is private"; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.pri }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        lineHeight: 1.4
                        font.pixelSize: 12; color: root.muted
                        text: root.p.preview === true
                            ? "This is what people see while your profile is Private: your name, @username and picture. Your bio, banner, playlists and listening stay hidden until you accept someone's request."
                            : (root.p.name || "They") + "'s bio, playlists and what they're listening to are hidden. If they accept your request, you'll see what they share."
                    }
                }
            }

            SectionLabel { visible: root.p.locked !== true && social.playlists.length > 0; text: "PLAYLISTS" }
            Flow {
                visible: root.p.locked !== true && social.playlists.length > 0
                width: parent.width
                spacing: 14
                Repeater {
                    model: social.playlists
                    Item {
                        required property var modelData
                        width: 96; height: 96 + 40
                        Rectangle { width: 96; height: 96; color: Qt.hsla(parent.modelData.hue / 360, 0.38, 0.5, 1) }
                        Text { y: 100; width: 96; text: parent.modelData.name; elide: Text.ElideRight; font.pixelSize: 12; color: root.pri }
                        Text { y: 118; width: 96; text: parent.modelData.sub; elide: Text.ElideRight; font.pixelSize: 10; color: root.muted }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.p.preview !== true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPlaylist(parent.modelData.id, parent.modelData.name, root.p.username)
                        }
                    }
                }
            }

            SectionLabel { visible: !!social.listening.title; text: "LISTENING NOW" }
            Row {
                visible: !!social.listening.title
                spacing: 10
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; color: settings.accent }
                Column {
                    Text { text: social.listening.title || ""; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.pri }
                    Text { text: (social.listening.artist || "") + ((social.listening.quality || "") !== "" ? " · " + social.listening.quality : ""); font.pixelSize: 11; color: root.muted }
                }
            }
        }
    }
}
