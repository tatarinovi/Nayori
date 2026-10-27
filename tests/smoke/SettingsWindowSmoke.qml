pragma ComponentBehavior: Bound
//@ pragma AppId nayori-settings-test
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "tokens"
import "services/settings"
import "services/canvas"
import "services/niri"
import "surfaces/settings"

ShellRoot {
    id: test
    readonly property bool waylandTest: Quickshell.env("NAYORI_WINDOW_WAYLAND") === "1"
    property int step: 0
    Tokens { id: theme }
    SettingsService { id: service; storageDirectory: Quickshell.env("NAYORI_SETTINGS_DIR") }
    WallpaperManager { id: wallpaper; storageDirectory: Quickshell.env("NAYORI_SETTINGS_DIR") }
    QtObject {
        id: fakeNiri
        property bool available: true
        property var windows: []
        property int lastFocused: -1
        function focusWindow(id) { lastFocused = id }
    }
    SettingsController {
        id: controller
        tokens: theme
        settingsService: service
        wallpaperManager: wallpaper
        niri: test.waylandTest ? Niri : fakeNiri
    }
    function check(ok, message) { if (!ok) { console.error("WINDOW_FAIL " + message); Qt.exit(1) } }
    IpcHandler {
        target: "settings"
        function open(): bool { return controller.open() }
        function openPage(page: string): bool { return controller.openPage(page) }
        function close(): void { controller.close() }
        function snapshot(): string {
            return JSON.stringify({opened: controller.opened, id: controller.windowId,
                pid: Quickshell.processId, page: controller.window ? controller.window.selectedPage : -1,
                city: service.weatherCity, dirty: service.dirty,
                usageReady: controller.usage.ready,
                usageDirty: controller.usage.dirty || controller.usage.saving})
        }
        function quit(): void { Qt.quit() }
    }
    Timer {
        interval: 100
        repeat: true
        running: !test.waylandTest
        onTriggered: {
            if (!service.ready || !wallpaper.ready) return
            if (test.step === 0) {
                test.check(controller.open(), "create window")
                test.check(controller.openPage("weather"), "select weather")
                test.check(!controller.openPage("missing"), "reject unknown page")
                test.check(controller.window.selectedPage === 3, "section mapping")
                // A foreign PID with the exact same title and app_id must never be selected.
                fakeNiri.windows = [{id: 11, pid: Quickshell.processId + 1, appId: Quickshell.appId, title: "Nayori Settings"}]
                test.check(controller.windowId === -1 && fakeNiri.lastFocused === -1, "reject foreign process")
                fakeNiri.windows = fakeNiri.windows.concat([{id: 12, pid: Quickshell.processId, appId: Quickshell.appId, title: "Nayori Settings"}])
                test.check(controller.windowId === 12 && fakeNiri.lastFocused === 12, "register exact identity")
            } else if (test.step === 1) {
                // Offscreen Qt does not guarantee a native QQuickWindow.
                // The --wayland Python test checks compositor-driven native close.
                controller.window.closeRequested()
                test.check(!controller.opened && controller.windowId === -1, "close request clears identity")
                service.update({weatherCity: "Closed window"})
            } else if (test.step === 2) {
                const old = controller.window
                test.check(controller.open() && controller.window === old, "reuse QML surface")
                test.check(controller.windowId === -1, "retired Niri ID must not be reused")
                fakeNiri.windows = [{id: 13, pid: Quickshell.processId, appId: Quickshell.appId, title: "Nayori Settings"}]
                test.check(controller.windowId === 13, "new native window identity")
                controller.close()
                controller.window.destroy()
            } else if (test.step === 3) {
                test.check(controller.window === null && !controller.opened, "destroyed object invalidates controller")
                test.check(controller.open(), "recreate destroyed surface")
                test.check(controller.window.weatherCity === "Closed window", "current service state on recreation")
                controller.close()
            } else if (test.step > 5) {
                test.check(!service.dirty, "save while closed")
                console.log("SETTINGS_WINDOW_PASS")
                Qt.quit()
            }
            test.step++
        }
    }
}
