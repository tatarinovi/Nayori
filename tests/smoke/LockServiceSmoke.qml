import QtQuick
import Quickshell
import "tokens"
import "services/lock"
import "services/niri"

ShellRoot {
    id: root
    Tokens { id: tokens }
    QtObject {
        id: wallpaper
        function wallpaper(name) { return { source: "", mode: "fill" } }
    }
    QtObject {
        id: music
        property var player: null
        function consumer(key, active) {}
    }
    LockService {
        id: service
        tokens: tokens
        wallpapers: wallpaper
        music: music
        systemIntegration: false
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            if (service.locked || service.secure) throw new Error("test must not acquire a lock")
            service.submit("discarded-preview-input")
            if (service.secret !== "") throw new Error("unexpected password retained")
            service.closePreview()
            if (service.previewing) throw new Error("preview did not close")
            Niri.applyEvent({KeyboardLayoutsChanged: {keyboard_layouts: {names: ["English (US)", "Russian"], current_idx: 0}}}, Niri._streamEpoch)
            if (Niri.keyboardLayout !== "English (US)") throw new Error("initial keyboard layout")
            Niri.applyEvent({KeyboardLayoutSwitched: {idx: 1}}, Niri._streamEpoch)
            if (Niri.keyboardLayout !== "Russian") throw new Error("layout switch event")
            console.log("LOCK_SERVICE_SMOKE_PASS")
            Qt.quit()
        }
    }
}
