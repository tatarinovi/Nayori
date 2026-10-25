import QtQuick
import Quickshell
import "services/canvas"
import "surfaces/canvas"
import "surfaces/settings"
import "tokens"

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    property bool prepared: false
    property var sources: [Qt.resolvedUrl("assets/wallpapers/nayori.png"), "file:///tmp/nayori-canvas-test.jpg", "file:///tmp/nayori-canvas-test.webp"]
    property var modes: ["fill", "fit", "stretch", "center"]
    function check(ok, reason) { if (!ok) throw new Error(reason) }
    Tokens { id: tokens }
    WallpaperManager { id: manager; storageDirectory: Quickshell.env("NAYORI_CANVAS_TEST_DIR") || "/tmp/nayori-canvas-smoke" }
    WallpaperManager { id: restored; storageDirectory: manager.storageDirectory + "-restore" }
    StaticRenderer { id: renderer; width: 640; height: 360; source: root.sources[0]; mode: "fill"; backgroundColor: tokens.color.background }
    Settings { tokens: tokens; wallpaperManager: manager; currentPage: 4 }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            try {
                root.ticks++
                root.check(root.ticks < 100, "timeout")
                if (!manager.ready || !restored.ready) return
                if (root.stage < 12) {
                    if (!root.prepared) {
                        renderer.source = root.sources[Math.floor(root.stage / 4)]
                        renderer.mode = root.modes[root.stage % 4]
                        root.prepared = true
                        return
                    }
                    if (!renderer.loaded) return
                    root.check(!renderer.failed, "decode")
                    root.prepared = false
                    root.stage++
                } else if (root.stage === 12) {
                    manager.apply("DP-1", String(root.sources[1]), "fit", false, true)
                    root.stage++
                } else if (root.stage === 13 && !manager.saving) {
                    root.check(manager.message === "Обои сохранены.", "save")
                    restored.file.path = manager.storageDirectory + "/canvas.json"
                    restored.file.reload()
                    root.stage = 16
                } else if (root.stage === 16 && restored.state.shared === false) {
                    root.check(restored.wallpaper("DP-1").mode === "fit", "restore output")
                    root.check(restored.wallpaper("DP-2").source === String(manager.defaultSource), "new output fallback")
                    manager.apply("DP-2", String(root.sources[2]), "center", true, true)
                    root.stage = 14
                } else if (root.stage === 14 && !manager.saving) {
                    root.check(manager.wallpaper("DP-1").mode === "center", "shared")
                    renderer.source = "file:///tmp/nayori-canvas-does-not-exist.png"
                    root.stage++
                } else if (root.stage === 15 && renderer.failed) {
                    console.log("CANVAS_SMOKE_PASS: PNG JPG WebP, four modes, save, restore, shared/output fallback, missing image, Settings page")
                    Qt.quit()
                }
            } catch (error) { console.error("CANVAS_SMOKE_FAIL", error); Qt.quit() }
        }
    }
}
