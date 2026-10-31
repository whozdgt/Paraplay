import QtQuick

// The Home page: a greeting, then the sections the person chose in Settings -> Home page.
// Guests get playlists, albums and songs by default, with a quiet way to sign up or in beside their name.
Flickable {
    id: root
    property var layout                     // HomeLayout
    property int gutter: 36
    readonly property bool compact: width < 620
    signal openUser(string username)
    signal openArtist(string name)
    signal openAlbum(string key, string name)
    signal openPlaylist(string key, string name)
    signal showView(string view)            // songs | albums | playlists
    signal menuRequested(string path, real gx, real gy)
    signal openProfile()
    signal signInRequested()
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    property int hour: new Date().getHours()
    onVisibleChanged: if (visible) hour = new Date().getHours()

    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 40
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        x: root.gutter
        y: 6
        width: root.width - 2 * root.gutter
        spacing: root.compact ? 22 : 30

        // ---- who you are ----
        Row {
            id: head
            width: parent.width
            spacing: root.compact ? 16 : 22
            readonly property int pic: root.compact ? 72 : 104
            Item {
                width: head.pic; height: head.pic
                Avatar { anchors.fill: parent; source: account.signedIn ? account.avatarUrl : "" }
                MouseArea { anchors.fill: parent; enabled: account.signedIn; cursorShape: Qt.PointingHandCursor; onClicked: root.openProfile() }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, parent.width - head.pic - head.spacing - (root.compact ? 0 : 190))
                spacing: 4
                Text {
                    text: root.hour < 12 ? "Good morning" : root.hour < 18 ? "Good afternoon" : "Good evening"
                    font.pixelSize: root.compact ? 13 : 14
                    color: root.muted
                }
                Flow {
                    width: parent.width
                    spacing: 16
                    Text {
                        width: Math.min(implicitWidth, parent.width)
                        text: account.signedIn ? (account.displayName || account.username) : "Guest"
                        elide: Text.ElideRight
                        font.pixelSize: root.compact ? 28 : 40
                        font.weight: Font.DemiBold
                        color: root.pri
                        MouseArea { anchors.fill: parent; enabled: account.signedIn; cursorShape: Qt.PointingHandCursor; onClicked: root.openProfile() }
                    }
                    Btn {       // guests aren't pushed: just a small way in
                        visible: !account.signedIn
                        label: "Sign up / in"
                        primary: false
                        opacity: 0.85
                        onClicked: root.signInRequested()
                    }
                }
                Text {
                    visible: account.signedIn
                    text: "@" + account.username
                    font.pixelSize: 12
                    color: root.muted
                }
            }
        }

        // ---- the sections ----
        Repeater {
            model: root.layout ? root.layout.shown : []
            Loader {
                id: slot
                required property string modelData
                width: col.width
                active: modelData !== "requests" || social.requests.length > 0
                visible: active
                height: item ? item.implicitHeight : 0
                sourceComponent: modelData === "friends" ? friendsC
                               : modelData === "requests" ? requestsC
                               : modelData === "top" ? topC
                               : modelData === "playlists" ? playlistsC
                               : modelData === "albums" ? albumsC
                               : songsC
            }
        }
    }

    Component { id: friendsC; HomeFriends { compact: root.compact; onOpenUser: (u) => root.openUser(u) } }
    Component { id: requestsC; HomeRequests { compact: root.compact; onOpenUser: (u) => root.openUser(u) } }
    Component { id: topC; HomeTop { compact: root.compact; onOpenArtist: (n) => root.openArtist(n) } }
    Component {
        id: playlistsC
        HomeStrip {
            kind: "playlist"; heading: "PLAYLISTS"; compact: root.compact
            onPicked: (k, n) => root.openPlaylist(k, n)
            onSeeAll: root.showView("playlists")
        }
    }
    Component {
        id: albumsC
        HomeStrip {
            kind: "album"; heading: "ALBUMS"; compact: root.compact
            onPicked: (k, n) => root.openAlbum(k, n)
            onSeeAll: root.showView("albums")
        }
    }
    Component {
        id: songsC
        HomeSongs {
            onSeeAll: root.showView("songs")
            onMenuRequested: (p, x, y) => root.menuRequested(p, x, y)
        }
    }
}
