pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "tokens"
import "services/desktop"
import "surfaces/desktop"

ShellRoot {
    id: test
    property int phase: 0
    property int cycles: 0
    property int ticks: 0
    property real closedHeight: 0
    property real nextSetY: 0
    property real nextTypeY: 0
    property real setOpenHeight: 0
    property int layoutWrites: 0
    property int writesBeforeCancel: 0
    function check(ok, message) {
        if (!ok) { console.error("WIDGET_EDITOR_FAIL " + message); Qt.exit(1) }
    }
    function find(item, name) {
        if (!item) return null
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    function yInCatalog(name) {
        const item = find(catalog, name)
        check(item !== null, "missing catalog item " + name)
        return item.mapToItem(catalog, 0, 0).y
    }
    function clickHeader(name) {
        const header = find(catalog, name)
        check(header !== null, "missing catalog header " + name)
        header.clicked()
    }
    Tokens { id: theme; animationsEnabled: false }
    Test.TestEvent { id: input }
    StageSession { id: stage }
    FloatingWindow {
        visible: true
        implicitWidth: 360; implicitHeight: 720
        WidgetCatalog { id: catalog; width: 336; tokens: theme }
    }
    FloatingWindow {
        visible: true
        implicitWidth: Quickshell.screens[0].width
        implicitHeight: Quickshell.screens[0].height
        DesktopWidgetEditor {
            anchors.fill: parent
            id: editor
            screen: Quickshell.screens[0]
            tokens: theme
            editing: true
            stageSession: stage
            layout: ({snap:true, items:[
                {id:"first", type:"note", x:24, y:24, size:"compact", style:"card", text:"Первая"},
                {id:"second", type:"note", x:24, y:240, size:"compact", style:"card", text:"Вторая"}
            ]})
            onLayoutEdited: test.layoutWrites++
        }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (++test.ticks > 100) { test.check(false, "editor timed out"); return }
            const setName = "widget-catalog-set-Nayori"
            const typeName = "widget-catalog-type-Nayori-clock"
            const weatherName = "widget-catalog-type-Nayori-weather"
            const nextSetName = "widget-catalog-set-ii widgets"
            const grid = test.find(editor, "desktop-widget-grid")
            const guides = test.find(editor, "desktop-widget-alignment-guides")
            const tabs = test.find(editor, "desktop-widget-tabs")
            const pane = test.find(editor, "desktop-widget-settings-pane")
            const first = test.find(editor, "desktop-widget-first")
            const second = test.find(editor, "desktop-widget-second")
            if (test.phase === 0) {
                test.check(catalog.sets.length === 4 && catalog.visibleEntries.length === 0, "all widget sets initially collapsed")
                test.closedHeight = catalog.implicitHeight
                test.nextSetY = test.yInCatalog(nextSetName)
                test.clickHeader(setName)
            } else if (test.phase === 1) {
                test.check(test.yInCatalog(nextSetName) > test.nextSetY, "opening set moves following set")
                test.check(catalog.visibleEntries.length === 0, "types initially collapsed")
                test.nextTypeY = test.yInCatalog(weatherName)
                test.setOpenHeight = catalog.implicitHeight
                test.clickHeader(typeName)
            } else if (test.phase === 2) {
                test.check(test.yInCatalog(weatherName) > test.nextTypeY, "opening type moves following type")
                const compact = test.find(catalog, "widget-catalog-card-clock-compact")
                const large = test.find(catalog, "widget-catalog-card-clock-large")
                test.check(compact && large && compact.y === large.y && large.x > compact.x, "clock cards occupy two columns")
                test.clickHeader(typeName)
            } else if (test.phase === 3) {
                test.check(test.yInCatalog(weatherName) === test.nextTypeY && catalog.implicitHeight === test.setOpenHeight, "collapsing type restores positions and height")
                test.check(!test.find(catalog, "widget-catalog-card-clock-compact"), "collapsed cards unload")
                test.clickHeader(setName)
            } else if (test.phase === 4) {
                test.check(test.yInCatalog(nextSetName) === test.nextSetY && catalog.implicitHeight === test.closedHeight, "collapsing set restores original layout")
                if (++test.cycles < 3) { test.phase = 0; return }
                catalog.expandedSections = ({})
                catalog.query = "Nayori"
            } else if (test.phase === 5) {
                test.check(catalog.sets.length === 1 && catalog.visibleEntries.length === 7, "search opens matching sets and types")
                test.clickHeader(setName)
            } else if (test.phase === 6) {
                test.check(catalog.visibleEntries.length === 0 && !test.find(catalog, typeName), "search results stay collapsed when requested")
                catalog.query = ""
                test.check(first && second && grid && guides && tabs && pane, "real desktop editor loads")
                test.check(grid.visible && !guides.visible && !pane.visible && !tabs.model[1].enabled, "initial grid and selection state")
                stage.enterWidgets("fixture", "widgets")
                editor.openCatalog("widgets")
            } else if (test.phase === 7) {
                // Clicking a disabled settings segment must not open an empty pane.
                tabs.activated("settings")
                test.check(editor.widgetDrawerTab === 0, "settings unavailable without selected widget")
                const list = test.find(editor, "desktop-widget-catalog-list")
                const next = ({"set:Nayori":true})
                for (const type of list.sets[0].types) next["type:Nayori:" + type.key] = true
                list.expandedSections = next
            } else if (test.phase === 8) {
                const scroll = test.find(editor, "desktop-widget-drawer-content")
                test.check(scroll.contentHeight > scroll.height, "expanded catalog scrolls")
                scroll.contentY = scroll.contentHeight - scroll.height
                test.find(editor, "desktop-widget-catalog-list").toggleSection("set:Nayori")
            } else if (test.phase === 9) {
                const scroll = test.find(editor, "desktop-widget-drawer-content")
                test.check(scroll.contentY === 0 && scroll.contentHeight <= scroll.height, "collapse removes empty scrolling space")
                editor.catalogOpen = false
                input.mousePress(first, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
                input.mouseMove(first, 83, 101, 20, Qt.LeftButton, Qt.NoModifier)
            } else if (test.phase === 10) {
                test.check(first.dragging && guides.visible && guides.box.x === first.x && guides.box.y === first.y, "guides follow held widget")
                test.check(first.x % 12 === 0 && first.y % 12 === 0 && test.layoutWrites === 0, "live grid snap does not save during drag")
                input.mouseRelease(first, 83, 101, Qt.LeftButton, Qt.NoModifier, -1)
            } else if (test.phase === 11) {
                test.check(!guides.visible && test.layoutWrites === 1, "release hides guides and commits once")
                editor.applyLayout({snap:false, items:editor.itemsNow()}, false)
                input.mousePress(first, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
                input.mouseMove(first, 55, 57, 20, Qt.LeftButton, Qt.NoModifier)
            } else if (test.phase === 12) {
                test.check(first.dragging && !grid.visible && !guides.visible, "disabled grid hides both grid and drag guides")
                input.mouseRelease(first, 55, 57, Qt.LeftButton, Qt.NoModifier, -1)
                input.mouseClick(first, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
            } else if (test.phase === 13) {
                test.check(editor.widgetDrawerTab === 1 && editor.catalogOpen && pane.visible && pane.spec.id === "first", "click opens selected widget settings in same drawer")
                test.check(stage.selected === "first" && tabs.currentKey === "settings", "selection and active tab agree")
                const field = test.find(pane, "widget-setting-width")
                field.forceActiveFocus()
                pane.setField("opacity", 0.4)
                test.check(editor.placement("first").opacity === 0.4 && editor.placement("second").opacity === undefined, "settings affect only selected instance")
                test.check(field.activeFocus, "updating settings does not steal focus back to widget")
                editor.catalogOpen = false
                input.mouseClick(second, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
            } else if (test.phase === 14) {
                test.check(pane.visible && pane.spec.id === "second" && stage.selected === "second", "click switches settings to another widget")
                pane.setField("opacity", 0.7)
                test.check(editor.placement("first").opacity === 0.4 && editor.placement("second").opacity === 0.7, "instance options stay independent")
                editor.applyRemove("second")
            } else if (test.phase === 15) {
                test.check(editor.selectedWidget === null && !pane.visible && editor.widgetDrawerTab === 0 && !tabs.model[1].enabled, "removing selection closes its settings")
                editor.applyLayout({snap:true, items:editor.itemsNow()}, false)
                editor.catalogOpen = false
                input.mousePress(first, 20, 20, Qt.LeftButton, Qt.NoModifier, -1)
                input.mouseMove(first, 65, 71, 20, Qt.LeftButton, Qt.NoModifier)
            } else if (test.phase === 16) {
                test.check(guides.visible, "guides return when grid enabled")
                test.writesBeforeCancel = test.layoutWrites
                editor.editing = false
            } else if (test.phase === 17) {
                test.check(!first.dragging && !guides.visible && !grid.visible, "leaving editor cancels drag and hides guides")
                test.check(test.layoutWrites === test.writesBeforeCancel, "cancelled drag does not persist")
                console.log("WIDGET_EDITOR_PASS accordion/scroll/selection/grid/guides")
                Qt.quit()
            }
            test.phase++
        }
    }
}
