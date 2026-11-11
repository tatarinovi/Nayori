import QtQuick
import Quickshell
import "services/startup"
import "services/settings"
import "surfaces/startup"
import "surfaces/canvas"
import "tokens"

ShellRoot {
    id: root
    property int stage: 0
    property int ticks: 0
    function check(value, message) { if (!value) throw new Error(message) }
    SettingsService { id: preferences; storageDirectory: Quickshell.env("XDG_CONFIG_HOME") + "/nayori" }
    StartupCache { id: appearanceCache }
    StartupCache { id: corruptCache; directory: appearanceCache.directory + "-corrupt" }
    StartupCache { id: absentCache; directory: appearanceCache.directory + "-absent" }
    Tokens { id: theme }
    StartupState { id: barrier; outputs: ["DP-1", "DP-2"]; warningDelay: 180 }
    StartupState { id: disabled; enabled: false }
    StartupState { id: instantBarrier; outputs: ["silent"]; stalled: true }
    StartupState { id: blocked; outputs: ["blocked"]; warningDelay: 40 }
    FloatingWindow {
        id: preview
        visible: true
        implicitWidth: 1100; implicitHeight: 760
        StartupArtwork { id: art; anchors.fill: parent; tokens: theme }
        FirstFrame { id: first; armed: true }
    }
    WallpaperCrossfade {
        id: wallpaper
        width: 400; height: 300
        source: "file:///tmp/nayori-startup-missing.png"
        mode: "fill"; backgroundColor: theme.color.background
        reduceMotion: true; duration: 0; managerReady: true
    }
    // Real window fade lifecycle on an offscreen output; controller receipts
    // use fixture output names so two windows exercise the global barrier.
    FloatingWindow {
        visible: true; implicitWidth: 640; implicitHeight: 480
        StartupCover { id: cover1; anchors.fill: parent; startup: barrier; tokens: theme; outputName: "DP-1"; fadeDuration: 120 }
    }
    FloatingWindow {
        visible: true; implicitWidth: 640; implicitHeight: 480
        StartupCover { id: cover2; anchors.fill: parent; startup: barrier; tokens: theme; outputName: "DP-2"; fadeDuration: 120 }
    }
    FloatingWindow {
        visible: root.stage >= 4; implicitWidth: 640; implicitHeight: 480
        StartupCover { id: instant; anchors.fill: parent; startup: instantBarrier; tokens: theme; outputName: "silent" }
    }
    Timer {
        interval: 30; running: true; repeat: true
        onTriggered: {
            try {
                root.check(++root.ticks < 150, "timeout at stage " + root.stage)
                if (root.stage === 0) {
                    if (!preferences.ready || !appearanceCache.ready || !corruptCache.ready || !absentCache.ready || !first.seen || !wallpaper.startupReady || !barrier.stalled) return
                    root.check(wallpaper.fore().failed, "failed wallpaper uses opaque fallback")
                    root.check(barrier.present && !barrier.releasing, "deadline must not dismiss")
                    root.check(blocked.stalled && blocked.present, "blocked component stays explainable")
                    root.check(preferences.values.startupSplashFadeDuration === 500, "fade duration clamped")
                    root.check(preferences.values.startupSplashEnabled, "invalid enabled uses default")
                    preferences.update({startupSplashEnabled: false, startupSplashDynamicAccent: false, startupSplashFadeDuration: 0})
                    preferences.flush(true)
                    root.check(appearanceCache.snapshot.accent === "#679AC8", "read palette before first splash")
                    root.check(corruptCache.snapshot.accent === "#C0AFD1" && absentCache.snapshot.accent === "#C0AFD1", "cache errors use fallback")
                    appearanceCache.publish({version: 1, accent: "#E8AA70", enabled: true, dynamicAccent: true,
                        fadeDuration: 220, animationsEnabled: true})
                    root.check(appearanceCache.snapshot.accent === "#679AC8", "publishing never changes boot snapshot")
                    disabled.settingsReady = true
                    root.check(!disabled.present, "disabled after settings load")
                    barrier.settingsReady = true
                    barrier.servicesReady = true
                    barrier.report("DP-1", "wallpaper", true)
                    barrier.report("DP-1", "panels", true)
                    barrier.report("DP-2", "wallpaper", true)
                    root.check(!barrier.ready, "second output panels still missing")
                    barrier.report("DP-2", "panels", true)
                    root.stage++
                } else if (root.stage === 1) {
                    if (!barrier.releasing) return
                    root.check(cover1.reveal > 0, "fade retains cover")
                    // Hotplug during fade cancels completion until new output reports.
                    barrier.outputs = ["DP-1", "DP-2", "HDMI-A-1"]
                    root.check(!barrier.releasing && barrier.present, "hotplug cancels release")
                    root.stage++
                } else if (root.stage === 2) {
                    if (cover1.reveal !== 1) return
                    // Disconnect the unfinished screen; no stale output can block.
                    barrier.outputs = ["DP-1", "DP-2"]
                    root.check(barrier.releasing, "removed output stops blocking")
                    root.stage++
                } else if (root.stage === 3) {
                    if (barrier.present) return
                    root.check(cover1.reveal === 0 && cover2.reveal === 0, "all fades finished before teardown")
                    blocked.dismiss()
                    root.check(blocked.releasing, "explicit continue after timeout")
                    const before = String(art.ground)
                    theme.accentDerived = true
                    theme.accentSource = "#E8AA70"
                    root.check(String(art.accent) === String(theme.color.accent) && String(art.ground) !== String(before), "accent tints logo and background")
                    art.splashAccent = appearanceCache.snapshot.accent
                    const frozenGround = String(art.ground)
                    theme.accentSource = "#70B8A0"
                    root.check(String(art.accent) === "#679ac8" && String(art.ground) === frozenGround, "visible splash palette stays frozen")
                    theme.animationsEnabled = false
                    first.armed = false
                    root.check(!first.seen, "frame receipt invalidated")
                    first.armed = true
                    root.stage++
                } else if (root.stage === 4) {
                    if (!first.seen) return
                    instantBarrier.dismiss()
                    root.check(instant.reveal === 0 && !instantBarrier.present, "reduced motion exits immediately")
                    if (Quickshell.env("NAYORI_SPLASH_PREVIEW")) {
                        art.grabToImage(result => {
                            result.saveToFile(Quickshell.env("NAYORI_SPLASH_PREVIEW"))
                            console.log("STARTUP_SPLASH_PASS")
                            Qt.quit()
                        })
                        root.stage++
                    } else { console.log("STARTUP_SPLASH_PASS"); Qt.quit() }
                }
            } catch (error) { console.error("STARTUP_SPLASH_FAIL", error); Qt.quit() }
        }
    }
}
