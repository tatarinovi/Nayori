pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens"
import "services/settings"
import "services/desktop"
import "surfaces/settings"
import "surfaces/desktop"

ShellRoot {
    id: test
    property int phase: 0
    property bool editing: false
    property var lastEdited: null
    property int gestureCommits: 0
    property var lastGeometry: null
    QtObject {
        id: gestureHost
        property bool editing: true
        property bool moving: false
        property bool snap: true
        property real x: 24
        property real y: 24
        property real width: 260
        property real height: 168
        property int screenWidth: 1920
        property int screenHeight: 1080
        property var box: ({width:260, height:168})
        property var spec: ({id:"gesture", type:"note", x:24, y:24})
    }
    WidgetSlot {
        id: slot
        host: gestureHost
        onPositionCommitted: (x,y) => { test.gestureCommits++; test.lastGeometry = {x:x,y:y} }
        onGeometryCommitted: (x,y,width,height) => { test.gestureCommits++; test.lastGeometry = {x:x,y:y,width:width,height:height} }
    }
    function check(ok, message) {
        if (!ok) { console.error("DESKTOP_WIDGET_FAIL " + message); Qt.exit(1) }
    }
    Tokens { id: theme }
    StageSession { id: stage }
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
                test.check(store.desktopWidgets["DP-1"].items[1].opacity === 0.6, "opacity restored")
                test.check(store.desktopWidgets["DP-1"].items[1].width === 320 && store.desktopWidgets["DP-1"].items[1].height === 210, "custom geometry restored")
                console.log("DESKTOP_WIDGET_RESTORE_PASS")
                Qt.quit()
            } else if (test.phase === 0) {
                slot.stageBeginMove(Qt.point(30,30), Qt.NoModifier)
                slot.stageUpdateMove(Qt.point(78,78), Qt.NoModifier)
                slot.stageEndMove(Qt.NoModifier)
                test.check(test.gestureCommits === 1 && test.lastGeometry.x === 72 && test.lastGeometry.y === 72, "ported move commits once")
                slot.stageBeginMove(Qt.point(30,30), Qt.NoModifier)
                slot.stageUpdateMove(Qt.point(110,110), Qt.NoModifier)
                slot.stageCancelMove()
                test.check(test.gestureCommits === 1 && !slot.dragging, "cancel does not persist")
                slot.stageBeginResize("br", Qt.point(284,192), Qt.NoModifier)
                slot.stageUpdateResize(Qt.point(414,276), Qt.NoModifier)
                slot.stageEndResize()
                test.check(test.gestureCommits === 2 && test.lastGeometry.width === 390 && test.lastGeometry.height === 252, "ported resize commits geometry once")
                slot.stageBeginResize("tl", Qt.point(24,24), Qt.NoModifier)
                slot.stageUpdateResize(Qt.point(0,0), Qt.NoModifier)
                slot.stageCancelResize()
                test.check(test.gestureCommits === 2 && !slot.resizing, "resize cancellation")
                slot.locked = true
                test.check(!slot.stageBeginMove(Qt.point(30,30), Qt.NoModifier), "locked widget does not move")
                slot.locked = false
                stage.enterWidgets("DP-1", "widgets")
                test.check(stage.onMonitor("DP-1") && !stage.onMonitor("HDMI-1"), "one editor monitor")
                stage.select("first")
                stage.toggleSelect("second")
                test.check(stage.selection.length === 2 && stage.selected === "second", "ordered selection")
                stage.openPanel("add")
                test.check(stage.escapeStep() === "panel" && stage.escapeStep() === "selection", "escape clears panel then selection")
                stage.enterWidgets("HDMI-1", "widgets")
                test.check(stage.onMonitor("HDMI-1") && stage.selection.length === 0, "switch monitor clears selection")
                test.check(stage.escapeStep() === "leave" && !stage.active, "escape ends session")
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
                const edited = JSON.parse(JSON.stringify(store.desktopWidgets))
                edited["DP-1"].items[1].opacity = 0.6
                edited["DP-1"].items[1].width = 320
                edited["DP-1"].items[1].height = 210
                store.update({ desktopWidgets: edited })
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
