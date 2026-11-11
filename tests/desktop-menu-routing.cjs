// Exercise the real QML handoff with the drawer initially closed, including
// re-entry while another catalogue is already selected on another monitor.
const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")
const shell = fs.readFileSync("surfaces/ShellSession.qml", "utf8")
const handler = shell.match(/onWallpaperRequested:\s*\{([^}]+)\}/)
assert.ok(handler, "wallpaper menu handoff exists")
for (const alreadyEditing of [false, true]) {
    const context = {
        desktopOutput: {modelData: {name: "HDMI-1"}},
        desktopStage: {
            monitor: "DP-1", section: "widgets",
            enterWidgets(monitor, section) { this.monitor = monitor; this.section = section },
        },
        settingsController: {widgetsEditing: alreadyEditing},
        desktopInput: {
            catalogOpen: false,
            openCatalog(section) {
                assert.equal(context.settingsController.widgetsEditing, true, "editor enabled before opening drawer")
                context.desktopStage.section = section
                this.catalogOpen = true
            },
        },
    }
    vm.runInNewContext(handler[1], context)
    assert.equal(context.desktopStage.monitor, "HDMI-1", "use clicked monitor")
    assert.equal(context.desktopStage.section, "wallpaper", "select wallpaper section")
    assert.equal(context.desktopInput.catalogOpen, true, "show wallpaper drawer, including re-entry")
}
console.log("DESKTOP_MENU_ROUTING_PASS")
