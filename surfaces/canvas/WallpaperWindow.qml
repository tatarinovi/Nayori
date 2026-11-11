import QtQuick
import Quickshell
import Quickshell.Wayland
import "../desktop"
import "../startup"
import "../../services/canvas"

PanelWindow {
    id: root
    required property var manager
    required property var tokens
    property var widgetHost: null
    property var blur: null
    property var settings: null
    readonly property real desktopDimOpacity: desktopBlur.dimOpacity
    property string outputName: screen ? screen.name : ""
    DesktopBlur {
        id: desktopBlur
        outputName: root.outputName
        settings: root.settings
        reduceMotion: root.tokens.motion.off
    }
    readonly property bool startupReady: manager.ready && (!visible || firstFrame.seen)
    FirstFrame {
        id: firstFrame
        armed: root.visible && wallpaperFrames.startupReady && root.widgetsReady
    }
    property bool widgetsReady: false
    property var weatherService: null
    property var music: null
    readonly property var wallpaper: manager.displayWallpaper(root.outputName)
    anchors { top: true; bottom: true; left: true; right: true }
    visible: manager.displayEnabled(root.outputName)
    color: tokens.color.background
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nayori-canvas"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WallpaperCrossfade {
        id: wallpaperFrames
        anchors.fill: parent
        source: String(root.wallpaper.source)
        blur: root.blur
        blurOpacity: desktopBlur.blurOpacity
        effectDuration: desktopBlur.duration
        mode: root.wallpaper.mode
        backgroundColor: root.tokens.color.background
        reduceMotion: root.tokens.motion.off
        duration: root.tokens.motion.base
        managerReady: root.manager.ready
        outputName: root.outputName
        onRenderFailed: function (failed) {
            if (root.outputName) root.manager.report(root.outputName, failed)
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
        audioReaction: root.widgetHost ? root.widgetHost.audioReaction : null
        wallpaperClockAccent: root.widgetHost ? root.widgetHost.wallpaperClockAccent : null
    }
    // One scrim above the entire desktop, including widget faces. This remains
    // on the Background surface, below every application and input proxy.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: desktopBlur.dimOpacity
        visible: opacity > 0
    }
}
