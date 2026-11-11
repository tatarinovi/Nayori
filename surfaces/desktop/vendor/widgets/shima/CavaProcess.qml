import QtQuick
import "../BridgeContext.js" as BridgeContext
Item {
    id: root
    readonly property var bridge: BridgeContext.find(parent)
    property bool active: false
    property int sampleCount: 0
    readonly property var points: active && bridge.audioReaction ? (bridge.audioReaction.visualizerSpectrum || bridge.audioReaction.spectrum || []).map(value => value*100) : []
    readonly property real normalizationCeiling: 100
    readonly property bool audioSignalActive: active && !!bridge.audioReaction && bridge.audioReaction.available !== false
    property bool held: false
    function sync() {
        const wanted = active && bridge.active && !bridge.reducedMotion && !bridge.gameMode.visualizersSuppressed
        if (wanted === held) return
        held = wanted
        if (held) bridge.cava.registerConsumer(); else bridge.cava.unregisterConsumer()
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (held) bridge.cava.unregisterConsumer()
    Connections { target: root.bridge; function onActiveChanged() { root.sync() } function onReducedMotionChanged() { root.sync() } function onGameModeChanged() { root.sync() } }
}
