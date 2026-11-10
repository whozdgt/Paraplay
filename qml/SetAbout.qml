import QtQuick
import QtQuick.Layouts

// Settings › About: the version and updates.
ColumnLayout {
    id: root
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    spacing: 0

    SetGroup {
        first: true
        title: "Updates"
        section: "About"
        ValueRow {
            label: "Version"
            keywords: "about version build release"
            value: (settings.mobile ? "Paraplay " : "Music ") + updater.current
        }
        ToggleRow {
            available: !updater.store              // a Play Store or App Store build is updated by the store
            label: "Check for updates on start"
            note: settings.mobile ? "Asks GitHub for a newer build, at most once an hour" : "Asks GitHub for the newest version, at most twice a day"
            keywords: "update upgrade github automatic"
            checked: settings.autoUpdateCheck
            onToggled: settings.autoUpdateCheck = !settings.autoUpdateCheck
        }
        SetBlock {
            available: !updater.store
            label: "Check now"
            keywords: "update upgrade install check now restart release page"
            Text {
                visible: updater.status !== ""
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: updater.status
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Btn { large: true; label: updater.checking ? "Checking…" : "Check now"; primary: false; enabled: !updater.checking && !updater.installing; onClicked: updater.check(true) }
                Btn {
                    visible: updater.available && updater.canInstall && !updater.installed
                    large: true
                    label: updater.installing ? "Updating…" : "Update now"
                    enabled: !updater.installing
                    onClicked: updater.install()
                }
                Btn { visible: updater.installed; large: true; label: "Restart"; onClicked: updater.restart() }
                Btn { visible: updater.available && !updater.canInstall; large: true; label: "Open release page"; primary: false; onClicked: updater.openReleasePage() }
            }
            Text {
                visible: updater.available && !updater.canInstall
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: !updater.configured ? "This build isn't linked to a release page yet."
                    : Qt.platform.os === "windows" ? "Download the new installer from the release page and run it. Your settings and library stay as they are."
                    : "To update from inside the player, install it once with ./update.sh --here from the project folder."
            }
            Rectangle {
                visible: updater.installing && settings.mobile
                Layout.fillWidth: true; Layout.preferredHeight: 4; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.2)
                Rectangle { width: parent.width * updater.progress; height: parent.height; color: settings.accent }
            }
            Text {
                visible: updater.installing && !settings.mobile
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "The new version is built on this computer at low priority, so music keeps playing. This can take a few minutes."
            }
        }
    }

    SetGroup {
        title: "Privacy"
        section: "About"
        SetBlock {
            label: "Privacy policy and terms"
            keywords: "privacy policy terms data delete account legal"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "No ads, no tracking. Your music stays on your device; an account is optional."
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                Btn { large: true; primary: false; label: "Privacy policy"; onClicked: Qt.openUrlExternally("https://whozdgt.github.io/Paraplay/privacy.html") }
                Btn { large: true; primary: false; label: "Terms"; onClicked: Qt.openUrlExternally("https://whozdgt.github.io/Paraplay/terms.html") }
            }
        }
    }

    SetGroup {
        visible: !updater.store
        title: "What's new"
        section: "About"
        SetBlock {
            available: updater.notes !== ""
            label: "What's new"
            keywords: "release notes changes changelog"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.pri
                text: updater.notes
            }
        }
    }
}
