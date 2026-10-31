import QtQuick
import QtQuick.Dialogs

// The phone's own picture picker (Photos, Files…). Android only: the picture comes back as a content:// address.
FileDialog {
    id: root
    signal picked(string url)
    title: "Choose a picture"
    nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.gif)"]
    onAccepted: root.picked(String(selectedFile))
}
