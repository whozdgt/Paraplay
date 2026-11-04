import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string name
    property color color: "black"
    property real size: 22
    readonly property bool filled: name === "play" || name === "pause"
    readonly property var paths: ({
        prev: "M19 20 9 12l10-8zM5 5v14",
        next: "M5 4l10 8-10 8zM19 5v14",
        play: "M6 4l14 8-14 8z",
        pause: "M6 4h4v16H6zM14 4h4v16h-4z",
        up: "M6 15l6-6 6 6",
        down: "M6 9l6 6 6-6",
        close: "M6 6l12 12M18 6 6 18",
        sort: "M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4",
        volume: "M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 0 1 0 6",
        menu: "M4 6h16M4 12h16M4 18h16",
        lyrics: "M4 5h16v11H10l-4 4v-4H4zM8 9h8M8 12h5",
        search: "M18 11a7 7 0 1 1-14 0 7 7 0 0 1 14 0zM20 20l-4-4",
        plus: "M12 5v14M5 12h14",
        personplus: "M12.6 8a3.6 3.6 0 1 1-7.2 0 3.6 3.6 0 0 1 7.2 0zM2.5 20.5c.5-3.8 3-6.3 6.5-6.3s6 2.5 6.5 6.3M19 3v6M16 6h6",
        camera: "M4 8h4l2-3h4l2 3h4v11H4zM12 17a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z",
        cloud: "M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z",
        chevron: "M9 6l6 6-6 6",
        back: "M15 6l-6 6 6 6",
        folder: "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z",
        wave: "M4 10v4M8 6v12M12 3v18M16 7v10M20 10v4",
        eye: "M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z",
        home: "M3 11l9-8 9 8M5 10v10h5v-6h4v6h5V10",
        info: "M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM12 11v6M12 7.5v.01",
        gear: "M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"
    })
    width: size
    height: size

    Shape {
        width: 24
        height: 24
        scale: root.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.filled ? "transparent" : root.color
            strokeWidth: root.filled ? -1 : 1.8
            fillColor: root.filled ? root.color : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.paths[root.name] || "" }
        }
    }
}
