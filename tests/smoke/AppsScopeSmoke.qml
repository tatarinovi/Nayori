import QtQuick
import Quickshell
import "islands/apps"
import "tokens"

ShellRoot {
    Tokens { id: theme }
    AppsIsland { id: apps; tokens: theme }
    Timer {
        interval: 50; running: true
        onTriggered: {
        const workspaces = [{id: 1, output: "DP-1", active: true}, {id: 2, output: "DP-1"}, {id: 3, output: "DP-2"}]
        const windows = [{id: 1, workspaceId: 1}, {id: 2, workspaceId: 2}, {id: 3, workspaceId: 3}, {id: 4, workspaceId: 99}]
        function check(ok, message) { if (!ok) throw new Error(message) }
        check(apps.collect("DP-1", workspaces, windows).windows.length === 1, "active workspace")
        apps.allMonitorWindows = true
        check(apps.collect("DP-1", workspaces, windows).windows.length === 2, "all monitor workspaces")
        check(apps.collect("DP-2", workspaces, windows).windows.length === 1, "other monitor")
        check(apps.collect("missing", workspaces, windows).windows.length === 0, "missing output")
        let many = []
        for (let i = 0; i < 12; i++) many.push({id: i, workspaceId: 2})
        check(apps.collect("DP-1", workspaces, many).windows.length === 12, "all windows available")
        console.log("APPS_SCOPE_PASS")
        Qt.quit()
        }
    }
}
