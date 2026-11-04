import QtQuick
import QtQuick.Layouts

// The base of the rows in Settings. Inside a SetGroup, a row hides itself while the search box holds words it doesn't match.
Item {
    id: root
    property string label
    property string note
    property string keywords                  // extra words the search should find this row by
    property bool available: true             // false takes the row away for good (a setting this system doesn't have)
    readonly property var host: parent
    readonly property bool inGroup: host !== null && host !== undefined && host.isSetBody === true
    readonly property string query: String(settings.settingsQuery).trim().toLowerCase()
    readonly property bool groupHit: inGroup && host.groupHit === true
    readonly property bool shown: available && (!inGroup || query === "" || groupHit || matches())
    readonly property bool touch: settings.mobile

    visible: shown
    Layout.fillWidth: true

    function matches() {
        const hay = (label + " " + note + " " + keywords).toLowerCase()
        for (const w of query.split(" "))
            if (w !== "" && hay.indexOf(w) < 0) return false
        return true
    }
}
