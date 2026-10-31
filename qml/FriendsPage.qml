import QtQuick
import QtQuick.Layouts

// The Friends hub: what people you follow are playing, finding people, and follow requests.
Item {
    id: root
    readonly property int gut: width < 600 ? 16 : 36      // side margin; smaller on a phone
    signal signInRequested()
    signal openUser(string username)
    signal openPlaylist(string pid, string name, string owner)

    property string tab: "activity"          // activity | find | requests
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool signedIn: account.signedIn

    function focusSearch() { if (typeof searchBox !== "undefined") searchBox.focusInput() }

    onVisibleChanged: social.watch(visible && signedIn)
    onSignedInChanged: social.watch(visible && signedIn)

    // ---- signed out ----
    Column {
        visible: !root.signedIn
        x: root.gut
        width: Math.min(480, root.width - 2 * root.gut)
        spacing: 14
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: 14
            lineHeight: 1.3
            color: root.pri
            text: "Sign in to find people, follow friends and share playlists. Friends only ever see song names, never your files."
        }
        Btn { label: "Sign in or create an account"; onClicked: root.signInRequested() }
    }

    // ---- signed in ----
    Item {
        id: body
        visible: root.signedIn
        x: root.gut
        width: root.width - 2 * root.gut
        height: root.height

        Row {
            id: tabs
            width: Math.min(520, body.width)
            Repeater {
                model: [{ k: "activity", t: "Activity" }, { k: "find", t: "Find people" },
                        { k: "requests", t: "Requests" + (social.requestCount > 0 ? " · " + social.requestCount : "") }]
                Item {
                    required property var modelData
                    readonly property bool on: root.tab === modelData.k
                    width: tabs.width / 3
                    height: 38
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.t
                        font.pixelSize: 13
                        font.weight: parent.on ? Font.DemiBold : Font.Normal
                        color: root.pri
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: parent.on ? 3 : 1
                        color: parent.on ? settings.accent : Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.18)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.tab = parent.modelData.k; if (root.tab === "find") Qt.callLater(searchBox.focusInput) }
                    }
                }
            }
        }

        Item {
            id: pane
            y: tabs.height + 14
            width: body.width
            height: body.height - y

            // ---------------- Activity ----------------
            TwoColumns {
                anchors.fill: parent
                visible: root.tab === "activity"
                leftWidth: 520

                SectionLabel { width: parent.width; topPadding: 6; text: "LISTENING NOW" }
                Repeater {
                    id: liveRep
                    model: social.activity.filter(function(a) { return a.live })
                    PersonRow {
                        required property var modelData
                        width: parent.width
                        person: modelData
                        sub: modelData.title + " · " + modelData.artist
                        onOpened: root.openUser(modelData.username)
                        Chip { visible: modelData.quality !== ""; text: modelData.quality; accent: true }
                        Item { width: 9; height: 22; Rectangle { anchors.centerIn: parent; width: 9; height: 9; color: settings.accent } }
                    }
                }
                SectionLabel { width: parent.width; visible: earlierRep.count > 0; text: "EARLIER" }
                Repeater {
                    id: earlierRep
                    model: social.activity.filter(function(a) { return !a.live })
                    PersonRow {
                        required property var modelData
                        width: parent.width
                        opacity: 0.85
                        person: modelData
                        sub: "Last played · " + modelData.title + " · " + modelData.artist
                        onOpened: root.openUser(modelData.username)
                        Text { text: modelData.when; font.pixelSize: 11; color: root.muted }
                    }
                }
                Text {
                    width: parent.width
                    visible: liveRep.count === 0 && earlierRep.count === 0
                    topPadding: 8
                    wrapMode: Text.Wrap
                    lineHeight: 1.35
                    font.pixelSize: 12
                    color: root.muted
                    text: social.following.length === 0
                        ? "You aren't following anyone yet. Use Find people to follow someone."
                        : "Nobody you follow is sharing what they listen to right now. They appear here when they switch on “Show what I'm listening to”."
                }

                rightItems: [
                    SectionLabel { width: parent.width; topPadding: 6; text: "SHARED PLAYLISTS" },
                    Repeater {
                        id: plRep
                        model: social.friendPlaylists
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 52
                            color: pma.containsMouse ? (settings.solid ? settings.boxHover : Qt.rgba(1, 1, 1, 0.55)) : (settings.solid ? settings.boxFill : Qt.rgba(1, 1, 1, 0.35))
                            Rectangle {
                                id: sq
                                x: 12
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32
                                color: Qt.hsla(parent.modelData.hue / 360, 0.38, 0.5, 1)
                            }
                            Column {
                                anchors { left: sq.right; leftMargin: 12; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                Text { width: parent.width; text: parent.parent.modelData.name; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.pri }
                                Text { width: parent.width; text: parent.parent.modelData.ownerName + " · " + parent.parent.modelData.sub; elide: Text.ElideRight; font.pixelSize: 11; color: root.muted }
                            }
                            MouseArea {
                                id: pma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openPlaylist(parent.modelData.id, parent.modelData.name, parent.modelData.owner)
                            }
                        }
                    },
                    Text {
                        width: parent.width
                        visible: plRep.count === 0
                        topPadding: 8
                        wrapMode: Text.Wrap
                        lineHeight: 1.35
                        font.pixelSize: 12
                        color: root.muted
                        text: "Playlists the people you follow choose to share show up here."
                    }
                ]
            }

            // ---------------- Find people ----------------
            Item {
                anchors.fill: parent
                visible: root.tab === "find"

                Field {
                    id: searchBox
                    width: Math.min(560, parent.width)
                    placeholder: "Search by name or @username"
                    onTextChanged: debounce.restart()
                    onAccepted: social.search(text)
                }
                Timer { id: debounce; interval: 300; onTriggered: social.search(searchBox.text) }

                Flickable {
                    anchors { left: parent.left; right: parent.right; top: searchBox.bottom; topMargin: 12; bottom: parent.bottom }
                    contentWidth: width
                    contentHeight: found.implicitHeight + 24
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: found
                        width: Math.min(560, parent.width)
                        spacing: 6
                        Repeater {
                            model: social.results
                            PersonRow {
                                required property var modelData
                                width: parent.width
                                person: modelData
                                sub: "@" + modelData.username + (modelData.visibility === "public" ? "" : " · Private profile")
                                onOpened: root.openUser(modelData.username)
                                FollowButton { person: modelData }
                            }
                        }
                        Text {
                            width: parent.width
                            topPadding: 6
                            wrapMode: Text.Wrap
                            lineHeight: 1.35
                            font.pixelSize: 11
                            color: root.muted
                            text: searchBox.text.trim().length < 2 ? "Type at least 2 letters. Only people who turned on “Appear in search” are listed."
                                : social.searching ? "Searching…"
                                : social.results.length === 0 ? "No one found. They may have turned off “Appear in search”."
                                : "Only people who turned on “Appear in search” are listed. Tap a name to preview their profile."
                        }
                    }
                }
            }

            // ---------------- Requests, following, blocked ----------------
            TwoColumns {
                anchors.fill: parent
                visible: root.tab === "requests"
                leftWidth: 420

                SectionLabel { width: parent.width; topPadding: 6; text: "WANT TO FOLLOW YOU" }
                Repeater {
                    id: reqRep
                    model: social.requests
                    PersonRow {
                        required property var modelData
                        width: parent.width
                        person: modelData
                        sub: "@" + modelData.username
                        onOpened: root.openUser(modelData.username)
                        Btn { label: "Accept"; height: 32; onClicked: social.respond(modelData.id, true) }
                        Btn { label: "Decline"; primary: false; height: 32; onClicked: social.respond(modelData.id, false) }
                    }
                }
                Text {
                    width: parent.width
                    topPadding: 8
                    wrapMode: Text.Wrap
                    lineHeight: 1.35
                    font.pixelSize: 11
                    color: root.muted
                    text: reqRep.count === 0
                        ? "No requests right now. Requests only appear while your profile is Private; on a Public profile people follow you straight away."
                        : "Shown while your profile is Private. Accepting lets them see your bio, shared playlists and listening."
                }

                rightItems: [
                    SectionLabel { width: parent.width; topPadding: 6; text: "FOLLOWING · " + social.following.length },
                    Repeater {
                        model: social.following
                        PersonRow {
                            required property var modelData
                            width: parent.width
                            small: true
                            person: modelData
                            sub: modelData.state === "requested" ? "Request sent" : ""
                            onOpened: root.openUser(modelData.username)
                            Btn { label: modelData.state === "requested" ? "Cancel" : "Unfollow"; primary: false; height: 32; onClicked: social.unfollow(modelData.id) }
                        }
                    },
                    SectionLabel { width: parent.width; visible: social.blocked.length > 0; text: "BLOCKED" },
                    Repeater {
                        model: social.blocked
                        PersonRow {
                            required property var modelData
                            width: parent.width
                            small: true
                            person: modelData
                            sub: "@" + modelData.username
                            Btn { label: "Unblock"; primary: false; height: 32; onClicked: social.unblock(modelData.id) }
                        }
                    }
                ]
            }
        }

        Rectangle {
            visible: social.message !== ""
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 6 }
            width: msg.implicitWidth + 28
            height: 34
            color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.92)
            Text { id: msg; anchors.centerIn: parent; text: social.message; font.pixelSize: 12; color: "white" }
        }
    }
}
