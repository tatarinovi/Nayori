pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "services/shelf"
import "services/clipboard"

ShellRoot {
    id: root
    ClipboardService { id: clipboardStore; enabled: false }
    ShelfService { id: shelf; clipboard: clipboardStore }
    TestCase {
        id: tests
        when: false
        function run() {
            try {
                // Fake wl-paste/wl-copy supplied by check-shelf.sh; no clipboard watchers.
                clipboardStore.worker.command = ["python3", "-u", Qt.resolvedUrl("services/clipboard/clipboard_store.py").toString().replace("file://", ""), "--no-watch"]
                clipboardStore.worker.running = true
                tryCompare(clipboardStore, "ready", true)
                tryCompare(shelf, "ready", true)
                shelf.paste()
                tryVerify(() => shelf.items.length === 1)
                compare(shelf.items[0].text, "Текст из текущего буфера")
                verify(!shelf.pastePending)
                shelf.copy(shelf.items[0])
                tryCompare(shelf, "copyPending", false)
                compare(shelf.status, "Скопировано")
                console.log("SHELF_CLIPBOARD_PASS")
                Qt.quit()
            } catch (failure) { console.error("SHELF_CLIPBOARD_FAIL", failure, failure.stack); Qt.exit(1) }
        }
    }
    Timer { interval: 100; running: true; onTriggered: tests.run() }
}
