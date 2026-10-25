import QtQuick
import Quickshell
import Quickshell.Wayland

// Background layer for one output. niri's nayori-overview rule places it in
// that output's overview backdrop. It is not the sharp desktop wallpaper.
PanelWindow {
    id: root

    required property var blur
    readonly property string outputName: screen && screen.name ? String(screen.name) : ""
    readonly property string imagePath: {
        const table = root.blur ? root.blur.shown : null
        const slot = table ? table[root.outputName] : null
        return slot && slot.path ? String(slot.path) : ""
    }
    readonly property string imageUrl: {
        if (root.imagePath === "")
            return ""
        return "file://" + encodeURI(root.imagePath).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }

    signal imageFailed(string path)

    visible: imagePath !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#00000000"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nayori-overview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Image {
        id: picture
        anchors.fill: parent
        source: root.imageUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        autoTransform: true
        cache: false
        visible: status === Image.Ready
        onStatusChanged: {
            if (status === Image.Error && root.imagePath !== "")
                root.imageFailed(root.imagePath)
        }
    }
}
