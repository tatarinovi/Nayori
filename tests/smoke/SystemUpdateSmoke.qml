import QtQuick
import Quickshell
import "services/system"

ShellRoot {
    id: root
    SystemUpdate { id: service }
    Timer {
        interval: 100; repeat: true; running: true
        property int step: 0
        property int ticks: 0
        onTriggered: {
            ticks++
            if (ticks > 100) { console.log("SYSTEM_UPDATE_FAIL timeout"); Qt.quit(); return }
            if (step === 0 && service.toolsReady) {
                if (!service.pacmanFound || !service.yayFound || !service.sudoFound || !service.zenityFound || !service.start() || service.start()) {
                    console.log("SYSTEM_UPDATE_FAIL start"); Qt.quit(); return
                }
                service.receive(":: Synchronizing package databases...", false)
                if (service.status !== "Обновляем базы пакетов") { console.log("SYSTEM_UPDATE_FAIL progress"); Qt.quit(); return }
                step = 1
            } else if (step === 1 && !service.busy) {
                if (service.status !== "Обновление завершено" || service.error !== "") {
                    console.log("SYSTEM_UPDATE_FAIL result " + service.status + " " + service.error); Qt.quit(); return
                }
                service.sudoFound = false
                if (service.start()) { console.log("SYSTEM_UPDATE_FAIL missing sudo"); Qt.quit(); return }
                service.sudoFound = true
                service.yayFound = false
                if (!service.start()) { console.log("SYSTEM_UPDATE_FAIL fallback"); Qt.quit(); return }
                step = 2
            } else if (step === 2 && !service.busy) {
                if (service.status !== "Обновление не завершено" || service.error.indexOf("fake failure") < 0) {
                    console.log("SYSTEM_UPDATE_FAIL failure " + service.error); Qt.quit(); return
                }
                console.log("SYSTEM_UPDATE_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
