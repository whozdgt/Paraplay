import QtQuick
import QtQuick.Layouts

// Settings: five sections (Library, Sound, Look, Home, About) and a search box.
// On a computer the sections are listed down the left. On a phone you first see the list, then open one (Back returns to the list).
Rectangle {
    id: root
    signal close()
    signal addServerRequested()
    signal chooseFolderRequested()
    property string cat: "look"            // the section you picked
    property string shownCat: "look"       // the one on screen (it changes halfway through the fade)
    property bool shownList: false         // same for "the list of sections" on a phone
    property bool pageOpen: false          // phone: a section is open, rather than the list
    property var layout                    // HomeLayout: what the Home page shows
    property bool confirmForget: false     // "Forget my listening history" is waiting for a second press
    property string confirmId: ""          // server whose Remove button is waiting for a second press
    readonly property bool compact: width < 500        // a phone: one column. The computer's panel is 540 wide, so it keeps the list on the left
    readonly property bool searching: String(settings.settingsQuery).trim() !== ""
    readonly property bool showList: compact && !pageOpen && !searching
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property bool touch: Qt.platform.os === "android"
    readonly property var cats: [
        { k: "library", t: "Library", icon: "folder" },
        { k: "sound", t: "Sound", icon: "wave" },
        { k: "look", t: "Look", icon: "eye" },
        { k: "home", t: "Home", icon: "home" },
        { k: "about", t: "About", icon: "info" }]
    readonly property string headTitle: searching ? "Search results"
        : (showList ? "Settings" : titleOf(cat))

    function titleOf(k) { for (const c of cats) if (c.k === k) return c.t; return "" }
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
    // the second line under each section on a phone
    function summary(k) {
        if (k === "library") {
            const n = servers.count
            return "Music folder" + (n > 0 ? " · " + n + (n === 1 ? " server" : " servers") : "")
        }
        if (k === "sound") return "Bit-perfect " + (settings.bitPerfect ? "on" : "off") + " · quality badges " + (settings.badges ? "on" : "off")
        if (k === "look") return "Size, colours, lyrics, cover art"
        if (k === "home") {
            const l = layout ? layout.listed : []
            let on = 0
            for (const s of l) if (layout.isOn(s)) on++
            return on + " of " + l.length + " sections shown"
        }
        return (Qt.platform.os === "android" ? "Paraplay " : "Music ") + updater.current + " · updates " + (settings.autoUpdateCheck ? "on start" : "off")
    }

    // Open a section from outside (the "Update available" chip in the menu).
    function show(k) {
        settings.settingsQuery = ""
        cat = k
        shownCat = k
        pageOpen = true
    }
    // Pick a section.
    function go(k) {
        settings.settingsQuery = ""
        cat = k
        pageOpen = true
    }
    // Back: clear the search, or return from a section to the list. False means there was nothing to go back from.
    function goBack() {
        if (searching) { settings.settingsQuery = ""; return true }
        if (compact && pageOpen) { pageOpen = false; return true }
        return false
    }

    onCatChanged: fade.restart()
    onShowListChanged: fade.restart()
    onVisibleChanged: {
        if (visible) return
        settings.settingsQuery = ""
        confirmForget = false
        confirmId = ""
        pageOpen = false
    }
    Component.onCompleted: { shownCat = cat; shownList = showList }

    color: compact ? settings.bgColor : Qt.rgba(1, 1, 1, 0.85)
    MouseArea { anchors.fill: parent }   // clicks inside must not reach the close-overlay

    // ---- computer: the sections down the left
    Column {
        id: nav
        visible: !root.compact
        width: 160
        height: parent.height
        topPadding: 20
        Text { text: "Settings"; font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri; leftPadding: 14; bottomPadding: 14 }
        Repeater {
            model: root.cats
            SetNavItem {
                required property var modelData
                width: nav.width
                text: modelData.t
                icon: modelData.icon
                active: root.cat === modelData.k && !root.searching
                onClicked: root.go(modelData.k)
            }
        }
    }
    Rectangle { visible: !root.compact; x: nav.width; width: 1; height: parent.height; color: Qt.rgba(0, 0, 0, 0.08) }

    Item {
        id: area
        anchors {
            left: root.compact ? parent.left : nav.right; leftMargin: root.compact ? 0 : 1
            right: parent.right; top: parent.top; bottom: parent.bottom
        }

        // ---- title, back arrow and close button
        Item {
            id: head
            width: parent.width
            height: root.compact ? 60 : 56
            IconButton {
                id: backBtn
                visible: root.compact && !root.showList
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                name: "back"; box: root.touch ? 44 : 40; iconSize: 20
                onClicked: root.goBack()
            }
            Text {
                anchors {
                    left: backBtn.visible ? backBtn.right : parent.left; leftMargin: backBtn.visible ? 4 : 20
                    right: closeBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter
                }
                text: root.headTitle
                elide: Text.ElideRight
                font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri
            }
            IconButton {
                id: closeBtn
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                name: "close"; box: root.touch ? 44 : 40; iconSize: 18
                onClicked: root.close()
            }
        }

        SetSearch {
            id: search
            visible: !root.compact || root.showList || root.searching
            anchors { left: parent.left; leftMargin: 20; right: parent.right; rightMargin: 20; top: head.bottom; topMargin: 2 }
        }

        // ---- phone: the list of sections
        Column {
            id: list
            visible: root.shownList
            anchors { left: parent.left; right: parent.right; top: search.bottom; topMargin: 12 }
            Repeater {
                model: root.cats
                Rectangle {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 68
                    color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, rma.pressed ? 0.10 : (rma.containsMouse ? 0.06 : 0))
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Accessible.role: Accessible.Button
                    Accessible.name: row.modelData.t
                    Accessible.onPressAction: root.go(row.modelData.k)
                    Icon { x: 20; anchors.verticalCenter: parent.verticalCenter; name: row.modelData.icon; size: 24; color: root.pri }
                    Column {
                        anchors { left: parent.left; leftMargin: 64; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Text { width: parent.width; text: row.modelData.t; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.pri }
                        Text { width: parent.width; text: root.summary(row.modelData.k); elide: Text.ElideRight; font.pixelSize: 12; color: root.muted }
                    }
                    Icon { id: chev; anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }; name: "chevron"; size: 18; color: root.pri }
                    Rectangle { anchors { left: parent.left; leftMargin: 64; right: parent.right; bottom: parent.bottom }; height: 1; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.08) }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.go(row.modelData.k) }
                }
            }
        }

        // ---- the section itself (or the search results)
        Flickable {
            id: flick
            visible: !root.shownList
            anchors { left: parent.left; right: parent.right; top: search.visible ? search.bottom : head.bottom; bottom: parent.bottom; topMargin: 8 }
            contentWidth: width
            contentHeight: pagesHost.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: pagesHost
                width: flick.width
                height: Math.max(pages.implicitHeight, 40) + 40
                transform: Translate { id: shift }

                Text {
                    visible: root.searching && pages.implicitHeight < 2
                    x: 20; y: 16
                    width: parent.width - 40
                    wrapMode: Text.Wrap
                    text: "No settings match that search."
                    font.pixelSize: 14
                    color: root.muted
                }

                ColumnLayout {
                    id: pages
                    x: 20; y: 8
                    width: parent.width - 40
                    spacing: 0
                    SetLibrary { Layout.fillWidth: true; panel: root; visible: root.searching || root.shownCat === "library" }
                    SetSound { Layout.fillWidth: true; visible: root.searching || root.shownCat === "sound" }
                    SetLook { Layout.fillWidth: true; visible: root.searching || root.shownCat === "look" }
                    SetHome { Layout.fillWidth: true; panel: root; visible: root.searching || root.shownCat === "home" }
                    SetAbout { Layout.fillWidth: true; visible: root.searching || root.shownCat === "about" }
                }
            }
        }
    }

    // Sections change with a short fade: the old one out quickly, the new one in a little slower, rising into place.
    SequentialAnimation {
        id: fade
        ParallelAnimation {
            NumberAnimation { target: pagesHost; property: "opacity"; to: 0; duration: 100 }
            NumberAnimation { target: list; property: "opacity"; to: 0; duration: 100 }
        }
        ScriptAction { script: { root.shownCat = root.cat; root.shownList = root.showList; flick.contentY = 0 } }
        ParallelAnimation {
            NumberAnimation { target: pagesHost; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: list; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: shift; property: "y"; from: 6; to: 0; duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
