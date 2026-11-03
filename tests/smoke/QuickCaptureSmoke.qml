pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/quickcapture"
import "services/settings"
import "surfaces/island"

ShellRoot {
    id: root
    property int saves: 0
    Tokens { id: theme; animationsEnabled: false }
    SettingsService { id: config }
    QuickCaptureService { id: store; settings: config; onSaved: root.saves++ }
    FloatingWindow {
        visible: true
        implicitWidth: 740
        implicitHeight: 550
        MorphingIsland {
            id: island
            anchors.centerIn: parent
            tokens: theme
            testMode: true
            quickCaptureService: store
            quickCaptureOpen: true
            onCloseRequested: expanded = false
        }
        TestCase {
            id: checks
            name: "QuickCapture"
            when: false
            function run() {
                try { check() }
                catch (failure) { console.error("QUICK_CAPTURE_SMOKE_FAIL", failure, failure.stack); Qt.exit(1) }
            }
            function check() {
                tryCompare(config, "ready", true)
                compare(config.values.quickCaptureEnabled, false)
                compare(config.normalize("quickCaptureWorkPath", "../outside"), "Inbox/Work")
                compare(config.normalize("quickCapturePersonalPath", "/outside"), "Inbox/Personal")
                compare(config.normalize("quickCaptureContext", "invalid"), "Work")
                tryCompare(store, "ready", true)
                island.expanded = true
                island.focusCapture()
                const loader = findChild(island, "islandDashboardLoader")
                tryVerify(() => !!loader.item)
                const input = findChild(loader.item, "quickCaptureInput")
                tryCompare(input, "activeFocus", true)
                const hint = findChild(loader.item, "quickCaptureConfigurationHint")
                verify(hint.visible, "setup hint inside Inbox when disabled")
                input.insert(0, "Черновик до настройки")
                tryCompare(store, "status", "Черновик сохранён")
                keyClick(Qt.Key_Return)
                compare(store.busy, false)
                compare(root.saves, 0)
                compare(input.text, "Черновик до настройки")
                verify(store.error !== "")
                config.update({quickCaptureEnabled: true, quickCaptureContext: "Personal"})
                verify(hint.visible, "empty Vault keeps setup hint in Inbox")
                verify(hint.text.indexOf("Vault") >= 0)
                verify(input.activeFocus)
                input.remove(0, input.length)
                config.update({quickCaptureVault: Quickshell.env("NAYORI_TEST_VAULT")})
                compare(hint.visible, false)
                compare(store.context, "Personal")
                input.insert(0, "Первая строка 🦊")
                input.cursorPosition = input.length
                keyClick(Qt.Key_Return, Qt.ShiftModifier)
                compare(input.text, "Первая строка 🦊\n")
                input.insert(input.length, "日本語")
                compare(store.text, input.text)
                keyClick(Qt.Key_Return)
                store.save()
                tryCompare(root, "saves", 1)
                compare(input.text, "")
                verify(store.lastUri.indexOf("obsidian://open?path=") === 0)
                store.context = "Work"
                input.insert(0, "Рабочая заметка")
                store.save()
                verify(store.busy)
                verify(input.readOnly)
                store.save()
                tryCompare(root, "saves", 2)
                config.update({quickCaptureVault: "/missing/nayori-vault"})
                input.insert(0, "Не терять при ошибке")
                keyClick(Qt.Key_Return)
                tryCompare(store, "busy", false)
                verify(store.error !== "")
                compare(input.text, "Не терять при ошибке")
                keyClick(Qt.Key_Escape)
                compare(island.expanded, false)
                theme.animationsEnabled = true
                island.expanded = true
                island.focusCapture()
                tryVerify(() => !!loader.item)
                const restored = findChild(loader.item, "quickCaptureInput")
                tryCompare(restored, "activeFocus", true)
                compare(restored.text, "Не терять при ошибке")
                island.focusCapture()
                compare(restored.activeFocus, true)
                tryCompare(loader.item, "pagePosition", 2)
                tryCompare(island, "progress", 1)
                island.grabToImage(result => result.saveToFile("/tmp/nayori-quick-capture.png"))
                wait(100)
                console.log("QUICK_CAPTURE_SMOKE_PASS")
                Qt.quit()
            }
        }
        Timer { interval: 150; running: true; onTriggered: checks.run() }
    }
}
