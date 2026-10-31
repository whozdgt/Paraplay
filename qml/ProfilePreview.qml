import QtQuick

// "Preview" on your own profile page: the same screen a stranger gets, built from what is saved.
Item {
    id: root
    readonly property int gut: width < 600 ? 16 : 36      // side margin; smaller on a phone
    property bool dirty: false      // the Edit page has changes that are not saved yet
    readonly property string sig: [account.visibility, account.showCounts, account.showPlaylists, account.listeningPublic,
                                   account.displayName, account.bio, account.avatarUrl, account.bannerUrl].join("|")

    function reload() { if (visible && account.signedIn) social.openProfile(account.username, true) }
    onVisibleChanged: reload()
    onSigChanged: reload()

    Rectangle {
        id: strip
        x: root.gut
        width: parent.width - 2 * root.gut
        height: 28
        color: settings.primary
        Text {
            anchors { left: parent.left; leftMargin: 14; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            font.pixelSize: 12
            color: "white"
            text: "Previewing your " + (account.visibility === "public" ? "Public" : "Private") + " profile as a stranger would see it. "
                  + (root.dirty ? "Unsaved changes are not shown yet." : "Nothing here can be changed.")
        }
    }
    PublicProfile {
        anchors { left: parent.left; right: parent.right; top: strip.bottom; topMargin: 12; bottom: parent.bottom }
    }
}
