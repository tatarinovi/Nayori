pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "services/settings"
import "surfaces/settings"
import "services/ui"
import "services/ui/PanelModes.js" as PanelModes

ShellRoot {
    id: test
    property int stage: 0
    property int requests: 0
    function check(ok, message) {
        if (!ok) { console.error("PANEL_MODES_FAIL " + message); Qt.exit(1) }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = find(child, name)
            if (found) return found
        }
        return null
    }
    SettingsService { id: settings; storageDirectory: Quickshell.env("NAYORI_SETTINGS_DIR") }
    Tokens { id: theme }
    Test.TestEvent { id: input }
    EdgeMotion { id: motion; tokens: theme; shown: edge.shown }
    EdgeVisibility { id: edge; autoHide: true; obstructed: true }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1000
        implicitHeight: 700
        color: theme.color.background
        PanelsPage {
            id: page
            anchors.fill: parent
            anchors.margins: 16
            tokens: theme
            screens: [{name: "DP-1", width: 2560, height: 1440}, {name: "HDMI-A-1", width: 1920, height: 1080}]
            panelReservations: settings.panelReservations
            panelModes: settings.panelModes
            onPanelReservationChangedRequested: (output, top, bottom) => settings.update({
                panelReservations: PanelModes.updatedReservation(settings.panelReservations, output, top, bottom)
            })
            onPanelModeChangedRequested: (output, part, mode) => {
                test.requests++
                settings.update({panelModes: PanelModes.updated(settings.panelModes, output, part, mode)})
            }
        }
    }
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (!settings.ready) return
            const first = test.find(page, "panels-DP-1-top")
            const second = test.find(page, "panels-HDMI-A-1-status")
            if (test.stage === 0) {
                test.check(first && second, "both monitors expose selectors")
                test.check(test.find(page, "panels-autohide") === null, "no global auto-hide block")
                const primaryTop = test.find(page, "panels-DP-1-top-reservation")
                const secondaryBottom = test.find(page, "panels-HDMI-A-1-bottom-reservation")
                primaryTop.adjusted(64)
                secondaryBottom.adjusted(24)
                test.check(settings.panelReservations["DP-1"].top === 64 && settings.panelReservations["DP-1"].bottom === 0, "primary reservation independent")
                test.check(settings.panelReservations["HDMI-A-1"].top === 0 && settings.panelReservations["HDMI-A-1"].bottom === 24, "secondary reservation independent")
                first.activated("hidden")
                second.activated("auto")
                test.check(settings.panelModes["DP-1"].top === "hidden", "primary can be hidden")
                test.check(settings.panelModes["HDMI-A-1"].status === "auto", "secondary tray independent")
                test.check(test.requests === 2, "only user actions update settings")
                test.check(!edge.shown, "obstruction hides auto mode")
                edge.pointerInside = true
                test.check(edge.shown, "edge hover reveals auto mode")
                edge.pointerInside = false
                test.check(edge.shown, "departure keeps delay")
            } else if (test.stage === 1) {
                test.check(motion.progress > 0 && motion.progress < 1, "appearance has intermediate frames");
                first.forceActiveFocus()
                input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
            } else if (test.stage === 2) {
                input.keyClick(Qt.Key_Up, Qt.NoModifier, -1)
                input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                test.check(settings.panelModes["DP-1"].top === "auto", "custom menu supports keyboard selection")
                test.check(test.requests === 3, "keyboard selection dispatches once")
                window.implicitWidth = 550
                page.selectedOutput = "HDMI-A-1"
            } else if (test.stage === 4) {
                test.check(motion.progress > 0 && motion.progress < 1, "disappearance has intermediate frames");
                test.check(!edge.shown, "auto-hide delay completes")
                edge.available = false
                edge.pointerInside = true
                test.check(!edge.shown, "disabled elements stay hidden on hover")
                test.check(page.activeOutput === "HDMI-A-1", "narrow page selects output")
                test.check(second.width > 140 && second.height >= 36, "custom select keeps usable dimensions")
                second.forceActiveFocus()
                input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
            } else if (test.stage === 5) {
            } else if (test.stage === 6) {
                test.check(motion.progress === 0, "disappearance settles at zero");
                theme.animationsEnabled = false
                edge.available = true
                test.check(motion.progress === 1, "disabled animations reveal immediately");
                input.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
                page.screens = [{name: "HDMI-A-1", width: 1920, height: 1080}]
                test.check(settings.panelModes["DP-1"].top === "auto", "disconnect keeps output preferences")
                settings.flush(true)
                console.log("PANEL_MODES_SMOKE_PASS")
                Qt.quit()
            }
            test.stage++
        }
    }
}
