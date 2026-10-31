pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "surfaces/desktop"
import "services/niri"

ShellRoot {
    id: test
    property int phase: 0
    property string note: ""
    property int moved: 0
    property int menus: 0
    function check(ok, message) { if (!ok) { console.error("DESKTOP_CONTENT_FAIL " + message); Qt.exit(1) } }
    function findItem(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) { const result = findItem(child, name); if (result) return result }
        return null
    }
    Tokens { id: theme }
    Test.TestEvent { id: input }
    SystemReader { id: systemReader }
    FloatingWindow {
        visible: true; implicitWidth: 520; implicitHeight: 400
        color: theme.color.background
        DesktopWidgetFaces {
            id: faces
            x: 260; width: 260; height: 168
            tokens: theme
            items: [{ id: "face", type: "note", x: 0, y: 0, size: "compact", style: "card", text: "пример" }]
            hiddenIds: test.phase > 0 ? ["face"] : []
        }
        DesktopWidgetFrame {
            id: frame
            tokens: theme
            screenWidth: 520; screenHeight: 400
            spec: ({ id: "note", type: "note", x: 20, y: 20, size: "compact", style: "card", text: test.note })
            onNoteEdited: (id, value) => test.note = value
            onMenuRequested: (id, x, y) => test.menus++
            onCommitPosition: (id, x, y, snap) => test.moved++
        }
    }
    Timer {
        interval: 300; repeat: true; running: true
        onTriggered: {
            if (test.phase === 0) {
                Niri.applyEvent({OverviewOpenedOrClosed: {is_open: true}}, Niri._streamEpoch)
                test.check(Niri.overviewOpen, "overview opened")
                Niri.applyEvent({OverviewOpenedOrClosed: {is_open: false}}, Niri._streamEpoch)
                test.check(!Niri.overviewOpen, "overview closed")
                test.check(test.findItem(faces, "desktop-widget-face").visible, "wallpaper face shown")
                systemReader.consumeGpu("42\n")
                test.check(systemReader.gpu === 0.42 && !systemReader.gpuFailed, "GPU percentage parsed")
                systemReader.consumeGpu("N/A")
                test.check(systemReader.gpu === null && systemReader.gpuFailed, "unavailable GPU handled")
                const editor = test.findItem(frame, "desktop-note-editor")
                test.check(editor && frame.takesInput, "note is interactive")
                input.mouseClick(frame, 8, 8, Qt.RightButton, Qt.NoModifier, -1)
                test.check(test.menus === 1, "right click opens menu")
                input.mouseClick(editor, 10, 10, Qt.LeftButton, Qt.NoModifier, -1)
                input.keyClickChar("a", Qt.NoModifier, -1)
                test.check(editor.activeFocus && editor.text === "a", "note accepts keyboard input")
            } else if (test.phase === 2) {
                test.check(!test.findItem(faces, "desktop-widget-face").visible, "interactive face hidden on backdrop")
                test.check(test.note === "a", "note edit saved")
                frame.editing = true
                frame.forceActiveFocus()
                input.keyClick(Qt.Key_Right, Qt.NoModifier, -1)
                test.check(test.moved === 1, "keyboard moves widget")
            } else if (test.phase === 3) {
                console.log("DESKTOP_CONTENT_PASS")
                Qt.quit()
            }
            test.phase++
        }
    }
}
