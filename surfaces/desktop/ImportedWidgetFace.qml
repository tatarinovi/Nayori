import QtQuick
import "ImportedWidgets.js" as ImportedWidgets

Item {
    id: root
    required property var tokens
    property var spec: null
    property bool active: visible
    property var systemReader: null
    property var music: null
    property int screenWidth: 0
    property int screenHeight: 0
    property string wallpaperSource: ""
    property var calendarStore: null
    property var widgetRuntime: null
    property var weatherService: null
    property var audioReaction: null
    signal optionsEdited(var options)
    signal settingsRequested()
    property alias loadedItem: face.item
    property alias loadStatus: face.status
    readonly property var widgetBridge: bridge
    readonly property var entry: ImportedWidgets.selected(spec ? spec.type : "", spec ? spec.options : null)
    opacity: entry && entry.category === "Shima widgets" ? Math.max(0,Math.min(1,Number(bridge.options.widgetOpacity ?? 100)/100)) : 1
    FontLoader { source: Qt.resolvedUrl("vendor/widgets/assets/fonts/material-symbols/MaterialSymbolsRounded.ttf") }
    ImportedWidgetBridge {
        id: bridge
        tokens: root.tokens
        runtime: root.widgetRuntime
        onOptionsEdited: options => root.optionsEdited(options)
        onSettingsRequested: root.settingsRequested()
        width: root.screenWidth || root.width
        height: root.screenHeight || root.height
        hostX: root.spec ? root.spec.x || 0 : 0
        hostY: root.spec ? root.spec.y || 0 : 0
        wallpaperSource: root.wallpaperSource
        type: root.entry ? root.entry.type : ""
        savedOptions: root.spec && root.spec.options ? root.spec.options : ({})
        active: root.active
        systemReader: root.systemReader
        music: root.music
        calendarStore: root.calendarStore
        weatherService: root.weatherService
        audioReaction: root.audioReaction
    }
    Item {
        id: natural
        width: face.item ? Math.max(1, face.item.implicitWidth || root.width) : root.width
        height: face.item ? Math.max(1, face.item.implicitHeight || root.height) : root.height
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.TopLeft
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        Loader {
            id: face
            width: natural.width
            height: natural.height
            visible: root.active
            active: root.entry !== null && (root.entry.category !== "Shima widgets" || !!bridge.irisStyle)
            source: root.entry ? Qt.resolvedUrl("vendor/widgets/" + root.entry.source) : ""
            onLoaded: root.applyOptions()
        }
    }
    Component.onDestruction: face.active = false
    function applyOptions() {
        if (!face.item || !root.entry || root.entry.category !== "Python widgets") return
        const opts = bridge.options
        for (const key of Object.keys(opts)) {
            // Only declared writable presentation properties are eligible.
            if ((root.entry.settings || []).indexOf(key) < 0 || face.item[key] === undefined) continue
            face.item[key] = opts[key]
        }
    }
    Connections { target: bridge; function onOptionsChanged() { root.applyOptions() } }
}
