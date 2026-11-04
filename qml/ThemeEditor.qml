import QtQuick
import QtQuick.Layouts

// Everything about colours: a preview, ready-made accent and background colours, hex boxes, how strong the tints are,
// and (folded away) red/green/blue sliders for each colour.
ColumnLayout {
    id: root
    readonly property color pri: settings.primary
    readonly property color muted: Qt.rgba(pri.r, pri.g, pri.b, 0.72)
    readonly property color accentC: settings.accent
    readonly property color bgC: settings.bgColor
    readonly property color hiC: settings.highlight
    readonly property var accents: [["#16a34a", "Green"], ["#2563eb", "Blue"], ["#db2777", "Pink"], ["#ea580c", "Orange"],
                                    ["#7c3aed", "Purple"], ["#0891b2", "Teal"], ["#ca8a04", "Amber"], ["#dc2626", "Red"]]
    readonly property var backgrounds: [["#f3f0f5", "Lavender grey (the default)"], ["#ffffff", "White"], ["#eaf1ee", "Mist green"],
                                        ["#f6efe4", "Sand"], ["#202028", "Charcoal"], ["#0f1318", "Midnight"]]

    spacing: 0

    function isDark(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.5 }
    // a new background brings text and highlight that can be read on it
    function setBackground(hex) {
        const c = Qt.color(hex)
        const ink = isDark(c) ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(0, 0, 0, 1)
        settings.bgColor = c
        settings.primary = ink
        settings.highlight = ink
    }
    function resetAll() {
        settings.accent = Qt.color("#16a34a")
        settings.bgColor = Qt.color("#f3f0f5")
        settings.primary = Qt.color("#000000")
        settings.highlight = Qt.color("#000000")
        settings.highlightOpacity = 12
        settings.boxOpacity = 5
    }

    SectionLabel { text: "PREVIEW"; topPadding: 4 }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 156
        clip: true
        color: settings.solid ? root.bgC : Qt.rgba(1, 1, 1, 0.58)
        border.width: 1
        border.color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.15)
        Accessible.role: Accessible.Graphic
        Accessible.name: "Preview of the chosen colours"

        Column {
            y: 10; width: 112
            Repeater {
                model: ["Home", "Songs", "Albums"]
                Rectangle {
                    id: navRow
                    required property string modelData
                    readonly property bool on: modelData === "Songs"
                    width: 112; height: 28
                    color: on ? settings.hiSel : "transparent"
                    Rectangle { visible: navRow.on; width: 3; height: parent.height; color: settings.accent }
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: navRow.modelData; font.pixelSize: 12; color: root.pri; opacity: navRow.on ? 1 : 0.7
                    }
                }
            }
        }
        Rectangle { x: 112; width: 1; height: parent.height; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.15) }
        Column {
            x: 128; y: 12; width: parent.width - 140; spacing: 8
            Text { text: "Songs"; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.pri }
            Rectangle {
                width: parent.width; height: 38
                color: settings.hiSel
                Rectangle { width: 3; height: parent.height; color: settings.accent }
                Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.12) }
                Column {
                    x: 46; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                    Rectangle { width: 90; height: 7; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.45) }
                    Rectangle { width: 60; height: 7; color: Qt.rgba(root.pri.r, root.pri.g, root.pri.b, 0.12) }
                }
            }
            Row {
                spacing: 14; height: 30
                Rectangle {
                    width: 64; height: 30; color: root.pri
                    Text { anchors.centerIn: parent; text: "Play"; font.pixelSize: 12; color: settings.solid ? root.bgC : "white" }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36; height: 20; color: settings.accent
                    Rectangle { x: 19; y: 3; width: 14; height: 14; color: "white" }
                }
            }
        }
    }

    SectionLabel { text: "ACCENT COLOUR"; topPadding: 18 }
    Flow {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: root.accents
            Swatch {
                required property var modelData
                swatch: modelData[0]
                name: modelData[1]
                selected: Qt.colorEqual(root.accentC, modelData[0])
                onPicked: settings.accent = Qt.color(modelData[0])
            }
        }
    }
    RowLayout {
        Layout.topMargin: 8
        spacing: 12
        Text { text: "Hex"; font.pixelSize: 13; color: root.muted }
        HexField { hex: root.accentC.toString(); onPicked: (h) => settings.accent = Qt.color(h) }
    }

    SectionLabel { visible: settings.solid; text: "BACKGROUND"; topPadding: 18 }
    Flow {
        visible: settings.solid
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: root.backgrounds
            Swatch {
                required property var modelData
                swatch: modelData[0]
                name: modelData[1]
                selected: Qt.colorEqual(root.bgC, modelData[0])
                onPicked: root.setBackground(modelData[0])
            }
        }
    }
    RowLayout {
        visible: settings.solid
        Layout.topMargin: 8
        spacing: 12
        Text { text: "Hex"; font.pixelSize: 13; color: root.muted }
        HexField { hex: root.bgC.toString(); onPicked: (h) => settings.bgColor = Qt.color(h) }
    }

    SectionLabel { visible: settings.solid; text: "SELECTION AND BOXES"; topPadding: 18 }
    SliderRow {
        available: settings.solid
        label: "Selection strength"
        note: "The colour behind what is playing and the menu item you are on"
        maxValue: 50
        value: settings.highlightOpacity
        valueText: settings.highlightOpacity + "%"
        onMoved: (v) => settings.highlightOpacity = v
    }
    SliderRow {
        available: settings.solid
        label: "Boxes and fields"
        note: "Boxes like the profile fields"
        maxValue: 30
        value: settings.boxOpacity
        valueText: settings.boxOpacity + "%"
        onMoved: (v) => settings.boxOpacity = v
    }

    SetAccordion {
        Layout.topMargin: 12
        label: "Colour sliders"
        note: "Fine-tune any colour with red, green and blue"
        ColorEditor { title: "Primary"; value: root.pri; onEdited: (c) => settings.primary = c }
        ColorEditor { title: "Accent"; value: root.accentC; onEdited: (c) => settings.accent = c }
        ColorEditor { visible: settings.solid; title: Qt.platform.os === "linux" ? "Background (frosted glass off)" : "Background"; value: root.bgC; onEdited: (c) => settings.bgColor = c }
        ColorEditor { visible: settings.solid; title: "Highlight"; value: root.hiC; onEdited: (c) => settings.highlight = c }
        Item { Layout.preferredHeight: 8 }
    }

    Btn { Layout.topMargin: 16; Layout.bottomMargin: 6; large: true; primary: false; label: "Reset colours to defaults"; onClicked: root.resetAll() }
}
