pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Live, input-transparent outline. No frozen frame, scrim or capture controls.
PanelWindow {
    id: root
    required property var tokens
    required property var service
    required property string outputName
    visible: service.mode === "video" && (service.recording || service.state === "starting") && outputName === service.output
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nayori-capture-frame"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    readonly property var area: service.area
    readonly property int lineWidth: 2
    readonly property real leftEdge: Math.max(0, area.x - lineWidth)
    readonly property real topEdge: Math.max(0, area.y - lineWidth)
    readonly property real rightEdge: Math.min(root.width - lineWidth, area.x + area.w)
    readonly property real bottomEdge: Math.min(root.height - lineWidth, area.y + area.h)
    // Keep the outline outside the recording crop wherever monitor bounds allow.
    Rectangle {
        x: root.leftEdge; y: root.topEdge
        width: Math.max(root.lineWidth, root.rightEdge + root.lineWidth - x); height: root.lineWidth
        color: root.tokens.color.accent; opacity: root.service.paused ? 0.6 : 1
    }
    Rectangle {
        x: root.leftEdge; y: root.bottomEdge
        width: Math.max(root.lineWidth, root.rightEdge + root.lineWidth - x); height: root.lineWidth
        color: root.tokens.color.accent; opacity: root.service.paused ? 0.6 : 1
    }
    Rectangle {
        x: root.leftEdge; y: root.topEdge
        width: root.lineWidth; height: Math.max(root.lineWidth, root.bottomEdge + root.lineWidth - y)
        color: root.tokens.color.accent; opacity: root.service.paused ? 0.6 : 1
    }
    Rectangle {
        x: root.rightEdge; y: root.topEdge
        width: root.lineWidth; height: Math.max(root.lineWidth, root.bottomEdge + root.lineWidth - y)
        color: root.tokens.color.accent; opacity: root.service.paused ? 0.6 : 1
    }
}
