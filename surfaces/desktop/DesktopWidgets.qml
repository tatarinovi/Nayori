pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "WidgetLayout.js" as WidgetLayout

// Слой виджетов одного экрана. Оболочка ставит его в Variants и задаёт screen
// (свойство PanelWindow, коннектор Wayland).
//
// layout — вход: { snap, items } или null. Свойство нельзя совместить с сигналом
// layoutChanged: Qt 6.12 не загружает тип (duplicate signal). Правки уходят
// сигналом layoutEdited(next). next — замена раскладки этого экрана.
// onLayoutChanged у свойства layout аргумента не несёт и срабатывает, когда
// оболочка сама записывает layout. Сохранять раскладку нужно из onLayoutEdited.
PanelWindow {
    id: root
    required property var tokens
    property var layout: null
    property var weatherService: null
    property var music: null
    property bool editing: false
    signal layoutEdited(var next)

    property var pendingLayout: null
    property var order: []
    property string focusedId: ""
    property int inputEpoch: 0
    property date now: new Date()

    readonly property int screenWidth: screen ? screen.width : 0
    readonly property int screenHeight: screen ? screen.height : 0
    readonly property var screenLayout: WidgetLayout.normalizeScreen(layout)
    readonly property var effectiveLayout: pendingLayout || screenLayout
    readonly property bool snapOn: effectiveLayout.snap === true
    readonly property var viewItems: WidgetLayout.clamp(effectiveLayout.items, screenWidth, screenHeight)
    readonly property var placedById: {
        const map = ({})
        const items = viewItems
        for (let i = 0; i < items.length; i++)
            map[items[i].id] = items[i]
        return map
    }
    readonly property bool wantsClock: containsType("clock")
    readonly property bool wantsSystem: containsType("system")
    readonly property var maskItems: {
        const epoch = inputEpoch
        const list = []
        const count = widgetRepeater.count
        for (let i = 0; i < count; i++) {
            const item = widgetRepeater.itemAt(i)
            if (item && item.takesInput)
                list.push(item)
        }
        return epoch >= 0 ? list : []
    }

    function containsType(type) {
        const items = effectiveLayout.items || []
        for (let i = 0; i < items.length; i++) {
            if (items[i].type === type)
                return true
        }
        return false
    }

    function placement(id) {
        const map = placedById
        return map[id] || null
    }

    function maskAt(index) {
        const items = maskItems
        return index < items.length ? items[index] : null
    }

    function bumpMask() {
        inputEpoch++
    }

    function itemsNow() {
        return pendingLayout ? pendingLayout.items : screenLayout.items
    }

    function publish(items) {
        const snap = (pendingLayout || screenLayout).snap === true
        const clean = WidgetLayout.normalizeScreen({ snap: snap, items: items })
        if (WidgetLayout.sameLayout(clean, pendingLayout || screenLayout))
            return
        pendingLayout = clean
        layoutEdited(clean)
    }

    function applyPosition(id, x, y, useSnap) {
        if (screenWidth <= 0 || screenHeight <= 0)
            return
        const moved = WidgetLayout.move(itemsNow(), id, x, y, useSnap, WidgetLayout.gridSize())
        let placed = null
        for (let i = 0; i < moved.length; i++) {
            if (moved[i].id === id)
                placed = WidgetLayout.clamp([moved[i]], screenWidth, screenHeight)[0]
        }
        if (!placed)
            return
        const items = []
        for (let i = 0; i < moved.length; i++)
            items.push(moved[i].id === id ? placed : moved[i])
        publish(items)
    }

    function applyRemove(id) {
        if (focusedId === id)
            focusedId = ""
        publish(WidgetLayout.remove(itemsNow(), id))
    }

    function applyNote(id, text) {
        publish(WidgetLayout.editText(itemsNow(), id, text))
    }

    function syncOrder() {
        const items = effectiveLayout.items || []
        const ids = []
        for (let i = 0; i < items.length; i++)
            ids.push(items[i].id)
        if (ids.length === order.length) {
            let same = true
            for (let i = 0; i < ids.length; i++) {
                if (ids[i] !== order[i]) {
                    same = false
                    break
                }
            }
            if (same)
                return
        }
        order = ids
    }

    onEffectiveLayoutChanged: syncOrder()
    onWantsClockChanged: if (wantsClock) now = new Date()
    onLayoutChanged: {
        if (!pendingLayout)
            return
        const incoming = WidgetLayout.normalizeScreen(layout)
        if (WidgetLayout.sameLayout(incoming, pendingLayout) || !WidgetLayout.sameIds(incoming.items, pendingLayout.items))
            pendingLayout = null
    }
    Component.onCompleted: syncOrder()

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    // В покое слой не берёт клавиатуру. В правке OnDemand, иначе стрелки не доходят до виджета.
    focusable: editing
    mask: maskItems.length > 0 ? liveMask : emptyMask
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nayori-desktop"
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    objectName: "nayori-desktop"

    Region { id: emptyMask }
    Region {
        id: liveMask
        Region { item: root.maskAt(0) }
        Region { item: root.maskAt(1) }
        Region { item: root.maskAt(2) }
        Region { item: root.maskAt(3) }
        Region { item: root.maskAt(4) }
        Region { item: root.maskAt(5) }
        Region { item: root.maskAt(6) }
        Region { item: root.maskAt(7) }
        Region { item: root.maskAt(8) }
        Region { item: root.maskAt(9) }
        Region { item: root.maskAt(10) }
        Region { item: root.maskAt(11) }
        Region { item: root.maskAt(12) }
        Region { item: root.maskAt(13) }
        Region { item: root.maskAt(14) }
        Region { item: root.maskAt(15) }
    }

    SystemReader {
        id: systemReader
        active: root.wantsSystem
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.wantsClock
        onTriggered: root.now = new Date()
    }

    Repeater {
        id: widgetRepeater
        model: root.order
        onCountChanged: root.bumpMask()
        delegate: DesktopWidgetFrame {
            required property var modelData
            required property int index
            tokens: root.tokens
            spec: root.placement(modelData)
            editing: root.editing
            snap: root.snapOn
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
            now: root.now
            weatherService: root.weatherService
            music: root.music
            systemReader: systemReader
            focusId: root.focusedId
            z: index
            onCommitPosition: function(id, x, y, useSnap) { root.applyPosition(id, x, y, useSnap) }
            onRemoveRequested: function(id) { root.applyRemove(id) }
            onNoteEdited: function(id, text) { root.applyNote(id, text) }
            onMaskDirty: root.bumpMask()
            onFocusIdChanged: root.focusedId = focusId
        }
    }
}
