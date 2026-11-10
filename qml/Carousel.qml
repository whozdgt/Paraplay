import QtQuick

// iPod-style Cover Flow for albums, artists and playlists.
Item {
    id: root
    property string kind: "album"          // album | artist | playlist
    property bool searching: false         // true = the covers stack up behind the front one
    property bool phone: false             // smaller cover, and no photo editing (it needs a file path typed in)
    property bool active: true             // false = hold nothing in memory (a phone shows a grid instead)
    property string editName: ""           // artist whose photo is being changed
    // While searching, a chosen result is shown on its own (two plain frosted layers behind it) and the
    // carousel behind it is unloaded, so nothing has to scroll past hundreds of covers.
    property var stackItem: null
    property bool jump: false              // true for a moment while fanning back out: no slide, just place it
    signal picked(string key, string name)
    clip: true
    readonly property color pri: settings.ink
    readonly property bool stacked: stackItem !== null
    readonly property var items: {
        if (!active) return []
        if (kind === "playlist") { playlists.revision; return playlists.list() }
        library.revision
        return library.groups(kind)
    }
    readonly property real cover: phone ? Math.max(100, Math.min(height - 100, width * 0.56))
                                        : Math.max(120, Math.min(height - 110, width * 0.3))
    readonly property var cur: stacked ? stackItem
        : (flow.count > 0 && flow.currentIndex >= 0 && flow.currentIndex < items.length ? items[flow.currentIndex] : null)
    property real spread: searching ? 0.05 : 1
    Behavior on spread { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
    onSearchingChanged: if (!searching) unstack()

    // A search result was chosen: while searching it goes to the front of the stack, otherwise the carousel slides to it.
    function focusKey(key) {
        for (let i = 0; i < items.length; ++i) {
            if (items[i].key !== key) continue
            if (searching) stackItem = items[i]
            else flow.currentIndex = i
            return
        }
    }
    // Search closed: bring the carousel back with the chosen cover in the middle.
    function unstack() {
        if (!stacked) return
        let idx = 0
        for (let i = 0; i < items.length; ++i) if (items[i].key === stackItem.key) { idx = i; break }
        jump = true
        stackItem = null
        flow.currentIndex = idx
        Qt.callLater(function() { flow.currentIndex = idx; root.jump = false })
    }

    PathView {
        id: flow
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: info.top }
        model: root.stacked ? 0 : root.items
        pathItemCount: 7
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        highlightMoveDuration: root.jump ? 0 : 300
        snapMode: PathView.SnapOneItem
        focus: true
        onVisibleChanged: if (visible) forceActiveFocus()
        Keys.onLeftPressed: decrementCurrentIndex()
        Keys.onRightPressed: incrementCurrentIndex()
        WheelHandler {
            onWheel: (e) => { if (e.angleDelta.y > 0 || e.angleDelta.x > 0) flow.decrementCurrentIndex(); else flow.incrementCurrentIndex() }
        }

        path: Path {
            startX: flow.width * 0.5 * (1 - root.spread); startY: flow.height / 2
            PathAttribute { name: "depth"; value: 0 }
            PathAttribute { name: "angle"; value: 65 * root.spread + 8 * (1 - root.spread) }
            PathAttribute { name: "scl"; value: 0.7 }
            PathLine { x: flow.width * 0.5; y: flow.height / 2 }
            PathAttribute { name: "depth"; value: 10 }
            PathAttribute { name: "angle"; value: 0 }
            PathAttribute { name: "scl"; value: 1 }
            PathLine { x: flow.width * (0.5 + 0.5 * root.spread); y: flow.height / 2 }
            PathAttribute { name: "depth"; value: 0 }
            PathAttribute { name: "angle"; value: -65 * root.spread - 8 * (1 - root.spread) }
            PathAttribute { name: "scl"; value: 0.7 }
        }

        delegate: Item {
            id: d
            required property int index
            required property var modelData
            readonly property bool isCur: PathView.isCurrentItem
            width: root.cover
            height: root.cover
            z: PathView.depth
            scale: PathView.scl
            opacity: isCur ? 1 : 0.85
            transform: Rotation {
                origin.x: d.width / 2
                origin.y: d.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: d.PathView.angle
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!d.isCur) flow.currentIndex = d.index
                    else root.picked(d.modelData.key, d.modelData.name)
                }
            }
            CoverTile { anchors.fill: parent; entry: d.modelData; kind: root.kind }
            Rectangle {
                visible: root.kind === "artist" && d.isCur && !root.searching && !root.phone
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                color: Qt.rgba(0, 0, 0, 0.65)
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: "camera"; size: 16; color: "white" }
                    Text { text: "Change photo"; color: "white"; font.pixelSize: 12 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editName = d.modelData.name }
            }
        }
    }

    // The chosen search result on its own, two plain frosted layers behind it.
    Item {
        visible: root.stacked
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: info.top }
        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -34
            width: root.cover; height: root.cover
            rotation: -4
            color: Qt.rgba(1, 1, 1, 0.34)
        }
        Rectangle {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 34
            width: root.cover; height: root.cover
            rotation: 4
            color: Qt.rgba(1, 1, 1, 0.34)
        }
        CoverTile {
            anchors.centerIn: parent
            width: root.cover; height: root.cover
            entry: root.stackItem
            kind: root.kind
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.stackItem) root.picked(root.stackItem.key, root.stackItem.name)
            }
        }
    }

    Column {
        id: info
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
        width: root.width - (root.phone ? 32 : 80)
        spacing: 4
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: root.cur ? root.cur.name : ""
            font.pixelSize: 18; font.weight: Font.DemiBold; color: root.pri
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: root.cur ? root.cur.sub : ""
            font.pixelSize: 14; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
        }
    }

    Text {
        anchors.centerIn: parent
        visible: flow.count === 0 && !root.stacked
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.4
        color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72)
        text: library.scanning ? "Scanning your music…"
            : root.kind === "playlist" ? "No playlists yet.\nPress “New playlist” above to make one."
            : "Nothing here yet."
    }

    // Change an artist's photo: drop an image file on this box, or paste its path.
    Rectangle {
        visible: root.editName !== ""
        z: 50
        anchors.centerIn: parent
        width: Math.min(420, root.width - 24)
        height: 250
        color: settings.surface; radius: settings.round ? 18 : 0
        MouseArea { anchors.fill: parent }
        DropArea {
            anchors.fill: parent
            onDropped: (e) => { if (e.hasUrls) { artistImages.setCustom(root.editName, e.urls[0]); root.editName = "" } }
        }
        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 12
            Text { width: parent.width; elide: Text.ElideRight; text: "Photo for " + root.editName; font.pixelSize: 16; font.weight: Font.DemiBold; color: root.pri }
            Text { width: parent.width; wrapMode: Text.Wrap; font.pixelSize: 12; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.72); text: "Drop an image file onto this box, or paste its path here." }
            Rectangle {
                width: parent.width; height: 38
                color: settings.field; radius: settings.round ? 10 : 0; border.width: 1; border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.3)
                TextInput {
                    id: pathIn
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    verticalAlignment: TextInput.AlignVCenter; clip: true; selectByMouse: true; font.pixelSize: 13; color: root.pri
                    onAccepted: { artistImages.setCustom(root.editName, text); text = ""; root.editName = "" }
                }
            }
            Row {
                spacing: 8
                Rectangle {
                    width: 90; height: 38; color: root.pri
                    Text { anchors.centerIn: parent; text: "Apply"; color: settings.onInk; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { artistImages.setCustom(root.editName, pathIn.text); pathIn.text = ""; root.editName = "" } }
                }
                Rectangle {
                    width: 150; height: 38; color: "transparent"; border.width: 1; border.color: root.pri
                    Text { anchors.centerIn: parent; text: "Use online photo"; color: root.pri; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { artistImages.clearCustom(root.editName); root.editName = "" } }
                }
                Rectangle {
                    width: 80; height: 38; color: "transparent"; border.width: 1; border.color: root.pri
                    Text { anchors.centerIn: parent; text: "Close"; color: root.pri; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.editName = "" }
                }
            }
        }
    }
}
