import QtQuick
import Quickshell
import "services/ui"
import "services/ui/Overlap.js" as Overlap
ShellRoot {
    EdgeVisibility { id: top; autoHide: true }
    EdgeVisibility { id: apps; autoHide: true }
    EdgeVisibility { id: spaces; autoHide: true }
    EdgeVisibility { id: tray; autoHide: true }
    function check(value, message) { if (!value) throw new Error(message) }
    Timer {
        interval: 50; running: true
        onTriggered: {
            const workspaces = [{ id: 1, output: "test", active: true }, { id: 2, output: "test", active: false }]
            const windows = [{ workspaceId: 1, output: "test", geometryKnown: true,
                geometry: { x: 100, y: 700, width: 800, height: 300 } }]
            const left = { x: 0, y: 950, width: 80, height: 48 }
            const center = { x: 400, y: 950, width: 200, height: 48 }
            const right = { x: 1000, y: 950, width: 100, height: 48 }
            check(!Overlap.report(left, "test", workspaces, windows).overlaps, "left remains clear")
            check(Overlap.report(center, "test", workspaces, windows).overlaps, "center is obstructed")
            check(!Overlap.report(right, "test", workspaces, windows).overlaps, "right remains clear")
            check(Overlap.report(center, "other", workspaces, windows).count === 0, "other output ignored")
            check(!Overlap.intersects(left, { x: 80, y: 950, width: 10, height: 10 }), "touching edges do not intersect")
            windows[0].geometryKnown = false
            check(Overlap.report(center, "test", workspaces, windows).unknown, "unknown IPC geometry is explicit")
            windows[0].workspaceId = 2
            check(Overlap.report(center, "test", workspaces, windows).count === 0, "inactive workspace ignored")
            console.log("INTELLIGENT_HIDE_GEOMETRY_PASS")
            check(!top.shown && !apps.shown && !spaces.shown && !tray.shown, "initial hidden")
            top.obstructed = false
            check(top.shown, "clear top area stays visible")
            top.obstructed = true
            apps.pointerInside = true
            check(apps.shown && !top.shown && !spaces.shown && !tray.shown, "independent apps reveal")
            apps.pointerInside = false
            check(apps.shown, "bridge across panel gap")
            top.heldOpen = true
            spaces.pointerInside = true
        }
    }
    Timer {
        interval: 800; running: true
        onTriggered: {
            check(!apps.shown && top.shown && spaces.shown && !tray.shown, "delay and held open")
            apps.available = false
            apps.pointerInside = true
            check(!apps.shown, "empty app dock stays hidden")
            tray.autoHide = false
            check(tray.shown, "independent disable")
            top.heldOpen = false
            spaces.pointerInside = false
        }
    }
    Timer {
        interval: 1550; running: true
        onTriggered: {
            check(!top.shown && !spaces.shown && tray.shown, "hide independently after delay")
            console.log("AUTOHIDE_ISOLATION_PASS")
        }
    }
}
