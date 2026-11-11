import QtQuick
import "../niri"
import "DesktopBlur.js" as Policy

// Per-output presentation state, fed only by the shared Niri EventStream.
QtObject {
    id: root
    property string outputName: ""
    property var settings: null
    property bool reduceMotion: false
    property bool occupied: false
    readonly property bool enabled: settings ? settings.desktopBlurEnabled === true : false
    readonly property int duration: reduceMotion ? 0 : (settings ? settings.desktopBlurDuration : 300)
    property real blurOpacity: enabled && occupied ? settings.desktopBlurIntensity / 100 : 0
    property real dimOpacity: enabled && occupied ? settings.desktopDimIntensity / 100 : 0
    Behavior on blurOpacity {
        NumberAnimation { id: blurAnimation; duration: root.duration; easing.type: Easing.OutCubic }
    }
    Behavior on dimOpacity {
        NumberAnimation { id: dimAnimation; duration: root.duration; easing.type: Easing.OutCubic }
    }
    onReduceMotionChanged: if (reduceMotion) { blurAnimation.complete(); dimAnimation.complete() }
    function sync() {
        if (!Niri.available || !Niri.windowsReady) return
        const next = Policy.occupied(Niri.workspaces, Niri.windows, root.outputName)
        if (next !== null) root.occupied = next
    }
    onOutputNameChanged: { occupied = false; coalesce.restart() }
    Component.onCompleted: coalesce.restart()
    property Timer coalesceTimer: Timer {
        id: coalesce
        interval: 0
        onTriggered: root.sync()
    }
    property Connections events: Connections {
        target: Niri
        function onWorkspacesChanged() { coalesce.restart() }
        function onWindowsChanged() { coalesce.restart() }
        function onAvailableChanged() { coalesce.restart() }
        function onWindowsReadyChanged() { coalesce.restart() }
    }
}
