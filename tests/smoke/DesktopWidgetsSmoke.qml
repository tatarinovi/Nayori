pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens"
import "services/settings"
import "surfaces/settings"
import "surfaces/desktop"

ShellRoot {
    id: test
    property int phase: 0
    property bool editing: false
    property var lastEdited: null
    function check(ok, message) {
        if (!ok) { console.error("DESKTOP_WIDGET_FAIL " + message); Qt.exit(1) }
    }
    Tokens { id: theme }
    SettingsService { id: store; storageDirectory: Quickshell.env("NAYORI_WIDGETS_TEST_DIR") }
    FloatingWindow {
        visible: true; implicitWidth: 720; implicitHeight: 720
        WidgetsPage {
            id: page
            width: 680; tokens: theme
            screens: ["DP-1", "HDMI-1"]
            desktopWidgets: store.desktopWidgets
            editing: test.editing
            onEditModeChanged: on => test.editing = on
            onLayoutEdited: layout => store.update({desktopWidgets: layout})
        }
    }
    Timer {
        interval: 200; running: true; repeat: true
        onTriggered: {
            if (!store.ready) return
            if (test.phase === 0 && Quickshell.env("NAYORI_WIDGETS_RESTORE") === "1") {
                test.check(store.desktopWidgets["DP-1"].items[1].text === "Пример заметки", "note restored")
                test.check(store.desktopWidgets["HDMI-1"].snap === false, "second screen restored")
                test.check(store.desktopWidgets["DP-1"].items[0].size === "huge", "large clock size restored")
                console.log("DESKTOP_WIDGET_RESTORE_PASS")
                Qt.quit()
            } else if (test.phase === 0) {
                test.check(page.activeScreen === "DP-1", "screen selected")
                test.check(page.currentItems.length === 0, "initial empty")
                page.addWidget("clock", "large", "plain")
                page.addWidget("note", "compact", "card")
                test.check(store.desktopWidgets["DP-1"].items.length === 2, "add persists")
                const first = store.desktopWidgets["DP-1"].items[0].id
                page.updateItem(first, 0, "size", "compact")
                test.check(store.desktopWidgets["DP-1"].items[0].size === "compact", "size persists")
                page.updateItem(first, 0, "size", "huge")
                test.check(store.desktopWidgets["DP-1"].items[0].size === "huge", "large clock size persists")
                page.toggleEditing()
                test.check(test.editing, "arrangement mode enabled")
            } else if (test.phase === 1) {
                const id = store.desktopWidgets["DP-1"].items[1].id
                page.updateItem(id, 1, "text", "Пример заметки")
                test.check(store.desktopWidgets["DP-1"].items[1].text === "Пример заметки", "note persists")
                page.selectedScreen = "HDMI-1"
                page.addWidget("weather", "compact", "card")
                test.check(store.desktopWidgets["DP-1"].items.length === 2 && store.desktopWidgets["HDMI-1"].items.length === 1, "separate screens")
                page.setSnap(false)
                test.check(!store.desktopWidgets["HDMI-1"].snap, "snap persisted")
                store.flush(false)
            } else if (test.phase === 2 && !store.dirty && !store.saving) {
                console.log("DESKTOP_WIDGET_PASS")
                Qt.quit()
            } else if (test.phase > 20) {
                test.check(false, "settings did not finish saving")
            }
            test.phase++
        }
    }
}
