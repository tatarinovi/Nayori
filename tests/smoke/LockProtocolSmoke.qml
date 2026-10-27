import QtQuick
import Quickshell
import "tokens"
import "services/lock"
import "surfaces/lock"

// Run ONLY through tests/lock-protocol.py, inside its disposable compositor.
ShellRoot {
    id: root
    property int ticks: 0
    property bool verified: false
    property bool sawExit: false
    property bool sawPreparedReveal: false
    property bool sawDesktopReveal: false
    property bool watchedBefore: false
    Component.onCompleted: watchedBefore = Quickshell.watchFiles
    Tokens { id: themeTokens }
    SessionEntrance { id: entrance; tokens: themeTokens; ready: true }
    QtObject {
        id: walls
        function wallpaper(output) { return {source: Qt.resolvedUrl("assets/wallpapers/nayori.png"), mode: "fill"} }
    }
    QtObject {
        id: musicModel
        property var player: null
        function consumer(key, active) {}
    }
    LockService {
        id: service
        tokens: themeTokens
        wallpapers: walls
        music: musicModel
        systemIntegration: false
    }
    Connections {
        target: service
        function onUnlockingChanged() {
            if (service.unlocking) {
                if (!service.locked || !service.secure) throw new Error("exit animation exposed the session")
                root.sawExit = true
            }
        }
        function onRevealStageChanged() {
            if (service.revealStage === 2) {
                if (!service.locked || !service.secure) throw new Error("reveal prepared after lock was released")
                if (!Quickshell.screens.every(screen => service.revealShots[screen.name])) throw new Error("lock frame was not captured")
                root.sawPreparedReveal = true
            }
            if (service.revealStage === 3) {
                if (service.locked || !root.sawPreparedReveal) throw new Error("desktop revealed before preparation")
                if (!Quickshell.screens.every(screen => service.revealReady[screen.name])) throw new Error("desktop revealed before output was ready")
                root.sawDesktopReveal = true
            }
        }
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            const runtime = Quickshell.env("XDG_RUNTIME_DIR")
            const socket = Quickshell.env("NIRI_SOCKET") || ""
            if (Quickshell.env("NAYORI_LOCK_NESTED_TEST") !== "1" || !runtime.includes("nayori-lock-protocol-") || !socket.startsWith(runtime + "/")) {
                throw new Error("Refusing to lock outside the disposable compositor")
            }
            if (++root.ticks === 2) {
                if (entrance.running) throw new Error("desktop entrance did not finish")
                service.lock()
            }
            if (root.ticks > 25) throw new Error("ext-session-lock was not confirmed")
            if (service.secure && !root.verified) {
                if (Quickshell.watchFiles) throw new Error("file reload must be paused while locked")
                root.verified = true
                service.preview()
                service.closePreview()
                if (!service.secure || !service.locked || service.previewing) throw new Error("preview bypassed real lock")
                service.primaryOutput = "disconnected-output"
                if (service.mainOutput !== Quickshell.screens[0].name) throw new Error("primary fallback")
                service.submit("nayori-test-only")
            } else if (root.verified && !service.busy && service.secret === "") {
                if (Quickshell.env("NAYORI_LOCK_TEST_ALLOW") === "1") {
                    if (service.locked) return
                    if (!root.sawExit) throw new Error("missing authenticated exit animation")
                    if (service.revealStage !== 0) return
                    if (!root.sawPreparedReveal || !root.sawDesktopReveal) throw new Error("missing desktop reveal")
                    if (Quickshell.watchFiles !== root.watchedBefore) throw new Error("file reload setting not restored")
                } else {
                    if (!service.status.startsWith("Не удалось разблокировать")) return
                    if (!service.locked || !service.secure) throw new Error("PAM failure unlocked the session")
                }
                console.log("LOCK_PROTOCOL_PASS")
                // Ending this client leaves ONLY the nested compositor locked.
                // The parent test then destroys that compositor.
                Qt.quit()
            }
        }
    }
}
