pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens"
import "services/keybinds"
import "surfaces/settings"

ShellRoot {
    id: test
    property int step: 0
    property int attempts: 0
    property int saves: 0
    Tokens { id: theme }
    QtObject {
        id: settings
        property var values: ({superTapEnabled: true})
        function update(patch) { values = Object.assign({}, values, patch) }
    }
    KeybindService { id: keybindBackend; settingsService: settings }
    Connections { target: keybindBackend; function onSaved() { test.saves++ } }
    FloatingWindow {
        id: window
        visible: true
        width: 1000
        height: 900
        Flickable {
            anchors.fill: parent
            contentHeight: page.implicitHeight
            clip: true
            ShortcutsPage { id: page; width: parent.width; tokens: theme; service: keybindBackend }
        }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function check(condition, message) {
        if (!condition) { console.error("KEYBINDS_FAIL " + message); Qt.exit(1) }
    }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (++test.attempts > 180) { test.check(false, "timeout " + test.step + " " + keybindBackend.error); return }
            if (!keybindBackend.ready || keybindBackend.busy) return
            if (test.step === 0) {
                test.check(keybindBackend.rows.some(row => row.title === "Terminal"), "Niri rows")
                const search = test.find(page, "keybindSearch")
                test.check(!!search, "search exists")
                search.text = "Terminal"
                test.check(page.shown.length === 1, "instant action search")
                search.text = "Mod+Return"
                test.check(page.shown.length === 1, "key search")
                search.text = ""
                page.source = "Nayori"
                test.check(page.shown.every(row => row.source === "Nayori"), "source filter")
                page.source = ""
                page.category = "Apps"
                test.check(page.shown.every(row => row.category === "Apps"), "category filter")
                page.category = ""
                keybindBackend.toggleSuper()
                test.check(keybindBackend.nativeRow.enabled === false, "native preference")
                keybindBackend.toggleSuper()
                page.edit(keybindBackend.rows.find(row => row.title === "Terminal"))
                test.step = 1
            } else if (test.step === 1) {
                const editor = page.editorObject
                test.check(editor.opened, "editor opens")
                const keys = test.find(editor.contentItem, "keybindKeys")
                test.check(!!keys, "record field")
                keys.text = "Super+F10"
                test.check(editor.change().keys === "Super+F10", "draft stays local")
                test.check(keybindBackend.rows.some(row => row.keys === "Mod+Return"), "not saved until confirm")
                editor.submitted(editor.change())
                test.step = 2
            } else if (test.step === 2 && test.saves === 1 && keybindBackend.rows.some(row => row.keys === "Super+F10")) {
                test.check(!page.editorObject.visible, "save closes editor")
                keybindBackend.apply({operation: "create", keys: "Super+F11", title: "Smoke command", kind: "command", value: "touch /never-run-by-editor", category: "Custom"})
                test.step = 3
            } else if (test.step === 3 && test.saves === 2 && keybindBackend.rows.some(row => row.custom)) {
                const row = keybindBackend.rows.find(row => row.custom)
                keybindBackend.apply({operation: "toggle", id: row.id})
                test.step = 4
            } else if (test.step === 4 && test.saves === 3 && keybindBackend.rows.some(row => row.custom && !row.enabled)) {
                const row = keybindBackend.rows.find(row => row.custom)
                keybindBackend.apply({operation: "delete", id: row.id})
                test.step = 5
            } else if (test.step === 5 && test.saves === 4 && !keybindBackend.rows.some(row => row.custom)) {
                test.check(keybindBackend.error === "", keybindBackend.error)
                console.log("KEYBINDS_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
