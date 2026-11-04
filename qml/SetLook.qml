import QtQuick
import QtQuick.Layouts

// Settings › Look: size, window, colours, lyrics and pictures, cover art.
ColumnLayout {
    id: root
    readonly property color pri: settings.primary

    spacing: 0

    SetGroup {
        first: true
        title: "Interface"
        section: "Look"
        SliderRow {
            id: scaleRow
            label: "Interface size"
            note: "Makes everything bigger or smaller. A bigger size needs a bigger window, and also means bigger touch targets."
            keywords: "scale zoom bigger smaller text size larger font"
            minValue: 80; maxValue: 150; step: 10
            property int pending: settings.uiScale
            value: pressed ? pending : settings.uiScale
            valueText: value + "%"
            onMoved: (v) => pending = v
            onCommitted: (v) => settings.uiScale = v        // the whole window changes size now, so only when you let go
        }
        SetBlock {
            available: settings.uiScale !== 100
            label: "Reset interface size"
            Btn { large: true; primary: false; label: "Reset to 100%"; onClicked: settings.uiScale = 100 }
        }
    }

    SetGroup {
        title: "Window"
        section: "Look"
        ToggleRow {
            available: Qt.platform.os === "linux"
            label: "Frosted glass"
            note: "Blurs what is behind the window"
            keywords: "blur transparent translucent"
            checked: settings.frosted
            onToggled: settings.frosted = !settings.frosted
        }
        ToggleRow {
            label: "Adapt to album colours"
            keywords: "glow album art colour color"
            checked: settings.adaptive
            onToggled: settings.adaptive = !settings.adaptive
        }
    }

    SetGroup {
        title: "Colours"
        section: "Look"
        SetAccordion {
            label: "Theme colours"
            note: "Accent, background, text and highlight"
            keywords: "theme accent background primary highlight hex rgb sliders swatches colour color dark light"
            chip: settings.accent
            ThemeEditor { Layout.fillWidth: true }
        }
    }

    SetGroup {
        title: "Lyrics and pictures"
        section: "Look"
        ToggleRow {
            label: "Show lyrics"
            keywords: "lyrics words karaoke"
            checked: settings.lyrics
            onToggled: settings.lyrics = !settings.lyrics
        }
        ToggleRow {
            label: "Look up lyrics online"
            note: "For songs without lyrics of their own, sends the artist, title and length to lrclib.net. Found lyrics are kept on this device"
            keywords: "lyrics lrclib internet privacy"
            checked: settings.onlineLyrics
            onToggled: settings.onlineLyrics = !settings.onlineLyrics
        }
        ToggleRow {
            label: "Fetch artist pictures online"
            note: "Sends artist names to Deezer"
            keywords: "artist photos images deezer internet privacy"
            checked: settings.onlineArtistPhotos
            onToggled: settings.onlineArtistPhotos = !settings.onlineArtistPhotos
        }
    }

    SetGroup {
        title: "Cover art"
        section: "Look"
        ToggleRow {
            label: "Spinning record cover"
            note: "In the full-screen player, turn the record to change the speed. Let go and it eases back to normal."
            keywords: "vinyl square cover style turntable"
            checked: settings.recordCover
            onToggled: settings.recordCover = !settings.recordCover
        }
        SliderRow {
            label: "Rings around the cover"
            note: "Fewer rings means a bigger cover. 0 shows the cover edge to edge."
            keywords: "cover art circles size"
            maxValue: 6
            value: settings.ringCount
            valueText: String(settings.ringCount)
            onMoved: (v) => settings.ringCount = v
        }
    }
}
