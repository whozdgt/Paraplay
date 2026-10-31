import QtQuick

// People asking to follow you. The page only draws this while there is someone waiting.
Item {
    id: root
    property bool compact: false
    signal openUser(string username)
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        HomeHeading { width: parent.width; text: "FOLLOW REQUESTS"; count: social.requests.length }
        ListView {
            width: parent.width
            height: 128
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: social.requests
            delegate: HomePerson {
                required property var modelData
                person: modelData
                request: true
                compact: root.compact
                onOpened: root.openUser(modelData.username)
            }
        }
    }
}
