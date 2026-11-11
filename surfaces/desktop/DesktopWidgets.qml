pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../canvas"
import "../settings"
import "WidgetLayout.js" as WidgetLayout
import "vendor/edit_mode.js" as EditMode

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
    property var audioReaction: null
    property var wallpaperClockAccent: null
    readonly property string audioKey: "desktop-music-" + String(root)
    readonly property bool wantsAudio: root.visible && wantsMusic && !!music && !!music.player
        && music.player.isPlaying && !tokens.motion.off
    function updateAudioConsumer() {
        if (audioReaction) audioReaction.consumer(audioKey, wantsAudio)
    }
    onWantsAudioChanged: updateAudioConsumer()
    onAudioReactionChanged: updateAudioConsumer()
    Component.onDestruction: { if (audioReaction) audioReaction.consumer(audioKey, false); if (music) music.consumer(lyricsKey, false) }
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "io.github.lgse.Strata"
    property bool editing: false
    property var stageSession: null
    property bool visualBackdrop: false
    property var wallpaperManager: null
    property real editProgress: editing ? 1 : 0
    property real drawerProgress: catalogOpen && editing ? 1 : 0
    readonly property bool editorShowing: editing || editProgress > 0
    // Ported from Ryoku EditModeChromeSurface: all surfaces derive the same
    // card/drawer geometry from a single animation scalar (see NOTICE).
    readonly property var viewport: EditMode.viewportGeometry({
        screenWidth: screenWidth, screenHeight: screenHeight,
        drawerWidth: Math.min(360, screenWidth * 0.32), margin: 24,
        edgeMargin: 12, chromeThickness: 50
    })
    readonly property real editShift: EditMode.drawerTravel(viewport) * drawerProgress
    readonly property var cardGeometry: EditMode.cardRect(viewport, editProgress, screenWidth, screenHeight, editShift)
    readonly property var drawerGeometry: EditMode.drawerRect(viewport, editProgress, drawerProgress, screenWidth, screenHeight)
    Behavior on editProgress { enabled: !root.tokens.motion.off; NumberAnimation { duration: root.tokens.motion.base; easing.type: Easing.OutCubic } }
    Behavior on drawerProgress { enabled: !root.tokens.motion.off; NumberAnimation { duration: root.tokens.motion.base; easing.type: Easing.OutCubic } }
    readonly property alias sharedSystemReader: desktopSystemReader
    readonly property var hiddenFaces: {
        const epoch = inputEpoch
        if (editorShowing) return order
        const ids = []
        for (let i = 0; i < widgetRepeater.count; i++) {
            const item = widgetRepeater.itemAt(i)
            if (item && item.inputVisible && item.spec) ids.push(item.spec.id)
        }
        return epoch >= 0 ? ids : []
    }
    signal layoutEdited(var next)
    signal editingRequested(bool enabled)
    signal musicStageRequested()
    signal monitorCycleRequested()
    readonly property string lyricsKey: "desktop-lyrics-" + String(root)
    function updateLyricsConsumer() { if (music) music.consumer(lyricsKey, root.visible && root.wantsNowPlaying) }
    onWantsNowPlayingChanged: updateLyricsConsumer()
    onVisibleChanged: updateLyricsConsumer()
    onMusicChanged: updateLyricsConsumer()

    property var undoStack: []
    property var redoStack: []
    property bool catalogOpen: false
    property string localCatalogSection: "widgets"
    readonly property string catalogSection: stageSession ? stageSession.section : localCatalogSection
    function openCatalog(section) {
        if (stageSession) stageSession.openSection(section)
        else localCatalogSection = section
        catalogOpen = true
    }
    readonly property var editorWallpaper: wallpaperManager
        ? wallpaperManager.displayWallpaper(screen ? screen.name : "") : ({ source: "", mode: "fill" })
    property int idNonce: 0
    property var pendingLayout: null
    property var lastReceivedLayout: null
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
    readonly property bool wantsNowPlaying: containsType("nowplaying")
    readonly property bool wantsMusic: containsType("music") || wantsNowPlaying
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

    function applyLayout(next, record) {
        const clean = WidgetLayout.normalizeScreen(next)
        const previous = pendingLayout || screenLayout
        if (WidgetLayout.sameLayout(clean, previous)) return
        if (record && editing) {
            undoStack = EditMode.undoPush(undoStack, previous)
            redoStack = []
        }
        pendingLayout = clean
        layoutEdited(clean)
    }

    function undoEdit() {
        if (!undoStack.length) return
        const result = EditMode.undoPop(undoStack)
        const previous = result.entry
        undoStack = result.stack
        redoStack = EditMode.undoPush(redoStack, pendingLayout || screenLayout)
        applyLayout(previous, false)
    }

    function redoEdit() {
        if (!redoStack.length) return
        const result = EditMode.undoPop(redoStack)
        const next = result.entry
        redoStack = result.stack
        undoStack = EditMode.undoPush(undoStack, pendingLayout || screenLayout)
        applyLayout(next, false)
    }

    function escapeEditor() {
        const action = EditMode.resolveEscape({
            menuOpen: menuId !== "", desktopMenuOpen: desktopMenuOpen,
            drawerOpen: catalogOpen,
            selectionCount: stageSession ? stageSession.selection.length : 0
        })
        if (action === "closeMenu") { menuId = ""; desktopMenuOpen = false }
        else if (action === "closeDrawer") catalogOpen = false
        else if (action === "clearSelection") { focusedId = ""; if (stageSession) stageSession.deselect() }
        else if (action === "exit") editingRequested(false)
    }

    function addWidget(type) {
        if (itemsNow().length >= 16) return
        idNonce++
        const id = "w-" + Date.now().toString(36) + "-" + idNonce.toString(36) + "-" + Math.random().toString(36).slice(2, 10)
        publish(WidgetLayout.add(itemsNow(), { type: type, id: id }, screenWidth, screenHeight))
    }

    function publish(items) {
        const snap = (pendingLayout || screenLayout).snap === true
        const clean = WidgetLayout.normalizeScreen({ snap: snap, items: items })
        applyLayout(clean, true)
    }

    function applyPosition(id, x, y, useSnap) {
        if (screenWidth <= 0 || screenHeight <= 0)
            return
        let moved = WidgetLayout.move(itemsNow(), id, x, y, useSnap, WidgetLayout.gridSize())
        const original = placement(id)
        if (useSnap && original) {
            const edge = WidgetLayout.snapEdges(x, y, WidgetLayout.sizeOf(original), screenWidth, screenHeight)
            const gridItem = moved.find(item => item.id === id)
            if (gridItem) moved = WidgetLayout.move(moved, id,
                edge.x !== x ? edge.x : gridItem.x, edge.y !== y ? edge.y : gridItem.y, false)
        }
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
        if (stageSession) stageSession.remove(id)
        publish(WidgetLayout.remove(itemsNow(), id))
    }

    function applyNote(id, text) {
        publish(WidgetLayout.editText(itemsNow(), id, text))
    }

    function changeWidget(id, field, value) {
        publish(WidgetLayout.changeItem(itemsNow(), id, field, value))
    }

    function applyGeometry(id, x, y, width, height) {
        const resized = WidgetLayout.resize(itemsNow(), id, width, height)
        const moved = WidgetLayout.move(resized, id, x, y, false)
        publish(WidgetLayout.clampMoved(moved, id, screenWidth, screenHeight))
    }

    function applySize(id, width, height) {
        publish(WidgetLayout.resize(itemsNow(), id, width, height))
    }

    function resizeWidget(id, direction) {
        const item = placement(id)
        if (!item) return
        const sizes = item.type === "clock" ? ["compact", "large", "extraLarge", "huge"] : item.type === "system" ? ["compact", "large", "extraLarge"] : ["compact", "large"]
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
        else if (action === "opacity-down" || action === "opacity-up") {
            const opacity = typeof item.opacity === "number" ? item.opacity : 1
            changeWidget(id, "opacity", Math.round((opacity + (action === "opacity-up" ? 0.1 : -0.1)) * 10) / 10)
        }
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
    onEditingChanged: {
        if (!editing) { catalogOpen = false; undoStack = []; redoStack = [] }
    }
    onWantsClockChanged: if (wantsClock) now = new Date()
    onLayoutChanged: {
        const incoming = WidgetLayout.normalizeScreen(layout)
        const disposition = WidgetLayout.incomingDisposition(incoming, pendingLayout, lastReceivedLayout)
        if (disposition === "external") { undoStack = []; redoStack = [] }
        if (disposition !== "unchanged") pendingLayout = null
        lastReceivedLayout = incoming
    }
    Component.onCompleted: { lastReceivedLayout = WidgetLayout.normalizeScreen(layout); syncOrder() }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    // В покое слой не берёт клавиатуру. В правке OnDemand, иначе стрелки не доходят до виджета.
    focusable: editing || wantsNote || menuVisible
    mask: desktopMask
    WlrLayershell.layer: editorShowing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "nayori-desktop"
    WlrLayershell.keyboardFocus: editing || wantsNote || menuVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    objectName: "nayori-desktop"

    Rectangle {
        anchors.fill: parent
        color: root.tokens.color.background
        opacity: root.editProgress * 0.97
        visible: root.editorShowing
    }
    Item {
        id: editorCanvas
        width: root.screenWidth
        height: root.screenHeight
        x: root.cardGeometry.x
        y: root.cardGeometry.y
        scale: root.screenWidth > 0 ? root.cardGeometry.width / root.screenWidth : 1
        transformOrigin: Item.TopLeft
        Rectangle {
            anchors.fill: parent
            visible: root.editorShowing
            z: -3
            color: root.tokens.color.background
            border.color: root.tokens.color.border
            border.width: 1
            radius: root.tokens.radius.medium
        }
        WallpaperCrossfade {
            anchors.fill: parent
            visible: root.editorShowing && !!root.wallpaperManager && root.visualBackdrop
            z: -2
            source: String(root.editorWallpaper.source)
            mode: root.editorWallpaper.mode
            backgroundColor: root.tokens.color.background
            reduceMotion: root.tokens.motion.off
            duration: root.tokens.motion.base
            managerReady: !!root.wallpaperManager && root.wallpaperManager.ready
            outputName: root.screen ? root.screen.name : ""
        }
    }
    // The editor's preview scales only shell content; compositor windows stay put.
    Item { id: desktopBounds; anchors.fill: parent }
    Region { id: desktopMask; item: desktopBounds }
    MouseArea {
        objectName: "desktop-background-click"
        anchors.fill: parent
        z: -2
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) root.openDesktopMenu(mouse.x, mouse.y)
            else {
                root.menuId = ""; root.desktopMenuOpen = false; root.movingId = ""
                root.focusedId = ""
                if (root.stageSession && root.editing) root.stageSession.deselect()
            }
        }
    }
    Canvas {
        id: grid
        parent: editorCanvas
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
    // This chrome sits on the desktop input layer, leaving real Niri windows alone.
    Rectangle {
        id: editorBar
        objectName: "desktop-editor-bar"
        visible: root.editing
        z: 120
        x: Math.max(12, root.cardGeometry.x + (root.cardGeometry.width - width) / 2)
        y: Math.max(12, root.cardGeometry.y - height - 12)
        width: Math.min(root.screenWidth - 24, editorRow.implicitWidth + 24)
        height: 50
        radius: root.tokens.radius.medium
        color: root.tokens.material.menu
        border.color: root.tokens.color.border
        Row {
            id: editorRow
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: [
                    { label: "Виджеты", action: "catalog", enabled: true },
                    { label: "Обои", action: "wallpapers", enabled: true },
                    { label: root.screen ? root.screen.name : "Экран", action: "screen", enabled: Quickshell.screens.length > 1 },
                    { label: root.snapOn ? "Сетка: вкл." : "Сетка: выкл.", action: "snap", enabled: true },
                    { label: "↶", action: "undo", enabled: root.undoStack.length > 0 },
                    { label: "↷", action: "redo", enabled: root.redoStack.length > 0 },
                    { label: "Готово", action: "done", enabled: true }
                ]
                delegate: SettingsButton {
                    required property var modelData
                    tokens: root.tokens
                    primary: modelData.action === "done"
                    text: modelData.label
                    enabled: modelData.enabled
                    Accessible.name: modelData.action === "undo" ? "Отменить" : modelData.action === "redo" ? "Повторить" : text
                    onClicked: {
                        if (modelData.action === "screen") root.monitorCycleRequested()
                        else if (modelData.action === "catalog") {
                            if (root.catalogOpen && root.catalogSection === "widgets") root.catalogOpen = false
                            else root.openCatalog("widgets")
                        }
                        else if (modelData.action === "wallpapers") root.openCatalog("wallpaper")
                        else if (modelData.action === "snap") root.applyLayout({snap: !root.snapOn, items: root.itemsNow()}, true)
                        else if (modelData.action === "undo") root.undoEdit()
                        else if (modelData.action === "redo") root.redoEdit()
                        else if (modelData.action === "done") root.editingRequested(false)
                    }
                }
            }
        }
    }
    Rectangle {
        id: catalog
        objectName: "desktop-widget-catalog"
        z: 119
        visible: root.editing && root.catalogOpen
        x: root.drawerGeometry.x
        y: root.drawerGeometry.y
        width: root.drawerGeometry.width
        height: root.drawerGeometry.height
        clip: true
        radius: root.tokens.radius.medium
        color: root.tokens.material.menu
        border.color: root.tokens.color.border
        Flickable {
            visible: root.catalogSection !== "wallpaper"
            anchors.fill: parent
            anchors.margins: 12
            contentWidth: width
            contentHeight: catalogColumn.implicitHeight
            clip: true
        Column {
            id: catalogColumn
            width: parent.width
            spacing: 6
            TextField {
                id: catalogSearch
                objectName: "desktop-catalog-search"
                width: parent.width
                placeholderText: "Поиск виджетов"
            }
            DesktopLabel { tokens: root.tokens; text: "Nayori" }
            Repeater {
                model: WidgetLayout.catalog(catalogSearch.text)
                delegate: SettingsButton {
                    required property var modelData
                    tokens: root.tokens
                    width: catalogColumn.width
                    text: modelData.icon + "  " + modelData.name + " — " + modelData.description
                    enabled: root.itemsNow().length < 16
                    onClicked: root.addWidget(modelData.id)
                }
            }
        }
        }
        Loader {
            objectName: "desktop-wallpaper-loader"
            anchors.fill: parent
            anchors.margins: 12
            active: root.editing && root.catalogOpen && root.catalogSection === "wallpaper" && !!root.wallpaperManager
            sourceComponent: DesktopWallpaperPicker {
                tokens: root.tokens
                manager: root.wallpaperManager
                output: root.screen ? root.screen.name : ""
            }
        }
    }

    Apps { id: apps }

    SystemReader {
        id: desktopSystemReader
        active: root.wantsSystem && root.visible
        showDetails: root.viewItems.some(item => item.type === "system" && item.size !== "compact")
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
        parent: editorCanvas
        model: root.order
        onCountChanged: root.bumpMask()
        delegate: DesktopWidgetFrame {
            required property var modelData
            required property int index
            tokens: root.tokens
            spec: root.placement(modelData)
            editing: root.editing
            inputOverlay: root.visualBackdrop && !root.editorShowing
            moving: root.movingId === modelData
            snap: root.snapOn
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
            now: root.now
            weatherService: root.weatherService
            music: root.music
            audioReaction: root.audioReaction
            wallpaperClockAccent: root.wallpaperClockAccent
            systemReader: desktopSystemReader
            focusId: root.focusedId
            z: index + 1
            onCommitPosition: function(id, x, y, useSnap) { root.applyPosition(id, x, y, useSnap) }
            onRemoveRequested: function(id) { root.applyRemove(id) }
            onNoteEdited: function(id, text) { root.applyNote(id, text) }
            onMenuRequested: function(id, x, y) {
                const point = editorCanvas.mapToItem(desktopBounds, x, y)
                root.openMenu(id, point.x, point.y)
            }
            onResizeRequested: function(id, direction) { root.resizeWidget(id, direction) }
            onCommitSize: function(id, width, height) { root.applySize(id, width, height) }
            onCommitGeometry: function(id, x, y, width, height) { root.applyGeometry(id, x, y, width, height) }
            onMoveFinished: root.movingId = ""
            onUndoRequested: root.undoEdit()
            onRedoRequested: root.redoEdit()
            onEscapeRequested: root.escapeEditor()
            onMusicStageRequested: root.musicStageRequested()
            onMaskDirty: root.bumpMask()
            onFocusIdChanged: {
                root.focusedId = focusId
                if (root.stageSession && root.editing && focusId !== "") root.stageSession.select(focusId)
            }
        }
    }
    FocusScope {
        id: contextMenu
        objectName: "desktop-widget-menu"
        z: 100
        visible: root.menuVisible && (root.desktopMenuOpen || !!root.placement(root.menuId))
        x: root.menuX
        y: root.menuY
        width: root.desktopMenuOpen ? 304 : 224
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
                { action: "widgets", text: "Редактировать рабочий стол", icon: "edit-desktop" }
            ]
            const list = [
                { action: "move", text: "Переместить" },
                { action: "smaller", text: "Уменьшить" },
                { action: "larger", text: "Увеличить" },
                { action: "style", text: item && item.style === "card" ? "Убрать фон" : "Добавить фон" },
                { action: "opacity-down", text: "Прозрачнее" },
                { action: "opacity-up", text: "Непрозрачнее" }
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
                            name: menuButton.modelData.icon || menuButton.modelData.action
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
