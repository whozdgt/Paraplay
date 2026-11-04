import QtCore
import QtQuick
import QtQuick.Dialogs

// The phone's own picture picker (Photos, Files…). The picture comes back as a content:// (Android) or
// assets-library:// (iPhone) address.
FileDialog {
    id: root
    signal picked(string url)
    title: "Choose a picture"
    nameFilters: ["Pictures (*.png *.jpg *.jpeg *.webp *.gif)"]
    onAccepted: root.picked(String(selectedFile))
    // on an iPhone, starting in the pictures place opens Photos instead of the Files app
    Component.onCompleted: if (Qt.platform.os === "ios") currentFolder = StandardPaths.writableLocation(StandardPaths.PicturesLocation)
}
