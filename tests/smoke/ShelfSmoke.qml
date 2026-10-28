pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "services/shelf"
import "services/island"
import "surfaces/island"

ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: false }
    QtObject {
        id: fakeClipboard
        property bool copying: false
        property string error: ""
        property string text: ""
        signal contentReady(var content)
        function readCurrent() { Qt.callLater(() => contentReady({text: "Вставлено из буфера"})); return true }
        signal copied(string identity)
        function copyContent(mime, content) { text = content; copied("") }
    }
    ShelfService { id: store; clipboard: fakeClipboard }
    NotificationModel { id: testNotifications }
    FloatingWindow {
        id: scene
        visible: true
        implicitWidth: 740; implicitHeight: 550
        color: theme.color.background
        MorphingIsland {
            id: island
            anchors.centerIn: parent
            tokens: theme
            testMode: true
            expanded: true
            shelfService: store
            notifications: testNotifications
        }
        TestCase {
            id: tests
            name: "Shelf"
            when: false
            function run() {
                try { check() }
                catch (failure) { console.error("SHELF_SMOKE_FAIL", failure, failure.stack); Qt.exit(1) }
            }
            function check() {
                tryCompare(store, "ready", true)
                const dashboard = findChild(island, "islandDashboardLoader").item
                verify(dashboard)
                compare(dashboard.pageCount, 3)
                dashboard.currentPage = 2
                compare(island.currentPage, 2)
                verify(!island.notificationPage)
                const shelf = findChild(dashboard, "shelfPage")
                verify(shelf.visible)
                verify(findChild(shelf, "shelfEmpty").visible)
                const paste = findChild(shelf, "shelfPaste")
                const input = findChild(shelf, "shelfNewNote")
                compare(input.height, paste.height, "input and buttons share a height")
                tryCompare(store, "busy", false)
                tryCompare(paste, "enabled", true)
                mouseClick(paste)
                tryVerify(() => store.items.length === 1)
                compare(store.items[0].text, "Вставлено из буфера")
                store.remove(store.items[0].id)
                tryCompare(store, "busy", false)
                store.add({text: "Заметка Nayori", note: true})
                tryCompare(store, "busy", false)
                compare(store.items.length, 1)
                const note = store.items[0]
                shelf.selectedId = note.id
                mouseClick(findChild(shelf, "shelfCopy"))
                compare(fakeClipboard.text, "Заметка Nayori")
                shelf.editNote(note)
                verify(shelf.interacting)
                const editor = findChild(shelf, "shelfNoteEditor")
                editor.text = "Изменённая заметка"
                shelf.saveNote()
                tryCompare(store, "busy", false)
                compare(store.items[0].text, "Изменённая заметка")
                store.taken(note.id)
                tryCompare(store, "busy", false)
                compare(store.items.length, 1, "notes survive successful drags")
                store.add({text: "Временный текст"})
                tryCompare(store, "busy", false)
                const loose = store.items[0]
                store.favorite(loose.id)
                tryCompare(store, "busy", false)
                store.taken(loose.id)
                tryCompare(store, "busy", false)
                compare(store.items.length, 2)
                store.favorite(loose.id)
                tryCompare(store, "busy", false)
                wait(30)
                const tile = findChild(shelf, "shelfItem_0")
                verify(tile)
                compare(tile.Drag.mimeData["text/plain"], "Временный текст")
                tile.Drag.dragFinished(Qt.IgnoreAction)
                wait(30)
                compare(store.items.length, 2, "cancelled drag keeps loose items")
                tile.Drag.dragFinished(Qt.CopyAction)
                tryCompare(store, "busy", false)
                compare(store.items.length, 1, "successful native drag takes loose item")
                store.add({urls: ["javascript:invalid"]})
                tryCompare(store, "busy", false)
                verify(store.error.length > 0)
                verify(findChild(shelf, "shelfError").visible)
                store.refresh()
                tryCompare(store, "busy", false)
                compare(store.error, "")
                // New notifications must remain unseen while the Shelf page is open.
                testNotifications.receive({id: 7, appName: "Test", summary: "Title", body: "Body", actions: []})
                compare(island.currentPage, 2)
                verify(!island.notificationPage)
                dashboard.navigateWheel(-120, Date.now())
                compare(dashboard.currentPage, 2, "right boundary")
                dashboard.navigateWheel(120, Date.now() + 1000)
                compare(dashboard.currentPage, 1)
                verify(island.notificationPage)
                dashboard.navigateWheel(120, Date.now() + 2000)
                compare(dashboard.currentPage, 0)
                verify(!island.notificationPage)
                island.currentPage = 2
                compare(dashboard.currentPage, 2, "Shelf is not reset to home by notification bookkeeping")
                island.expanded = false
                wait(100)
                island.expanded = true
                compare(island.currentPage, 1, "unread notification default remains intact")
                island.currentPage = 2
                wait(50)
                island.grabToImage(result => result.saveToFile("/tmp/nayori-shelf-smoke.png"))
                wait(100)
                console.log("SHELF_SMOKE_PASS")
                Qt.quit()
            }
        }
        Timer { interval: 150; running: true; onTriggered: tests.run() }
    }
}
