import QtQuick
import Quickshell
import Quickshell.Wayland
import "tokens"
import "islands/status"

ShellRoot {
    id: root
    Tokens { id: theme; surfaceStyle: "frosted" }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 500; implicitHeight: 300
        StatusIsland { id: status; tokens: theme; menuWindow: window; x: 100; y: 200 }
    }
    property var popup: null
    property int stage: 0
    property int index: 0
    property var names: ["tray", "bluetooth", "audio", "network"]
    function check(value, message) { if (!value) throw new Error("STATUS_POPUP_FAIL: " + message) }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            if (!root.popup) {
                for (let i = 0; i < status.data.length; i++)
                    if (status.data[i].objectName === "status-popup") root.popup = status.data[i]
                root.check(!!root.popup, "popup found")
            }
            if (root.stage === 0) {
                status.opened = root.names[root.index]
                root.stage = 1
            } else if (root.stage === 1) {
                root.check(status.popupReveal === 1 && root.popup.visible, "open " + root.names[root.index])
                root.check(root.popup.BackgroundEffect.blurRegion !== null, "blur enabled when open")
                status.opened = ""
                root.check(status.displayedPopup === root.names[root.index], "content retained during close")
                root.check(root.popup.BackgroundEffect.blurRegion === null, "blur removed on close")
                root.check(!root.popup.grabFocus, "focus released on close")
                root.stage = 2
            } else if (root.stage === 2) {
                root.check(!root.popup.visible && status.popupReveal === 0, "close completed")
                root.index++
                if (root.index < root.names.length) root.stage = 0
                else {
                    status.opened = "audio"
                    root.stage = 3
                }
            } else if (root.stage === 3) {
                status.opened = ""
                root.stage = 4
                interval = 40
            } else if (root.stage === 4) {
                root.check(status.popupReveal > 0 && status.popupReveal < 1, "exit is animated")
                status.opened = "audio"
                root.stage = 5
                interval = 200
            } else {
                    root.check(status.popupReveal === 1 && root.popup.visible, "interrupted close reopens")
                    theme.animationsEnabled = false
                    status.opened = "audio"
                    root.check(status.popupReveal === 1, "instant open")
                    status.opened = ""
                    root.check(status.popupReveal === 0 && !root.popup.visible, "instant close")
                    console.log("STATUS_POPUP_SMOKE_PASS")
                    Qt.quit()
            }
        }
    }
}
