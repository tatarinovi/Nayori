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
                updater.operation = "apply"
                updater.receiveResult(1, {ok: false, error: "ошибка"}, "")
                if (updater.restartNeeded) { console.log("UPDATE_SMOKE_FAIL failed update"); Qt.exit(1); return }
                updater.receiveResult(0, {ok: true, installed: true}, "")
                if (!updater.restartNeeded) { console.log("UPDATE_SMOKE_FAIL successful update"); Qt.exit(1); return }
                updater.operation = "check"
                updater.receiveResult(0, {ok: true, installed: true}, "")
                if (!updater.restartNeeded) { console.log("UPDATE_SMOKE_FAIL check lost restart"); Qt.exit(1); return }
                console.log("UPDATE_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
