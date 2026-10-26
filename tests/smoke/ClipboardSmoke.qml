pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import "tokens"
import "surfaces/clipboard"

ShellRoot {
    id: root
    Tokens { id: theme; animationsEnabled: false }
    QtObject {
        id: fixture
        property bool ready: true
        property bool copying: false
        property string error: ""
        property var records: []
        property string lastCopied: ""
        property bool lastPasteRequested: false
        signal copied(string identity)
        function copy(identity, pasteAfter) { lastCopied = identity; lastPasteRequested = pasteAfter === true }
        function pin(identity) { records = records.map(r => Object.assign({}, r, {pinned:r.id === identity ? !r.pinned : r.pinned})) }
        function remove(identity) { records = records.filter(r => r.id !== identity) }
        function clear() { records = [] }
    }
    FloatingWindow {
        id: scene
        visible: true
        implicitWidth: 628; implicitHeight: 568
        color: theme.color.background
        ClipboardPanel {
            id: panel
            x: 24; y: 24; width: 580; height: 520
            tokens: theme
            store: fixture
            property int closes: 0
            onCloseRequested: closes++
        }
        TestCase {
            id: test
            name: "Clipboard"
            when: false
            function run() {
                try { checkBehavior() }
                catch (failure) { console.error("CLIPBOARD_SMOKE_FAIL", failure, failure.stack); Qt.exit(1) }
            }
            function checkBehavior() {
                fixture.records = [
                    {id:"wall",kind:"image",title:"Обои Nayori",text:"",format:"PNG",bytes:123456,width:3344,height:1882,created:Date.now(),pinned:false,image:Qt.resolvedUrl("assets/wallpapers/nayori.png").toString()},
                    {id:"text",kind:"text",title:"Графит, лаванда и немного розы",text:"Графит, лаванда и немного розы\nВсё нужное — рядом",format:"",bytes:75,created:Date.now()-180000,pinned:false,image:""},
                    {id:"fox",kind:"image",title:"Лиса Nayori",text:"",format:"PNG",bytes:12345,created:Date.now()-600000,pinned:true,image:Qt.resolvedUrl("assets/branding/nayori-fox-logo.png").toString()}
                ]
                tryCompare(panel, "selectedId", "wall")
                tryCompare(panel.imagePreview, "status", Image.Ready)
                compare(panel.imagePreview.fillMode, Image.PreserveAspectFit)
                verify(findChild(panel, "clipboardMetadata").text.indexOf("3344 × 1882") >= 0)
                compare(findChild(panel, "clipboardCount").text, "· 3")
                panel.searchInput.forceActiveFocus()
                keyClick(Qt.Key_Down)
                compare(panel.selectedId, "text")
                keyClick(Qt.Key_Return)
                compare(fixture.lastCopied, "text")
                verify(fixture.lastPasteRequested)
                mouseClick(findChild(panel, "clipboardCopy"))
                verify(!fixture.lastPasteRequested)
                mouseDoubleClickSequence(findChild(panel, "clipboardEntry_1"))
                verify(fixture.lastPasteRequested)
                panel.query = "лиса"
                tryCompare(panel, "selectedId", "fox")
                compare(panel.entries.length, 1)
                fixture.pin("fox")
                compare(panel.selected.pinned, false)
                panel.query = ""; panel.filter = "pinned"
                compare(panel.entries.length, 0)
                panel.filter = "all"
                tryCompare(panel, "selectedId", "wall")
                panel.enlarged = true
                panel.dismissEscape()
                compare(panel.enlarged, false)
                compare(panel.closes, 0)
                fixture.remove("wall")
                tryCompare(panel, "selectedId", "text")
                panel.width = 296; panel.height = 640
                compare(panel.narrow, true)
                wait(50)
                verify(panel.historyList.width <= panel.width)
                panel.width = 580; panel.height = 520
                fixture.records = [{id:"wall",kind:"image",title:"Обои Nayori",text:"",format:"PNG",bytes:123456,width:3344,height:1882,created:Date.now(),pinned:false,image:Qt.resolvedUrl("assets/wallpapers/nayori.png").toString()}].concat(fixture.records)
                panel.selectedId = "wall"
                tryCompare(panel.imagePreview, "status", Image.Ready)
                let saved = false
                panel.grabToImage(result => {
                    saved = result.saveToFile("/tmp/nayori-clipboard-preview.png")
                })
                tryVerify(() => saved)
                mouseClick(findChild(panel, "clipboardClear"))
                compare(fixture.records.length, 0)
                compare(panel.selectedId, "")
                panel.dismissEscape()
                compare(panel.closes, 1)
                console.log("CLIPBOARD_SMOKE_PASS")
                Qt.quit()
            }
        }
        Timer { interval: 400; running: true; onTriggered: test.run() }
    }
}
