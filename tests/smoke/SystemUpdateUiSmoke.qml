import QtQuick
import Quickshell
import "tokens"
import "surfaces/settings"
import "surfaces/island"

ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: false }
    QtObject { id: update; property bool busy: true; property string status: "Собираем пакеты AUR"; property string error: ""; property bool toolsReady: true; property bool pacmanFound: true; property bool yayFound: true; property bool sudoFound: true; property bool zenityFound: true }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const result = find(child, name); if (result) return result }
        return null
    }
    FloatingWindow {
        visible: true; implicitWidth: 800; implicitHeight: 900
        Column {
            DynamicIsland { id: compact; width: 352; height: 48; tokens: theme; testMode: true; systemUpdateService: update }
            UpdatesPage { id: page; width: 680; tokens: theme; systemUpdateService: update }
            IslandDashboard { id: island; width: 680; height: 450; tokens: theme; testMode: true; systemUpdateService: update }
        }
    }
    Timer {
        running: true; interval: 100
        onTriggered: {
            const c = root.find(compact, "islandCompactUpdateStatus")
            const a = root.find(page, "systemUpdateStatus")
            const b = root.find(island, "islandExpandedUpdateStatus")
            if (!a || !b || !c || !a.visible || !b.visible || !c.visible || a.text !== update.status || b.text !== update.status || c.text !== update.status) {
                console.log("SYSTEM_UPDATE_UI_FAIL"); Qt.exit(1); return
            }
            console.log("SYSTEM_UPDATE_UI_PASS"); Qt.quit()
        }
    }
}
