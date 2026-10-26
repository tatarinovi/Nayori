import QtQuick
import Quickshell.Wayland
import "../niri"

// Niri also reports windowed-fullscreen through foreign-toplevel fullscreen.
// Require a matching tile that actually covers the output on its active workspace.
QtObject {
    id: root
    property var screen: null
    property bool enabled: true
    required property var tokens
    property real reveal: blocked ? 0 : 1
    Behavior on reveal {
        NumberAnimation {
            // Native compositor blur cannot follow QML opacity. Unmap the whole
            // surface immediately on entry; only returning to the desktop fades.
            duration: root.blocked || root.tokens.motion.off ? 0 : root.tokens.motion.base
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
        }
    }
    readonly property bool blocked: {
        if (!enabled || !screen || !Niri.available) return false
        const output = screen.name
        const workspaces = Niri.workspaces
        const windows = Niri.windows
        const activeIds = workspaces.filter(workspace => workspace.output === output && workspace.active).map(workspace => workspace.id)
        for (const window of ToplevelManager.toplevels.values) {
            if (!window.fullscreen || window.minimized) continue
            if (!Array.from(window.screens).some(candidate => candidate.name === output)) continue
            const matches = windows.filter(candidate => candidate.appId === window.appId && candidate.title === window.title)
            if (matches.some(candidate => {
                if (candidate.output !== output || !activeIds.includes(candidate.workspaceId)) return false
                const layout = candidate.layout
                const size = layout ? layout.tile_size : null
                if (!Array.isArray(size) || size.length !== 2) return false
                if (Math.abs(size[0] - screen.width) > 1 || Math.abs(size[1] - screen.height) > 1) return false
                const position = layout.tile_pos_in_workspace_view
                return !Array.isArray(position) || (Math.abs(position[0]) <= 1 && Math.abs(position[1]) <= 1)
            })) return true
        }
        return false
    }
}
