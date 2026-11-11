import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io




Item {
    readonly property var nayoriVisualizerFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    property real minWidth: 50
    property real minHeight: 50
    property real maxWidth: 99999
    property real maxHeight: 99999
    property real minAspect: 0
    property real maxAspect: 99999

    property bool isVisVisible: visible

    property bool isSubscribed: false

    onIsVisVisibleChanged: updateSubscription()

    function updateSubscription() {
        if (isVisVisible && !isSubscribed) {
            isSubscribed = true;
            nayoriVisualizerFace.cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            nayoriVisualizerFace.cava.unregisterConsumer();
        }
    }

    Component.onCompleted: updateSubscription()

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            nayoriVisualizerFace.cava.unregisterConsumer();
        }
    }

    property real barSpacing: nayoriVisualizerFace.scaler.s(4)
    property real minBarWidth: nayoriVisualizerFace.scaler.s(6)
    property int activeBars: Math.max(4, Math.min(128, Math.floor((width + barSpacing) / (minBarWidth + barSpacing))))

    Visualizer {
        anchors.fill: parent
        active: root.isSubscribed
        color: false ? nayoriVisualizerFace.accent : nayoriVisualizerFace.pythonTheme.mauve
        gain: nayoriVisualizerFace.options.gain || 1
        count: root.activeBars
        spacing: root.barSpacing
        maxLength: height * 0.96
        minLength: nayoriVisualizerFace.scaler.s(3)
        radiusRatio: 0.35
        opacityBase: 0.3
        opacityRange: 0.7
        edgeFade: true
    }
}
