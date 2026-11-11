pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "WidgetLayout.js" as WidgetLayout

FocusScope {
    id: root
    required property var tokens
    property var spec: null
    property bool editing: false
    property bool snap: true
    property int screenWidth: 0
    property int screenHeight: 0
    property date now: new Date()
    property string wallpaperSource: ""
    property var calendarStore: null
    property var widgetRuntime: null
    property var weatherService: null
    property var music: null
    property var audioReaction: null
    property var wallpaperClockAccent: null
    property var systemReader: null
    property string focusId: ""
    signal commitPosition(string id, real x, real y, bool useSnap)
    signal removeRequested(string id)
    signal selectedRequested(string id)
    signal focusRequested(string id)
    signal optionsEdited(string id, var options)
    signal noteEdited(string id, string text)
    signal maskDirty()
    signal menuRequested(string id, real x, real y)
    signal resizeRequested(string id, int direction)
    signal commitSize(string id, real width, real height)
    signal moveFinished()
    signal undoRequested()
    signal redoRequested()
    signal escapeRequested()
    signal musicStageRequested()
    property bool moving: false
    property bool inputOverlay: false
    property real desktopDimOpacity: 0
    // Hover/focus moves the face above the wallpaper scrim. Tint only that
    // small interactive copy; preserve alpha around plain widgets and artwork.
    layer.enabled: inputOverlay && inputVisible && desktopDimOpacity > 0
    layer.effect: MultiEffect {
        colorization: root.desktopDimOpacity
        colorizationColor: "black"
        autoPaddingEnabled: false
    }
    readonly property bool inputVisible: editing || moving || dragging || activeFocus || contextArea.containsMouse

    readonly property var box: spec ? WidgetLayout.sizeOf(spec) : ({ width: 0, height: 0 })
    readonly property bool imported: spec && WidgetLayout.isImported(spec.type)
    readonly property bool card: spec && spec.style === "card" && !imported
    readonly property bool takesInput: spec !== null
    readonly property alias dragging: placement.dragging
    readonly property alias resizing: placement.resizing
    signal commitGeometry(string id, real x, real y, real width, real height)
    WidgetSlot {
        id: placement
        host: root
        onPositionCommitted: (x, y) => { if (root.spec) root.commitPosition(root.spec.id, x, y, root.snap) }
        onGeometryCommitted: (x, y, width, height) => { if (root.spec) root.commitGeometry(root.spec.id, x, y, width, height) }
    }
    onEditingChanged: if (!editing && !moving) { placement.stageCancelMove(); placement.stageCancelResize() }

    function widgetName(type) {
        if (type === "clock")
            return "Часы"
        if (type === "weather")
            return "Погода"
        if (type === "music")
            return "Музыка"
        if (type === "nowplaying")
            return "Сейчас играет"
        if (type === "system")
            return "Система"
        if (type === "note")
            return "Заметка"
        const entry = WidgetLayout.importedEntry(type)
        return entry ? entry.name : "Виджет"
    }

    visible: spec !== null
    width: resizing ? placement.previewWidth : box.width
    height: resizing ? placement.previewHeight : box.height
    x: !spec ? 0 : (dragging || resizing) ? placement.dragX : spec.x
    y: !spec ? 0 : (dragging || resizing) ? placement.dragY : spec.y
    z: dragging ? 10 : 0
    objectName: spec ? "desktop-widget-" + spec.id : "desktop-widget"
    activeFocusOnTab: true
    Accessible.name: spec ? widgetName(spec.type) : "Виджет"
    Accessible.description: editing ? "Стрелки двигают виджет" : ""

    opacity: inputOverlay && !inputVisible ? 0.001 : (spec && typeof spec.opacity === "number" ? spec.opacity : 1)
    onInputVisibleChanged: maskDirty()
    onTakesInputChanged: maskDirty()
    Component.onCompleted: {
        maskDirty()
        if (spec && editing && focusId === spec.id)
            forceActiveFocus()
    }
    onActiveFocusChanged: if (activeFocus && spec) focusRequested(spec.id)

    Keys.onPressed: function(event) {
        if (!editing || !spec || root.Window.activeFocusItem !== root)
            return
        if (event.key === Qt.Key_Escape) {
            escapeRequested()
            event.accepted = true
            return
        }
        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
            if (event.modifiers & Qt.ShiftModifier) redoRequested()
            else undoRequested()
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            selectedRequested(spec.id)
            event.accepted = true
            return
        }
        const grid = WidgetLayout.gridSize()
        const fine = event.modifiers & Qt.ShiftModifier
        const step = fine ? (snap ? 1 : grid) : (snap ? grid : 1)
        if (event.key === Qt.Key_Left)
            commitPosition(spec.id, x - step, y, false)
        else if (event.key === Qt.Key_Right)
            commitPosition(spec.id, x + step, y, false)
        else if (event.key === Qt.Key_Up)
            commitPosition(spec.id, x, y - step, false)
        else if (event.key === Qt.Key_Down)
            commitPosition(spec.id, x, y + step, false)
        else if (event.key === Qt.Key_Delete)
            removeRequested(spec.id)
        else
            return
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: root.card ? (root.spec && root.spec.type === "note" ? root.tokens.color.text : (root.tokens.frosted ? root.tokens.material.dense : root.tokens.color.background)) : "transparent"
        border.width: root.card ? 1 : 0
        border.color: root.tokens.color.border
        antialiasing: true
    }

    MouseArea {
        id: dragArea
        z: 3
        anchors.fill: parent
        enabled: (root.editing || root.moving) && root.spec !== null
        acceptedButtons: Qt.LeftButton
        hoverEnabled: enabled
        preventStealing: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: function(mouse) {
            const point = mapToItem(root.parent, mouse.x, mouse.y)
            root.forceActiveFocus()
            placement.stageBeginMove(point, mouse.modifiers)
        }
        onPositionChanged: function(mouse) {
            if (pressed) placement.stageUpdateMove(mapToItem(root.parent, mouse.x, mouse.y), mouse.modifiers)
        }
        onReleased: function(mouse) {
            const moved = placement.dragging
            placement.stageEndMove(mouse.modifiers)
            if (!moved && root.editing && root.spec) root.selectedRequested(root.spec.id)
            if (root.moving) root.moveFinished()
        }
        onCanceled: { placement.stageCancelMove(); if (root.moving) root.moveFinished() }
    }

    Item {
        id: content
        objectName: "desktop-widget-content"
        z: 1
        anchors.fill: parent
        anchors.leftMargin: root.card ? 16 : 0
        anchors.rightMargin: root.card ? 16 : 0
        anchors.bottomMargin: root.card ? (root.spec && root.spec.type === "system" ? 10 : 16) : 0
        anchors.topMargin: root.card ? (root.spec && root.spec.type === "system" ? 10 : 16) : 0
        clip: !root.imported

        Loader {
            anchors.fill: parent
            active: root.imported
            sourceComponent: ImportedWidgetFace {
                tokens: root.tokens
                screenWidth: root.screenWidth
                screenHeight: root.screenHeight
                wallpaperSource: root.wallpaperSource
                spec: root.spec
                onOptionsEdited: options => { if (root.spec) root.optionsEdited(root.spec.id, options) }
                onSettingsRequested: if (root.spec) root.selectedRequested(root.spec.id)
                active: root.visible && (!root.inputOverlay || root.inputVisible)
                enabled: !root.editing && !root.moving
                music: root.music
                systemReader: root.systemReader
                calendarStore: root.calendarStore
                widgetRuntime: root.widgetRuntime
                weatherService: root.weatherService
                audioReaction: root.audioReaction
            }
        }
        ClockWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "clock"
            enabled: visible
            tokens: root.tokens
            now: root.now
            wallpaperAccent: root.wallpaperClockAccent
            card: root.card
            editing: false
            size: root.spec ? root.spec.size : "compact"
            large: root.spec && root.spec.size !== "compact"
        }
        WeatherWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "weather"
            enabled: visible
            tokens: root.tokens
            service: root.weatherService
            large: root.spec && root.spec.size === "large"
        }
        MusicWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "music"
            enabled: visible && !root.editing && !root.moving
            tokens: root.tokens
            music: root.music
            audioReaction: root.audioReaction
            large: root.spec && root.spec.size === "large"
        }
        NowPlayingWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "nowplaying"
            enabled: visible && !root.editing && !root.moving
            tokens: root.tokens
            music: root.music
            audioReaction: root.audioReaction
            visualActive: !root.inputOverlay || root.inputVisible
            onStageRequested: root.musicStageRequested()
        }
        SystemWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "system"
            enabled: visible
            tokens: root.tokens
            reader: root.systemReader
            metrics: root.spec && root.spec.metrics ? root.spec.metrics : ["cpu", "memory", "gpu"]
            size: root.spec ? root.spec.size : "compact"
            large: root.spec && root.spec.size !== "compact"
        }
        NoteWidget {
            anchors.fill: parent
            visible: root.spec && root.spec.type === "note"
            enabled: visible && !root.editing && !root.moving
            tokens: root.tokens
            paper: root.card
            savedText: root.spec && root.spec.type === "note" && root.spec.text ? root.spec.text : ""
            onTextEdited: function(text) {
                if (root.spec)
                    root.noteEdited(root.spec.id, text)
            }
        }
    }

    MouseArea {
        id: contextArea
        anchors.fill: parent
        hoverEnabled: true
        z: 2
        acceptedButtons: Qt.RightButton
        enabled: root.spec !== null
        onClicked: function(mouse) {
            const p = mapToItem(root.parent, mouse.x, mouse.y)
            root.menuRequested(root.spec.id, p.x, p.y)
        }
        onWheel: function(wheel) {
            if (!(wheel.modifiers & Qt.ControlModifier)) { wheel.accepted = false; return }
            const delta = wheel.angleDelta.y || wheel.angleDelta.x
            if (delta) root.resizeRequested(root.spec.id, delta > 0 ? 1 : -1)
            wheel.accepted = true
        }
    }

    MouseArea {
        id: resizeHandle
        objectName: "desktop-widget-resize"
        z: 4
        visible: root.editing && root.spec !== null
        width: 28; height: 28
        anchors.right: parent.right; anchors.bottom: parent.bottom
        cursorShape: Qt.SizeFDiagCursor
        onPressed: function(mouse) {
            root.forceActiveFocus()
            placement.stageBeginResize("br", mapToItem(root.parent, mouse.x, mouse.y), mouse.modifiers)
        }
        onPositionChanged: function(mouse) {
            if (pressed) placement.stageUpdateResize(mapToItem(root.parent, mouse.x, mouse.y), mouse.modifiers)
        }
        onReleased: placement.stageEndResize()
        onCanceled: placement.stageCancelResize()
        onDoubleClicked: placement.stageResetScale()
        Item {
            anchors.right: parent.right; anchors.bottom: parent.bottom
            width: 16; height: 16
            readonly property color ink: root.card && root.spec && root.spec.type === "note" ? root.tokens.color.background : root.tokens.color.accent
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 14; height: 2; color: parent.ink }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 2; height: 14; color: parent.ink }
        }
    }

}
