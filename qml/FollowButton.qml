import QtQuick

// Follow / Request / Following / Requested, depending on where things stand with that person.
Btn {
    id: root
    property var person: ({})
    readonly property string st: root.person.state || "none"
    height: 32
    primary: root.st === "none"
    label: root.st === "accepted" ? "Following"
         : root.st === "requested" ? "Requested"
         : (root.person.visibility === "public" ? "Follow" : "Request")
    onClicked: {
        if (root.st === "none") social.follow(root.person.id)
        else social.unfollow(root.person.id)
    }
}
