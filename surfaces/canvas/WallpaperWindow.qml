import QtQuick
import Quickshell
import Quickshell.Wayland
import "../desktop"

PanelWindow {
    id: root
    required property var manager
    required property var tokens
    property var widgetHost: null
    property bool widgetsReady: false
    property var weatherService: null
    property var music: null
    readonly property var wallpaper: manager.wallpaper(screen ? screen.name : "")
    anchors { top: true; bottom: true; left: true; right: true }
    visible: manager.enabled
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
    DesktopWidgetFaces {
        anchors.fill: parent
        visible: root.widgetsReady && !!root.widgetHost
        tokens: root.tokens
        items: root.widgetHost ? root.widgetHost.viewItems : []
        hiddenIds: root.widgetHost ? root.widgetHost.hiddenFaces : []
        now: root.widgetHost ? root.widgetHost.now : new Date()
        systemReader: root.widgetHost ? root.widgetHost.sharedSystemReader : null
        weatherService: root.weatherService
        music: root.music
    }

}
