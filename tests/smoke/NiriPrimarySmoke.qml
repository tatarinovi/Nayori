import QtQuick
import Quickshell
import "services/system"

ShellRoot {
    NiriPrimary { id: primary }
    Timer {
        property int ticks: 0
        interval: 100; repeat: true; running: true
        onTriggered: {
            ticks++
            if (primary.outputs.length === 2) {
                if (primary.outputs[0].name !== "DP-1" || !primary.outputs[0].focusAtStartup || primary.outputs[1].focusAtStartup) {
                    console.error("NIRI_PRIMARY_FAIL wrong records"); Qt.exit(1); return
                }
                console.log("NIRI_PRIMARY_PASS"); Qt.quit(); return
            }
            if (ticks > 100) { console.error("NIRI_PRIMARY_FAIL timeout"); Qt.exit(1) }
        }
    }
}
