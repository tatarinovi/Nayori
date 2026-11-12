import QtQuick
import "../BridgeContext.js" as BridgeContext
// Nayori host seam; original concrete renderers retain their presentation.
Item {
    id: root
    readonly property var hostBridge: BridgeContext.find(parent)
    property string configEntryName: ""
    property var defaultConfig: ({})
    property var resizableAxes: ({})
    property real resizeMinWidth: 80
    property real resizeMinHeight: 60
    property real resizeMaxWidth: 1800
    property real resizeMaxHeight: 1200
    property bool liveColorTracking: false
    property bool needsColText: false
    property bool visibleWhenLocked: true
    property bool draggable: false
    property bool locked: false
    property bool widgetSurfaceEnabled: true
    property bool semanticPaletteQuickControls: true
    property Component editPopoverContent: null
    property Component irisFace: null
    property var irisSizes: []
    property string irisDefaultSize: "medium"
    property var irisOptions: []
    readonly property string _configPath: "background.widgets." + configEntryName
    readonly property real scaleFactor: Math.max(0.1,Math.min(4,Number(_readConfigKey("widgetScale") ?? 100)/100))
    readonly property bool ryokuHosted: true
    readonly property bool ryokuStyle: false
    readonly property bool powerActive: !!hostBridge && hostBridge.active
    readonly property bool animationsActive: powerActive && !hostBridge.reducedMotion
    readonly property bool motionActive: animationsActive
    readonly property real ryokuScreenX: hostBridge ? hostBridge.hostX : 0
    readonly property real ryokuScreenY: hostBridge ? hostBridge.hostY : 0
    readonly property real scaledScreenWidth: hostBridge ? hostBridge.width : 0
    readonly property real scaledScreenHeight: hostBridge ? hostBridge.height : 0
    readonly property bool widgetIris: true
    readonly property bool irisFaced: irisFace !== null
    readonly property real irisFaceWidth: (hostBridge.options.irisSize === "small" ? 170 : hostBridge.options.irisSize === "large" ? 360 : 300) * scaleFactor
    readonly property real irisFaceHeight: (hostBridge.options.irisSize === "small" ? 170 : hostBridge.options.irisSize === "large" ? 300 : 210) * scaleFactor
    readonly property real irisGutter: 16
    readonly property real cornerRadiusOverride: Number(_readConfigKey("cornerRadius") ?? -1)
    readonly property real widgetCardRadius: 22
    readonly property color widgetInk: hostBridge.ink
    readonly property color widgetInkMuted: hostBridge.muted
    readonly property color widgetInkSubtle: hostBridge.muted
    readonly property color widgetSurfaceInk: hostBridge.ink
    readonly property color widgetPlateColor: hostBridge.surface
    readonly property color widgetAccent: hostBridge.accent
    readonly property color widgetAccent2: hostBridge.tokens.color.secondary
    readonly property color widgetAccent3: hostBridge.accent
    readonly property color widgetAccentVisible: widgetAccent
    readonly property color widgetAccent2Visible: widgetAccent2
    readonly property color widgetAccent3Visible: widgetAccent3
    readonly property color irisAccent: widgetAccent
    readonly property string widgetBodyFamily: hostBridge.tokens.type.body.family
    readonly property string widgetTitleFamily: widgetBodyFamily
    readonly property string widgetNumbersFamily: "monospace"
    readonly property int widgetLabelWeight: Font.Medium
    readonly property string widgetPrimaryRole: "primary"
    readonly property string widgetSecondaryRole: "secondary"
    readonly property string widgetTertiaryRole: "tertiary"
    readonly property string widgetSurfaceRole: "surface"
    readonly property string widgetSignalRole: "signal"
    readonly property color widgetSignal: widgetAccent
    readonly property color accentBackdrop: widgetPlateColor
    readonly property real regionBrightness: 0.2
    readonly property string colorMode: String(_readConfigKey("colorMode") || "auto")
    readonly property real backgroundOpacity: _readConfigKey("showBackground") === false ? 0 : Number(_readConfigKey("backgroundOpacity") ?? 0.16)
    readonly property real borderOpacity: Number(_readConfigKey("borderOpacity") ?? 0.2)
    readonly property real borderWidth: _readConfigKey("showBorder") === false ? 0 : Number(_readConfigKey("borderWidth") ?? 1)
    readonly property bool effectiveBlur: _readConfigKey("useBlur") === true
    readonly property bool widgetHasSurface: backgroundOpacity > 0
    function _readConfigKey(key) { return hostBridge.optionValue(key,defaultConfig[key]) }
    function _setOutputValue(key,value) { hostBridge.editOption(key,value) }
    function previewIrisValue(key,value) { _setOutputValue(key,value) }
    function commitIrisValue(key,value) { _setOutputValue(key,value) }
    function widgetSemanticContainer(role) { return role === "secondary" ? widgetAccent2 : role === "tertiary" ? widgetAccent3 : widgetPlateColor }
    function widgetSemanticOnContainer(role) { return widgetInk }
    function widgetSemanticForeground(role) { return widgetInk }
    Loader { anchors.fill: parent; z:-1; sourceComponent: root.irisFace }
}
