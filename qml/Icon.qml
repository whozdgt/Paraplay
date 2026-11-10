import QtQuick
import QtQuick.Shapes

Item {
    id: root
    property string name
    property color color: "black"
    property real size: 22
    readonly property bool filled: name === "play" || name === "pause" || name === "more" || name === "ff" || name === "rw" || name === "homefill" || name === "heart"
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
        homefill: "M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
        library: "M5 4v16M10 4v16M14.5 4.5l5 15",
        friends: "M12.5 8a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0zM2.5 20a6.5 6.5 0 0 1 13 0M19.5 9a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0zM16.5 14a5 5 0 0 1 5 5",
        more: "M10.2 5a1.8 1.8 0 1 0 3.6 0 1.8 1.8 0 0 0-3.6 0zM10.2 12a1.8 1.8 0 1 0 3.6 0 1.8 1.8 0 0 0-3.6 0zM10.2 19a1.8 1.8 0 1 0 3.6 0 1.8 1.8 0 0 0-3.6 0z",
        ff: "M3 5.5v13l8.5-6.5zM12 5.5v13l8.5-6.5z",
        rw: "M21 5.5v13L12.5 12zM12 5.5v13L3.5 12z",
        heart: "M12 20s-7.5-4.5-7.5-10.2A4.2 4.2 0 0 1 12 7.2a4.2 4.2 0 0 1 7.5 2.6C19.5 15.5 12 20 12 20z",
        song: "M9 18V5l11-2v13M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0zM20 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z",
        album: "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM14.5 12a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0z",
        artist: "M9 6a3 3 0 0 1 6 0v5a3 3 0 0 1-6 0zM5 11a7 7 0 0 0 14 0M12 18v3",
        playlist: "M3 6h12M3 12h12M3 18h7M17 18V8l4-1M17 18a2 2 0 1 1-4 0 2 2 0 0 1 4 0z",
        server: "M3 5.5A1.5 1.5 0 0 1 4.5 4h15A1.5 1.5 0 0 1 21 5.5v4a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 9.5zM3 14.5A1.5 1.5 0 0 1 4.5 13h15a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5zM7 7.5h.01M7 16.5h.01",
        clock: "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM12 7v5l3 2",
        shuffle: "M3 7h3.5c2 0 3.2 1 4.3 2.6l2.4 4.8C14.3 16 15.5 17 17.5 17H21M3 17h3.5c1.4 0 2.4-.5 3.2-1.4M14.3 8.4c.8-.9 1.8-1.4 3.2-1.4H21M18 4l3 3-3 3M18 14l3 3-3 3",
        repeat: "M17 2l3 3-3 3M4 11V9a4 4 0 0 1 4-4h12M7 22l-3-3 3-3M20 13v2a4 4 0 0 1-4 4H4",
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
