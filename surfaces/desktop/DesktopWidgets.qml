pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../services"
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
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "io.github.lgse.Strata"
    property bool editing: false
    property bool visualBackdrop: false
    readonly property alias sharedSystemReader: desktopSystemReader
    readonly property var hiddenFaces: {
        const epoch = inputEpoch
        const ids = []
        for (let i = 0; i < widgetRepeater.count; i++) {
            const item = widgetRepeater.itemAt(i)
            if (item && item.inputVisible && item.spec) ids.push(item.spec.id)
        }
        return epoch >= 0 ? ids : []
    }
    signal layoutEdited(var next)
    signal editingRequested(bool enabled)

    property var pendingLayout: null
    property var order: []
    property string focusedId: ""
    property int inputEpoch: 0
    property date now: new Date()
    property string menuId: ""
    property bool desktopMenuOpen: false
    readonly property bool menuVisible: desktopMenuOpen || menuId !== ""
    property string menuNotice: ""
    property string movingId: ""
    property real menuX: 0
    property real menuY: 0

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
    readonly property bool wantsNote: containsType("note")
    readonly property bool wantsMusic: containsType("music")
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

    function changeWidget(id, field, value) {
        publish(WidgetLayout.changeItem(itemsNow(), id, field, value))
    }

    function resizeWidget(id, direction) {
        const item = placement(id)
        if (!item) return
        const sizes = item.type === "clock" ? ["compact", "large", "extraLarge", "huge"] : ["compact", "large"]
        const current = Math.max(0, sizes.indexOf(item.size))
        changeWidget(id, "size", sizes[Math.max(0, Math.min(sizes.length - 1, current + direction))])
    }

    function openMenu(id, x, y) {
        if (!desktopMenuOpen && menuId === id) { menuId = ""; return }
        desktopMenuOpen = false
        menuNotice = ""
        movingId = ""
        menuId = id
        menuX = Math.max(0, Math.min(x, screenWidth - contextMenu.width))
        menuY = Math.max(0, Math.min(y, screenHeight - contextMenu.height))
        Qt.callLater(() => contextMenu.forceActiveFocus())
    }

    function openDesktopMenu(x, y) {
        menuId = ""
        menuNotice = ""
        desktopMenuOpen = true
        menuX = Math.max(0, Math.min(x, screenWidth - contextMenu.width))
        menuY = Math.max(0, Math.min(y, screenHeight - contextMenu.height))
        Qt.callLater(() => contextMenu.forceActiveFocus())
    }

    function menuAction(action) {
        if (desktopMenuOpen) {
            if (action === "widgets") {
                desktopMenuOpen = false
                editingRequested(!editing)
            } else {
                const id = action === "terminal" ? preferredTerminal : preferredFileManager
                if (apps.launch(id)) desktopMenuOpen = false
                else menuNotice = "Не удалось открыть приложение"
            }
            return
        }
        const item = placement(menuId)
        if (!item) { menuId = ""; return }
        const id = menuId
        if (action === "move") { movingId = id; menuId = ""; return }
        if (action === "remove") { menuId = ""; applyRemove(id); return }
        if (action === "smaller" || action === "larger") resizeWidget(id, action === "larger" ? 1 : -1)
        else if (action === "style") changeWidget(id, "style", item.style === "card" ? "plain" : "card")
        else if (action.indexOf("metric:") === 0) {
            const key = action.slice(7)
            const metrics = WidgetLayout.normalizeMetrics(item.metrics)
            const index = metrics.indexOf(key)
            if (index >= 0 && metrics.length > 1) metrics.splice(index, 1)
            else if (index < 0) metrics.push(key)
            changeWidget(id, "metrics", metrics)
            return
        }
        menuId = ""
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
    focusable: editing || wantsNote || menuVisible
    mask: desktopMask
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nayori-desktop"
    WlrLayershell.keyboardFocus: editing || wantsNote || menuVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    objectName: "nayori-desktop"

    // The desktop surface receives clicks on empty space; windows remain above it.
    Item { id: desktopBounds; anchors.fill: parent }
    Region { id: desktopMask; item: desktopBounds }
    MouseArea {
        objectName: "desktop-background-click"
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.openDesktopMenu(mouse.x, mouse.y)
            else { root.menuId = ""; root.desktopMenuOpen = false; root.movingId = "" }
        }
    }
    Canvas {
        id: grid
        objectName: "desktop-widget-grid"
        anchors.fill: parent
        z: -1
        visible: root.editing
        property color ink: Qt.alpha(root.tokens.color.text, root.snapOn ? 0.20 : 0.08)
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = ink
            ctx.lineWidth = 1
            const step = WidgetLayout.gridSize()
            ctx.beginPath()
            for (let x = 0; x <= width; x += step) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height) }
            for (let y = 0; y <= height; y += step) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5) }
            ctx.stroke()
        }
    }
    Apps { id: apps }

    SystemReader {
        id: desktopSystemReader
        active: root.wantsSystem
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.wantsClock
        onTriggered: root.now = new Date()
    }

    // Progress polling does not enable the separate lyrics/network consumer.
    Timer {
        interval: 1000
        repeat: true
        running: root.wantsMusic && !!root.music && !!root.music.player && root.music.player.isPlaying
        triggeredOnStart: true
        onTriggered: if (root.music && typeof root.music.syncPosition === "function") root.music.syncPosition(true)
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
            inputOverlay: root.visualBackdrop
            moving: root.movingId === modelData
            snap: root.snapOn
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
            now: root.now
            weatherService: root.weatherService
            music: root.music
            systemReader: desktopSystemReader
            focusId: root.focusedId
            z: index
            onCommitPosition: function(id, x, y, useSnap) { root.applyPosition(id, x, y, useSnap) }
            onRemoveRequested: function(id) { root.applyRemove(id) }
            onNoteEdited: function(id, text) { root.applyNote(id, text) }
            onMenuRequested: function(id, x, y) { root.openMenu(id, x, y) }
            onResizeRequested: function(id, direction) { root.resizeWidget(id, direction) }
            onMoveFinished: root.movingId = ""
            onMaskDirty: root.bumpMask()
            onFocusIdChanged: root.focusedId = focusId
        }
    }
    FocusScope {
        id: contextMenu
        objectName: "desktop-widget-menu"
        z: 100
        visible: root.menuVisible && (root.desktopMenuOpen || !!root.placement(root.menuId))
        x: root.menuX
        y: root.menuY
        width: 224
        height: menuColumn.implicitHeight + 12
        onHeightChanged: if (visible) root.menuY = Math.max(0, Math.min(root.menuY, root.screenHeight - height))
        activeFocusOnTab: true
        Keys.onEscapePressed: function(event) { root.menuId = ""; root.desktopMenuOpen = false; event.accepted = true }
        readonly property var item: root.placement(root.menuId)
        readonly property var metrics: item && item.type === "system" ? WidgetLayout.normalizeMetrics(item.metrics) : []
        readonly property var entries: {
            if (root.desktopMenuOpen) return [
                { action: "terminal", text: "Терминал" },
                { action: "files", text: "Файлы" },
                { action: "widgets", text: "Виджеты" }
            ]
            const list = [
                { action: "move", text: "Переместить" },
                { action: "smaller", text: "Уменьшить" },
                { action: "larger", text: "Увеличить" },
                { action: "style", text: item && item.style === "card" ? "Убрать фон" : "Добавить фон" }
            ]
            if (item && item.type === "system") {
                list.push({ action: "metric:cpu", text: (metrics.indexOf("cpu") >= 0 ? "✓  " : "    ") + "Процессор" })
                list.push({ action: "metric:memory", text: (metrics.indexOf("memory") >= 0 ? "✓  " : "    ") + "Память" })
                list.push({ action: "metric:gpu", text: (metrics.indexOf("gpu") >= 0 ? "✓  " : "    ") + "Видеокарта" })
            }
            list.push({ action: "remove", text: "Удалить" })
            return list
        }
        Rectangle {
            anchors.fill: parent
            radius: root.tokens.radius.medium
            color: root.tokens.material.menu
            border.width: 1
            border.color: root.tokens.color.border
        }
        Column {
            id: menuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            DesktopLabel {
                width: parent.width
                visible: root.desktopMenuOpen && root.menuNotice !== ""
                tokens: root.tokens
                text: root.menuNotice
                wrapMode: Text.Wrap
            }
            Repeater {
                model: contextMenu.entries
                delegate: AbstractButton {
                    id: menuButton
                    objectName: "desktop-menu-" + modelData.action
                    required property var modelData
                    width: menuColumn.width
                    height: 36
                    text: modelData.text
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: text
                    Accessible.description: root.desktopMenuOpen && modelData.action === "widgets" ? (root.editing ? "Закончить расстановку" : "Начать расстановку") : ""
                    onClicked: root.menuAction(modelData.action)
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: menuButton.hovered || menuButton.visualFocus ? root.tokens.color.surfaceAlt : "transparent"
                        border.width: menuButton.visualFocus ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    contentItem: Item {
                        DesktopMenuIcon {
                            id: glyph
                            visible: root.desktopMenuOpen
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 18
                            height: 18
                            name: menuButton.modelData.action
                            ink: root.tokens.color.textMuted
                        }
                        DesktopLabel {
                            anchors.left: parent.left
                            anchors.leftMargin: root.desktopMenuOpen ? 40 : 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            // Inter's visible glyphs sit above the line box centre.
                            anchors.verticalCenterOffset: root.desktopMenuOpen ? 2 : 0
                            tokens: root.tokens
                            text: menuButton.text
                        }
                    }
                }
            }
        }
    }

}
