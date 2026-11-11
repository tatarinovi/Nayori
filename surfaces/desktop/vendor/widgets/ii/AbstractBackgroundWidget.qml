import "."
import QtQuick
import "../BridgeContext.js" as BridgeContext

// Nayori host seam: upstream presentation retains its own geometry and look;
// WidgetSlot alone owns placement, resizing, input and persistence.
Item {
    id: root
    readonly property var hostBridge: BridgeContext.find(parent)
    property string configEntryName: ""
    property string lockBehavior: "keep"
    property bool visibleWhenLocked: true
    property bool isPreview: true
    property bool paused: false
    property bool _resizeActive: false
    property bool needsColText: false
    readonly property bool live: visible && !paused && !!hostBridge && hostBridge.active
    readonly property real renderScale: 1
    readonly property var configEntry: hostBridge ? hostBridge.options : ({})
    readonly property var widgetInstance: null
    readonly property var instanceImagePath: configEntry.imagePath
    property int screenWidth: hostBridge ? hostBridge.width : 1920
    property int screenHeight: hostBridge ? hostBridge.height : 1080
    property int scaledScreenWidth: screenWidth
    property int scaledScreenHeight: screenHeight
    property real wallpaperScale: 1
    readonly property bool activeWorkspaceHasWindows: false
    function updatePosition() {}
}
