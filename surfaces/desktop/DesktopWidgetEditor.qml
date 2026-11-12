pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../services/system"
import "../canvas"
import "../visualizer"
import "../settings"
import "WidgetLayout.js" as WidgetLayout
import "vendor/edit_mode.js" as EditMode

// Shared desktop editor content. DesktopWidgets owns its layer-shell window;
// CI hosts this same content in an isolated offscreen FloatingWindow.
FocusScope {
    id: root
    required property var tokens
    property var screen: null
    readonly property alias inputMask: desktopMask
    property var layout: null
    property var calendarStore: null
    property var widgetRuntime: null
    property var weatherService: null
    property var music: null
    property var audioReaction: null
    property var visualizerService: null
    property color visualizerAccent: tokens.color.accent
    property var systemMonitorService: null
    property var wallpaperClockAccent: null
    readonly property string audioKey: "desktop-music-" + String(root)
    readonly property bool wantsMusicAudio: containsType("music") || wantsNowPlaying
        || viewItems.some(item => item.type.startsWith("python_Music") && !item.type.startsWith("python_MusicFaceLyrics"))
    readonly property bool wantsAudio: root.visible && wantsMusicAudio && !!music && !!music.player
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
    property real desktopDimOpacity: 0
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
    signal wallpaperRequested()
    signal searchRequested()
    signal settingsRequested()
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
    property int widgetDrawerTab: 0
    readonly property var selectedWidget: placement(focusedId)
    onSelectedWidgetChanged: if (!selectedWidget) widgetDrawerTab = 0
    function selectWidget(id) {
        if (!editing || !placement(id)) return
        focusedId = id
        if (stageSession) stageSession.select(id)
        widgetDrawerTab = 1
        openCatalog("widgets")
    }
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
    readonly property bool wantsSystem: containsType("system") || viewItems.some(item => /^python_(Cpu|Ram|Temp|Disk)/.test(item.type) || item.type === "ii_concentric_clock" || item.type.startsWith("ii_resource_") || item.type === "ii_nothing_ram" || item.type === "shima_systemMonitor" || item.type === "shima_uptime")
    readonly property bool wantsNote: containsType("note")
    readonly property bool wantsImportedText: viewItems.some(item => ["shima_notes","shima_todo","python_GithubFace"].includes(item.type))
    readonly property bool wantsNowPlaying: containsType("nowplaying")
    readonly property bool wantsMusic: containsType("music") || wantsNowPlaying || viewItems.some(item => item.type.startsWith("python_Music") || item.type === "shima_mediaControls")
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
    readonly property var dragGuideBox: {
        for (const item of maskItems) {
            if (item && item.dragging)
                return {x:item.x, y:item.y, width:item.width, height:item.height}
        }
        return null
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

    function addWidget(type, size, style) {
        if (itemsNow().length >= 16) return
        idNonce++
        const id = "w-" + Date.now().toString(36) + "-" + idNonce.toString(36) + "-" + Math.random().toString(36).slice(2, 10)
        publish(WidgetLayout.add(itemsNow(), { type: type, id: id, size: size, style: style }, screenWidth, screenHeight))
        focusedId = id
        if (stageSession) stageSession.select(id)
    }

    function publish(items) {
        const snap = (pendingLayout || screenLayout).snap === true
        const clean = WidgetLayout.normalizeScreen({ snap: snap, items: items })
        applyLayout(clean, true)
    }

    function applyPosition(id, x, y, useSnap) {
        if (screenWidth <= 0 || screenHeight <= 0)
            return
        const original = placement(id)
        if (!original) return
        const placed = WidgetLayout.placementPosition(x, y, WidgetLayout.sizeOf(original), screenWidth, screenHeight, useSnap)
        publish(WidgetLayout.move(itemsNow(), id, placed.x, placed.y, false))
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
    }

    function menuAction(action) {
        if (action === "options") {
            editingRequested(true)
            selectWidget(menuId)
            menuId = ""
            return
        }
        if (desktopMenuOpen) {
            menuNotice = ""
            if (action === "terminal") {
                if (apps.launch(preferredTerminal)) desktopMenuOpen = false
                else menuNotice = "Не удалось открыть терминал. Проверьте приложение в настройках"
            } else if (["lock", "logout", "reboot", "powerOff"].indexOf(action) >= 0) {
                session[action]()
            } else {
                desktopMenuOpen = false
                if (action === "widgets") editingRequested(!editing)
                else if (action === "wallpaper") wallpaperRequested()
                else if (action === "search") searchRequested()
                else if (action === "settings") settingsRequested()
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

    objectName: "nayori-desktop-editor"

    Rectangle {
        anchors.fill: parent
        color: root.tokens.color.background
        opacity: root.editProgress * 0.97
        visible: root.editorShowing
    }
    Item {
        id: editorCanvas
        focus: root.editing && root.catalogSection === "visualizer"
        Keys.onEscapePressed: event => { root.escapeEditor(); event.accepted = true }
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
    VisualizerLayer {
        parent: editorCanvas
        anchors.fill: parent
        visible: root.editorShowing && root.visualBackdrop
        service: root.visualizerService
        tokens: root.tokens
        output: root.screen ? root.screen.name : ""
        sourceAudio: root.audioReaction
        paletteAccent: root.visualizerAccent
        editing: root.editing && root.catalogSection === "visualizer"
        snap: root.snapOn
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
        visible: root.editing && root.snapOn
        property color ink: Qt.alpha(root.tokens.color.text, 0.20)
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
    WidgetAlignmentGuides {
        parent: editorCanvas
        anchors.fill: parent
        z: 0
        tokens: root.tokens
        box: root.dragGuideBox
        visible: root.editing && root.snapOn && box !== null
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
                    { label: "Визуализатор", action: "visualizer", enabled: true },
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
                        else if (modelData.action === "visualizer") root.openCatalog("visualizer")
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
        SettingsSegmented {
            id: widgetTabs
            objectName: "desktop-widget-tabs"
            tokens: root.tokens
            equalWidth: true
            height: 40
            visible: root.catalogSection === "widgets"
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 12
            currentKey: root.widgetDrawerTab === 1 ? "settings" : "catalog"
            model: [{key:"catalog", label:"Каталог"}, {key:"settings", label:"Настройки", enabled:root.selectedWidget !== null}]
            onActivated: key => { if (key !== "settings" || root.selectedWidget !== null) root.widgetDrawerTab = key === "settings" ? 1 : 0 }
        }
        Flickable {
            id: widgetDrawerContent
            objectName: "desktop-widget-drawer-content"
            visible: root.catalogSection === "widgets"
            anchors.top: widgetTabs.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 12
            contentWidth: width
            contentHeight: catalogColumn.implicitHeight
            clip: true
            function clampScroll() { contentY = Math.max(0, Math.min(contentY, Math.max(0, contentHeight - height))) }
            onContentHeightChanged: Qt.callLater(clampScroll)
            Connections { target: root; function onWidgetDrawerTabChanged() { widgetDrawerContent.contentY = 0 } }
            Column {
                id: catalogColumn
                width: parent.width
                spacing: 12
                WidgetCatalog {
                    objectName: "desktop-widget-catalog-list"
                    width: parent.width
                    visible: root.widgetDrawerTab === 0
                    tokens: root.tokens
                    canAdd: root.itemsNow().length < 16
                    onAddRequested: (type, size, style) => root.addWidget(type, size, style)
                }
                WidgetSettingsPane {
                    objectName: "desktop-widget-settings-pane"
                    width: parent.width
                    visible: root.widgetDrawerTab === 1 && root.selectedWidget !== null
                    tokens: root.tokens
                    spec: root.selectedWidget
                    onFieldEdited: (id, field, value) => root.changeWidget(id, field, value)
                    onNoteEdited: (id, text) => root.applyNote(id, text)
                    onGeometryEdited: (id, x, y, width, height) => root.applyGeometry(id, x, y, width, height)
                }
            }
        }
        Loader {
            anchors.fill: parent
            anchors.margins: 12
            active: root.editing && root.catalogOpen && root.catalogSection === "visualizer" && !!root.visualizerService
            sourceComponent: VisualizerPane {
                onEscapeRequested: root.escapeEditor()
                tokens: root.tokens
                service: root.visualizerService
                output: root.screen ? root.screen.name : ""
                aspect: root.screenWidth / Math.max(1, root.screenHeight)
                sourceAudio: root.audioReaction
                paletteAccent: root.visualizerAccent
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
        monitorService: root.systemMonitorService
        active: root.wantsSystem && root.visible
        showDetails: root.wantsSystem
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
            desktopDimOpacity: root.editorShowing ? 0 : root.desktopDimOpacity
            moving: root.movingId === modelData
            snap: root.snapOn
            wallpaperSource: root.editorWallpaper.source || ""
            screenWidth: root.screenWidth
            screenHeight: root.screenHeight
            now: root.now
            calendarStore: root.calendarStore
            widgetRuntime: root.widgetRuntime
            weatherService: root.weatherService
            music: root.music
            audioReaction: root.audioReaction
            wallpaperClockAccent: root.wallpaperClockAccent
            systemReader: desktopSystemReader
            focusId: root.focusedId
            z: index + 1
            onCommitPosition: function(id, x, y, useSnap) { root.applyPosition(id, x, y, useSnap) }
            onRemoveRequested: function(id) { root.applyRemove(id) }
            onSelectedRequested: id => {
                if (!root.editing) root.editingRequested(true)
                Qt.callLater(() => root.selectWidget(id))
            }
            onOptionsEdited: (id, options) => root.changeWidget(id, "options", options)
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
            onFocusRequested: id => {
                root.focusedId = id
                if (root.stageSession && root.editing && id !== "") root.stageSession.select(id)
            }
        }
    }
    SessionActions {
        id: session
        onStarted: root.desktopMenuOpen = false
        onFailed: function(action, message) { root.menuNotice = message; root.desktopMenuOpen = true }
    }
    FocusScope {
        id: contextMenu
        objectName: "desktop-widget-menu"
        z: 100
        readonly property bool desktopPresentation: root.desktopMenuOpen || (desktopMenu.presenting && root.menuId === "")
        visible: desktopPresentation || (root.menuId !== "" && !!root.placement(root.menuId))
        x: root.menuX
        y: root.menuY
        width: desktopPresentation ? desktopMenu.implicitWidth : 224
        height: desktopPresentation ? desktopMenu.implicitHeight : menuColumn.implicitHeight + 12
        onHeightChanged: if (visible) root.menuY = Math.max(0, Math.min(root.menuY, root.screenHeight - height))
        activeFocusOnTab: true
        Keys.onEscapePressed: function(event) { root.menuId = ""; root.desktopMenuOpen = false; event.accepted = true }
        readonly property var item: root.placement(root.menuId)
        readonly property var metrics: item && item.type === "system" ? WidgetLayout.normalizeMetrics(item.metrics) : []
        readonly property var entries: {
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
            if (item && WidgetLayout.isImported(item.type)) list.push({action: "options", text: "Настройки виджета"})
            list.push({ action: "remove", text: "Удалить" })
            return item && WidgetLayout.isImported(item.type) ? list.filter(entry => entry.action !== "style") : list
        }
        DesktopContextMenu {
            id: desktopMenu
            anchors.fill: parent
            visible: presenting && root.menuId === ""
            tokens: root.tokens
            opened: root.desktopMenuOpen && root.visible
            wallpaperSource: root.visualBackdrop ? root.editorWallpaper.source : ""
            busy: session.busy
            notice: root.menuNotice
            onRequested: action => root.menuAction(action)
            onDismissed: root.desktopMenuOpen = false
        }
        Rectangle {
            visible: !contextMenu.desktopPresentation
            anchors.fill: parent
            radius: root.tokens.radius.medium
            color: root.tokens.material.menu
            border.width: 1
            border.color: root.tokens.color.border
        }
        Column {
            id: menuColumn
            visible: !contextMenu.desktopPresentation
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
