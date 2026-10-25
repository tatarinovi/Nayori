.pragma library

function intersects(a, b) {
    if (!a || !b || a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0)
        return false
    return a.x < b.x + b.width && b.x < a.x + a.width
        && a.y < b.y + b.height && b.y < a.y + a.height
}

// All rectangles are local to the output, in logical pixels. Unknown geometry
// is reported separately so callers can apply an explicit fallback policy.
function report(panel, output, workspaces, windows) {
    var activeIds = {}
    for (var i = 0; i < workspaces.length; i++) {
        var workspace = workspaces[i]
        if (workspace.output === output && workspace.active)
            activeIds[workspace.id] = true
    }
    var result = { overlaps: false, unknown: false, count: 0 }
    for (var j = 0; j < windows.length; j++) {
        var window = windows[j]
        if (!activeIds[window.workspaceId] || window.output !== output)
            continue
        result.count++
        if (!window.geometryKnown || !window.geometry)
            result.unknown = true
        else if (intersects(panel, window.geometry))
            result.overlaps = true
    }
    return result
}
