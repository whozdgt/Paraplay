import QtQuick

// Which sections the Home page shows and in what order.
// Until the person changes something the built-in layout is used (one for guests, one for people with an account).
// The first change in Settings saves the whole layout, so it stays exactly as they left it.
QtObject {
    id: root

    readonly property var keys: ["friends", "requests", "top", "playlists", "albums", "songs"]
    readonly property var titles: ({
        friends: "Your friends", requests: "Follow requests", top: "Your top artists",
        playlists: "Playlists", albums: "Albums", songs: "Songs" })
    readonly property var notes: ({
        friends: "What the people you follow are playing", requests: "People asking to follow you",
        top: "Counted on this device, never uploaded",
        playlists: "Your playlists", albums: "Your albums", songs: "A short list of songs" })
    readonly property bool signedIn: account.signedIn
    readonly property bool custom: settings.homeCustom

    // sections that only make sense with an account
    function needsAccount(k) { return k === "friends" || k === "requests" }
    function available(k) { return !needsAccount(k) || signedIn }

    readonly property var order: {
        if (!custom) return keys
        const out = []
        for (const k of String(settings.homeOrder).split(","))
            if (keys.indexOf(k) >= 0 && out.indexOf(k) < 0) out.push(k)
        for (const k of keys)
            if (out.indexOf(k) < 0) out.push(k)
        return out
    }
    readonly property var off: custom ? String(settings.homeOff).split(",")
                                      : (signedIn ? ["playlists", "albums", "songs"] : ["top"])

    // what Settings lists: everything this person can use
    readonly property var listed: order.filter(function(k) { return root.available(k) })
    // what the Home page draws, top to bottom
    readonly property var shown: listed.filter(function(k) { return root.off.indexOf(k) < 0 })

    function isOn(k) { return off.indexOf(k) < 0 }

    function commit(newOrder, newOff) {
        settings.homeOrder = newOrder.join(",")
        settings.homeOff = newOff.join(",")
        settings.homeCustom = true
    }
    function toggle(k) {
        const o = off.slice()
        const i = o.indexOf(k)
        if (i >= 0) o.splice(i, 1); else o.push(k)
        commit(order, o)
    }
    // d = -1 moves it up, +1 down (past the sections this person can't see, too)
    function move(k, d) {
        const i = listed.indexOf(k)
        const j = i + d
        if (i < 0 || j < 0 || j >= listed.length) return
        const o = order.slice()
        const a = o.indexOf(k)
        const b = o.indexOf(listed[j])
        o[a] = listed[j]
        o[b] = k
        commit(o, off)
    }
    function reset() {
        settings.homeCustom = false
        settings.homeOrder = ""
        settings.homeOff = ""
    }
}
