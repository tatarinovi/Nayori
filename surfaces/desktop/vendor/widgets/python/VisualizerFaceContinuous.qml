import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io




Item {
    readonly property var nayoriVisualizerFaceContinuous: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

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
            nayoriVisualizerFaceContinuous.cava.registerConsumer();
        } else if (!isVisVisible && isSubscribed) {
            isSubscribed = false;
            nayoriVisualizerFaceContinuous.cava.unregisterConsumer();
        }
    }

    Component.onCompleted: updateSubscription()

    Component.onDestruction: {
        if (isSubscribed) {
            isSubscribed = false;
            nayoriVisualizerFaceContinuous.cava.unregisterConsumer();
        }
    }

    Visualizer {
        anchors.fill: parent
        active: root.isSubscribed
        continuous: true
        color: false ? nayoriVisualizerFaceContinuous.accent : nayoriVisualizerFaceContinuous.pythonTheme.mauve
        gain: nayoriVisualizerFaceContinuous.options.gain || 1
        count: 64
        rise: 0.25
        fall: 0.12
        maxLength: height * 0.92
    }
}
