pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// One desktop entrance per shell process; hot reload preserves the completed flag.
Scope {
    id: root
    required property var tokens
    property bool ready: false
    property bool enabled: true
    readonly property bool running: ready && enabled && !!tokens && !state.played && !tokens.motion.off
    PersistentProperties { id: state; property bool played: false }
    onReadyChanged: if (ready && tokens && (tokens.motion.off || !enabled)) state.played = true
    onEnabledChanged: if (!enabled && state) state.played = true
    Component.onCompleted: if (ready && (tokens.motion.off || !enabled)) state.played = true
    Connections {
        target: root.tokens ? root.tokens.motion : null
        function onOffChanged() { if (root.tokens.motion.off) state.played = true }
    }
    Variants {
        model: root.running ? Quickshell.screens : []
        PanelWindow {
            id: veil
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            color: "transparent"
            Rectangle {
                id: tint
                anchors.fill: parent
                color: root.tokens.color.background
                NumberAnimation {
                    id: fade
                    target: tint
                    property: "opacity"
                    from: 1; to: 0
                    duration: root.tokens.motion.base
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: root.tokens.motion.easeOut
                }
            }
            Component.onCompleted: fade.start()
        }
    }
    Timer { running: root.running; interval: root.tokens ? root.tokens.motion.base + 16 : 236; onTriggered: state.played = true }
}
