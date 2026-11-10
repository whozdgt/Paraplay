import QtQuick
import QtQuick.Layouts

// Settings › Sound
ColumnLayout {
    id: root
    readonly property color pri: settings.ink
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)

    spacing: 0

    SetGroup {
        first: true
        title: "Playback"
        section: "Sound"
        SetBlock {
            label: "Formats"
            keywords: "formats flac alac wav mp3 aac ogg opus gapless sample rate native lossless"
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; lineHeight: 1.3; color: root.muted
                text: "FLAC · ALAC · WAV · MP3 · AAC · OGG · OPUS\nGapless playback, native sample rate"
            }
        }
        ToggleRow {
            label: "Bit-perfect output"
            note: "No ReplayGain. Volume below 100% changes the samples"
            keywords: "replaygain volume samples audiophile exact"
            checked: settings.bitPerfect
            onToggled: settings.bitPerfect = !settings.bitPerfect
        }
        ToggleRow {
            label: "Match track sample rate"
            note: "Applies on next start"
            keywords: "sample rate hz resample"
            checked: settings.matchRate
            onToggled: settings.matchRate = !settings.matchRate
        }
        ToggleRow {
            label: "Show quality badges"
            keywords: "lossless flac hi-res badge chip format"
            checked: settings.badges
            onToggled: settings.badges = !settings.badges
        }
    }
}
