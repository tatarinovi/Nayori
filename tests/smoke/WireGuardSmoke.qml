pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "surfaces/settings"
import "islands/status"
import "tokens"

ShellRoot {
    id: test
    property int step: 0
    property int ticks: 0
    property bool previewStarted: false
    property bool previewDone: false
    property bool trayPreviewStarted: false
    property bool trayPreviewDone: false
    Tokens { id: theme }
    FloatingWindow {
        id: window
        visible: true
        width: 320; height: 600
        color: theme.color.background
        WireGuardControls {
            id: controls
            x: 12; y: 70; width: 296
            tokens: theme
            watching: true
        }
        StatusIsland { id: status; x: 12; y: 12; tokens: theme; menuWindow: window }
    }
    FileView { id: state; path: Quickshell.env("NAYORI_WG_STATE") }
    FileView { id: event; path: Quickshell.env("NAYORI_WG_STATE") + ".event" }
    function check(ok, label) {
        if (!ok) { console.error("WIREGUARD_FAIL " + label); Qt.exit(1) }
    }
    function changeState(value) {
        state.setText(JSON.stringify(value))
    }
    function findControls(item) {
        if (item.objectName === "wireguard-controls") return item
        for (const child of item.children || []) {
            const found = findControls(child)
            if (found) return found
        }
        return null
    }
    function popupContent() {
        for (const entry of status.data) {
            if (entry && entry.toString().indexOf("Popup") >= 0 && entry.contentItem)
                return entry.contentItem
        }
        return null
    }
    Timer {
        interval: 30; repeat: true; running: true
        onTriggered: {
            test.ticks++
            const control = controls.control
            test.check(test.ticks < 500, "timeout step " + test.step + ": " + control.error)
            if (test.step === 0 && control.ready) {
                test.check(control.available && control.profiles.length === 1, "wireguard only")
                test.check(control.profiles[0].name === "Work: VPN", "escaped name")
                control.toggle(control.profiles[0])
                control.toggle(control.profiles[0])
                test.check(control.busy, "operation busy")
                test.step++
            } else if (test.step === 1 && !control.busy && control.profiles[0].active) {
                if (Quickshell.env("NAYORI_WG_PREVIEW") && !test.previewDone) {
                    if (!test.previewStarted) {
                        test.previewStarted = true
                        controls.grabToImage(result => {
                            result.saveToFile(Quickshell.env("NAYORI_WG_PREVIEW"))
                            test.previewDone = true
                        })
                    }
                    return
                }
                control.toggle(control.profiles[0])
                // Closing the panel must not interrupt a requested operation.
                window.visible = false
                test.step++
            } else if (test.step === 2 && !control.busy && !control.profiles[0].active) {
                test.changeState({active: false, fail: true})
                test.step++
            } else if (test.step === 3) {
                window.visible = true
                control.toggle(control.profiles[0])
                test.step++
            } else if (test.step === 4 && !control.busy && control.error !== "") {
                test.check(!control.profiles[0].active, "failed activation keeps disconnected state")
                control.refresh()
                test.step++
            } else if (test.step === 5 && test.ticks % 10 === 0) {
                test.check(control.error !== "", "query preserves action error")
                test.changeState({active: false})
                test.step++
            } else if (test.step === 6) {
                control.importFile(Quickshell.env("NAYORI_WG_IMPORT"))
                test.step++
            } else if (test.step === 7 && !control.busy && control.profiles.length === 2) {
                test.check(control.notice !== "" && control.error === "", "import feedback")
                test.changeState({active: true, imported: true})
                test.step++
            } else if (test.step === 8) {
                event.setText("changed")
                test.step++
            } else if (test.step === 9 && control.profiles[0].active) {
                test.check(control.profiles[0].device === "wg0", "monitor receives external changes")
                controls.watching = false
                status.opened = "network"
                test.step++
            } else if (test.step === 10) {
                const content = test.popupContent()
                const tray = content ? test.findControls(content) : null
                if (!tray || !tray.control.ready) return
                test.check(tray.control.profiles.length === 2 && tray.control.profiles[0].active, "actual tray integration")
                if (Quickshell.env("NAYORI_WG_PREVIEW") && !test.trayPreviewDone) {
                    if (!test.trayPreviewStarted) {
                        test.trayPreviewStarted = true
                        content.children[0].grabToImage(result => {
                            result.saveToFile(Quickshell.env("NAYORI_WG_PREVIEW") + ".tray.png")
                            test.trayPreviewDone = true
                        })
                    }
                    return
                }
                status.opened = ""
                test.changeState({unavailable: true})
                test.step++
            } else if (test.step === 11) {
                control.refresh()
                test.step++
            } else if (test.step === 12 && !control.available && control.error !== "") {
                test.check(control.profiles.length === 0, "unavailable clears stale profiles")
                test.changeState({empty: true})
                test.step++
            } else if (test.step === 13) {
                control.refresh(true)
                test.step++
            } else if (test.step === 14 && control.available && control.error === "") {
                test.check(control.profiles.length === 0, "empty state")
                test.check(!control.monitor.running, "monitor stops when hidden")
                console.log("WIREGUARD_PASS")
                Qt.quit()
            }
        }
    }
}
