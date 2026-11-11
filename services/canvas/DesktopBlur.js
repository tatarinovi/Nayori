// Niri Windows contains application toplevels, never layer-shell surfaces.
// null means that an output snapshot is not yet usable (startup/reconnect).
function occupied(workspaces, windows, output) {
    if (!output) return null
    const active = workspaces.find(workspace => workspace.output === output && workspace.active)
    if (!active) return null
    return windows.some(window => window.workspaceId === active.id)
}
