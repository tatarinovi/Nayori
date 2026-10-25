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
    StaticRenderer {
        anchors.fill: parent
        source: root.wallpaper.source
        mode: root.wallpaper.mode
        backgroundColor: root.tokens.color.background
        onFailedChanged: if (root.screen) root.manager.report(root.screen.name, failed)
    }
}
