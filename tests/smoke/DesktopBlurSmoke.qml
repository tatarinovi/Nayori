import QtQuick
import Quickshell
import "services/canvas"
import "services/niri"
import "services/settings"
import "surfaces/canvas"

ShellRoot {
    id: test
    property int phase: 0
    property int attempts: 0
    SettingsService { id: store }
    OverviewBlur { id: cache }
    DesktopBlur { id: first; outputName: "DP-1"; settings: store.values }
    DesktopBlur { id: second; outputName: "DP-2"; settings: store.values }
    StaticRenderer {
        id: renderer
        width: 100; height: 80
        source: Qt.resolvedUrl("assets/wallpapers/nayori.png")
        mode: "center"
        backgroundColor: "black"
        blurFrame: ({path: "/does-not-exist.png", originalSize: [600, 400]})
        blurOpacity: first.blurOpacity
    }
    function check(ok, message) {
        if (!ok) { console.error("DESKTOP_BLUR_FAIL " + message); Qt.exit(1) }
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            test.attempts++
            test.check(test.attempts < 150, "timeout")
            if (!store.ready) return
            if (Quickshell.env("NAYORI_BLUR_RESTORE") === "1") {
                test.check(store.values.desktopBlurIntensity === 80 && store.values.desktopDimIntensity === 25
                    && store.values.desktopBlurDuration === 150, "persisted values restored")
                console.log("DESKTOP_BLUR_SMOKE_PASS restore")
                Qt.quit()
                return
            }
            if (test.phase === 0) {
                if (!renderer.loaded) return
                test.check(store.values.desktopBlurEnabled && store.values.desktopBlurIntensity === 45
                    && store.values.desktopDimIntensity === 15 && store.values.desktopBlurDuration === 300, "defaults")
                test.check(store.normalize("desktopBlurIntensity", NaN) === 45
                    && store.normalize("desktopBlurDuration", 900) === 600
                    && store.normalize("desktopDimIntensity", -1) === 0, "normalization")
                cache.applyPayload({outputs: {"DP-1": {ok: true, pointer: "/first.png", source: "file:///first", originalSize: [800, 600]}}})
                cache.applyPayload({outputs: {"DP-1": {ok: true, pointer: "/second.png", source: "file:///second", originalSize: [900, 600]}}})
                test.check(cache.frame("DP-1", "file:///first").path === "/first.png"
                    && cache.frame("DP-1", "file:///second").path === "/second.png"
                    && cache.frame("DP-1", "file:///preview") === null, "source-matched cache during dissolve")
                cache.revert("DP-1", "/second.png")
                test.check(cache.frame("DP-1", "file:///first").path === "/first.png", "failed decode rollback")
                Niri._available = true
                Niri.applyWorkspaces({workspaces: [
                    {id: 1, idx: 1, output: "DP-1", is_active: true},
                    {id: 2, idx: 2, output: "DP-1"},
                    {id: 3, idx: 1, output: "DP-2", is_active: true}
                ]}, Niri._streamEpoch)
                Niri.applyWindows({windows: []}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 1) {
                test.check(!first.occupied && !second.occupied, "empty desktop")
                Niri.applyWindowOpenedOrChanged({window: {id: 10, workspace_id: 1}}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 2) {
                test.check(first.occupied && !second.occupied, "per-output first window")
                if (first.blurOpacity < 0.44) return
                test.check(Math.abs(first.dimOpacity - 0.15) < 0.01, "dim default")
                Niri.applyWorkspaceActivated({id: 2, focused: true}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 3) {
                test.check(!first.occupied, "workspace switch")
                // Retarget an in-flight fade, then close and reopen in one event batch.
                Niri.applyWorkspaceActivated({id: 1, focused: true}, Niri._streamEpoch)
                Niri.applyWindowClosed({id: 10}, Niri._streamEpoch)
                Niri.applyWindowOpenedOrChanged({window: {id: 11, workspace_id: 1}}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 4) {
                test.check(first.occupied, "rapid retarget")
                first.reduceMotion = true
                store.update({desktopBlurIntensity: 80, desktopDimIntensity: 25, desktopBlurDuration: 150})
                test.phase++
            } else if (test.phase === 5) {
                test.check(first.blurOpacity === 0.8 && first.dimOpacity === 0.25, "live settings/motion off")
                Niri.dropStream("fixture disconnect")
                test.phase++
            } else if (test.phase === 6) {
                test.check(first.occupied && first.blurOpacity === 0.8, "disconnect retains state")
                Niri._available = true
                Niri.applyWorkspaces({workspaces: [{id: 1, idx: 1, output: "DP-1", is_active: true}]}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 7) {
                test.check(first.occupied, "partial reconnect retains state")
                Niri.applyWindows({windows: []}, Niri._streamEpoch)
                test.phase++
            } else if (test.phase === 8) {
                test.check(!first.occupied && first.blurOpacity === 0 && first.dimOpacity === 0, "last window removed")
                test.check(renderer.loaded && !renderer.failed, "cache failure keeps sharp image")
                const image = renderer.children.find(child => child.objectName === "wallpaper-blur-image")
                test.check(image.opacity === 0, "failed cache hidden")
                renderer.blurFrame = {path: decodeURIComponent(String(Qt.resolvedUrl("assets/wallpapers/nayori.png"))).replace(/^file:\/\//, ""), originalSize: [600, 400]}
                test.phase++
            } else if (test.phase === 9) {
                const image = renderer.children.find(child => child.objectName === "wallpaper-blur-image")
                if (image.status !== Image.Ready) return
                test.check(image.width === 600 && image.height === 400, "native center size")
                renderer.mode = "fit"
                test.phase++
            } else if (test.phase === 10) {
                const image = renderer.children.find(child => child.objectName === "wallpaper-blur-image")
                test.check(image.width === 100 && image.height === 80 && image.fillMode === Image.PreserveAspectFit, "fit mode")
                store.flush(false)
                test.phase++
            } else if (!store.saving && !store.dirty) {
                console.log("DESKTOP_BLUR_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
