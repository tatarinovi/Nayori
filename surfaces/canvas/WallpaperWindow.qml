import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    required property var manager
    required property var tokens
    readonly property var wallpaper: manager.wallpaper(screen ? screen.name : "")
    anchors { top: true; bottom: true; left: true; right: true }
    color: tokens.color.background
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nayori-canvas"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WallpaperCrossfade {
        anchors.fill: parent
        source: String(root.wallpaper.source)
        mode: root.wallpaper.mode
        backgroundColor: root.tokens.color.background
        reduceMotion: root.tokens.motion.off
        duration: root.tokens.motion.base
        managerReady: root.manager.ready
        outputName: root.screen && root.screen.name ? String(root.screen.name) : ""
        onRenderFailed: function (failed) {
            if (root.screen) root.manager.report(root.screen.name, failed)
        }
    }
}
