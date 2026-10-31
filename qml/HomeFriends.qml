import QtQuick

// The people you follow, with what they are playing. One row you can scroll, or all of them with the arrow.
Item {
    id: root
    property bool compact: false
    property bool expanded: false
    signal openUser(string username)
    readonly property int tileW: compact ? 176 : 224
    implicitHeight: col.implicitHeight

    // People who are listening now first, then whoever played something lately, then everyone else.
    readonly property var people: {
        const act = {}
        const feed = social.activity
        for (let i = 0; i < feed.length; ++i) act[feed[i].username] = { a: feed[i], at: i }
        const out = []
        for (const p of social.following) {
            if (p.state !== "accepted") continue
            const e = act[p.username]
            out.push({
                id: p.id, username: p.username, name: p.name, avatar: p.avatar,
                title: e ? e.a.title : "", artist: e ? e.a.artist : "", quality: e ? e.a.quality : "",
                live: e ? !!e.a.live : false, when: e ? e.a.when : "",
                rank: e ? (e.a.live ? 0 : 1) : 2, at: e ? e.at : 0 })
        }
        out.sort(function(x, y) { return x.rank !== y.rank ? x.rank - y.rank : x.at - y.at })
        return out
    }

    Column {
        id: col
        width: parent.width
        HomeHeading {
            width: parent.width
            text: "YOUR FRIENDS" + (root.people.length > 0 ? " · " + root.people.length : "")
            arrow: root.people.length * (root.tileW + 12) - 12 > root.width
            arrowOpen: root.expanded
            onActivated: root.expanded = !root.expanded
        }
        ListView {
            visible: !root.expanded && root.people.length > 0
            width: parent.width
            height: 142
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.people
            delegate: HomePerson {
                required property var modelData
                person: modelData
                compact: root.compact
                onOpened: root.openUser(modelData.username)
            }
        }
        Flow {
            visible: root.expanded && root.people.length > 0
            width: parent.width
            spacing: 12
            Repeater {
                model: root.expanded ? root.people : []
                HomePerson {
                    required property var modelData
                    person: modelData
                    compact: root.compact
                    onOpened: root.openUser(modelData.username)
                }
            }
        }
        Text {
            visible: root.people.length === 0
            width: parent.width
            wrapMode: Text.Wrap
            lineHeight: 1.35
            font.pixelSize: 12
            color: Qt.rgba(settings.primary.r, settings.primary.g, settings.primary.b, 0.72)
            text: "You aren't following anyone yet. Tap the person with a plus at the top right to find people."
        }
    }
}
