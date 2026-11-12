pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// The per-monitor native host; editor state and interaction live in one shared
// component so CI can exercise them without a layer-shell backend.
PanelWindow {
    id: root
    required property var tokens
    property alias layout: editor.layout
    property alias calendarStore: editor.calendarStore
    property alias widgetRuntime: editor.widgetRuntime
    property alias weatherService: editor.weatherService
    property alias music: editor.music
    property alias audioReaction: editor.audioReaction
    property alias visualizerService: editor.visualizerService
    property alias visualizerAccent: editor.visualizerAccent
    property alias systemMonitorService: editor.systemMonitorService
    property alias wallpaperClockAccent: editor.wallpaperClockAccent
    property alias preferredTerminal: editor.preferredTerminal
    property alias preferredFileManager: editor.preferredFileManager
    property alias editing: editor.editing
    property alias stageSession: editor.stageSession
    property alias visualBackdrop: editor.visualBackdrop
    property alias desktopDimOpacity: editor.desktopDimOpacity
    property alias wallpaperManager: editor.wallpaperManager
    readonly property alias editorShowing: editor.editorShowing
    readonly property alias viewItems: editor.viewItems
    readonly property alias now: editor.now
    readonly property alias sharedSystemReader: editor.sharedSystemReader
    readonly property alias hiddenFaces: editor.hiddenFaces
    signal layoutEdited(var next)
    signal editingRequested(bool enabled)
    signal wallpaperRequested()
    signal searchRequested()
    signal settingsRequested()
    signal musicStageRequested()
    signal monitorCycleRequested()
    function openCatalog(section) { editor.openCatalog(section) }

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: editor.editing || editor.wantsNote || editor.wantsImportedText || editor.menuVisible
    mask: editor.inputMask
    WlrLayershell.layer: editor.editorShowing ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "nayori-desktop"
    WlrLayershell.keyboardFocus: root.focusable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    objectName: "nayori-desktop"

    DesktopWidgetEditor {
        id: editor
        anchors.fill: parent
        visible: root.visible
        tokens: root.tokens
        screen: root.screen
        onLayoutEdited: next => root.layoutEdited(next)
        onEditingRequested: enabled => root.editingRequested(enabled)
        onWallpaperRequested: root.wallpaperRequested()
        onSearchRequested: root.searchRequested()
        onSettingsRequested: root.settingsRequested()
        onMusicStageRequested: root.musicStageRequested()
        onMonitorCycleRequested: root.monitorCycleRequested()
    }
}
