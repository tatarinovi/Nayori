pragma Singleton
import QtQuick
import Quickshell
// Only the original app-icon lookup is needed by IrisScreenTimeFace.
QtObject {
    function appIcon(appId: string): string {
        const id = String(appId || "")
        const entry = DesktopEntries.applications.values.find(app => app.id === id || app.id === id + ".desktop")
        return entry && entry.icon ? entry.icon : id || "application-x-executable"
    }
}
