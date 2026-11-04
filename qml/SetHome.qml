import QtQuick
import QtQuick.Layouts

// Settings › Home: which sections the Home page shows, in what order, and the listening history behind "top artists".
ColumnLayout {
    id: root
    property var panel
    readonly property var lay: panel ? panel.layout : null
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    spacing: 0

    SetGroup {
        first: true
        title: "Sections"
        section: "Home"
        SetBlock {
            label: "Home page layout"
            keywords: "home page layout sections order arrows"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "Switch sections on or off, and use the arrows to move them up or down. Changes show straight away."
            }
        }
        Repeater {
            model: root.lay ? root.lay.listed : []
            ToggleRow {
                id: hrow
                required property string modelData
                required property int index
                label: root.lay.titles[modelData]
                note: root.lay.notes[modelData]
                keywords: "home page section"
                checked: root.lay.isOn(modelData)
                onToggled: root.lay.toggle(modelData)
                IconButton {
                    name: "up"; box: hrow.touch ? 44 : 36; iconSize: 18
                    enabled: hrow.index > 0; opacity: enabled ? 1 : 0.3
                    onClicked: root.lay.move(hrow.modelData, -1)
                }
                IconButton {
                    name: "down"; box: hrow.touch ? 44 : 36; iconSize: 18
                    enabled: hrow.index < root.lay.listed.length - 1; opacity: enabled ? 1 : 0.3
                    onClicked: root.lay.move(hrow.modelData, 1)
                }
            }
        }
        SetBlock {
            label: "Home page layout"
            keywords: "home page layout reset default friends sign in"
            Text {
                visible: !account.signedIn
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "Your friends and follow requests join this list once you sign in."
            }
            Btn {
                Layout.topMargin: 4
                large: true
                label: "Reset to the default layout"
                primary: false
                enabled: settings.homeCustom
                onClicked: root.lay.reset()
            }
        }
    }

    SetGroup {
        title: "Listening history"
        section: "Home"
        SetBlock {
            label: "Listening history"
            keywords: "listening history top artists plays forget wipe privacy"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "Your top artists come from what you play. It is counted and kept on this device only, and never uploaded. "
                      + stats.total + (stats.total === 1 ? " play" : " plays") + " counted so far."
            }
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Btn {
                    large: true
                    label: root.panel && root.panel.confirmForget ? "Yes, forget it" : "Forget my listening history"
                    primary: false
                    enabled: stats.total > 0
                    onClicked: { if (root.panel.confirmForget) { stats.clear(); root.panel.confirmForget = false } else root.panel.confirmForget = true }
                }
                Btn { visible: root.panel && root.panel.confirmForget; large: true; label: "Keep it"; primary: false; onClicked: root.panel.confirmForget = false }
            }
        }
    }
}
