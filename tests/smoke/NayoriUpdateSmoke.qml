import QtQuick
import Quickshell
import "services/system"

ShellRoot {
    NayoriUpdate { id: updater }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!updater.ready) return
            if (updater.installed || updater.error !== "") {
                console.log("UPDATE_SMOKE_FAIL", updater.installed, updater.error)
                Qt.exit(1)
            } else {
                console.log("UPDATE_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
