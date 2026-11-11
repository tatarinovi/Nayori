import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriRamFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    property real minWidth: 100
    property real minHeight: 70
    property real maxWidth: 600
    property real maxHeight: 400
    property real minAspect: 0.6
    property real maxAspect: 3.0
    property bool isRound: false
    // Ryoku host hook: while the desktop slot draws the plate (Ryoku style),
    // this face's own plate steps aside; the content keeps painting.
    property bool ryokuBare: false

    property bool isSubscribed: false
    property bool compactMode: root.height < nayoriRamFace.scaler.s(100) || root.width < nayoriRamFace.scaler.s(140)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriRamFace.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriRamFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriRamFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawRam: isNaN(nayoriRamFace.sysData.ramPercent) ? 0.0 : Math.round(nayoriRamFace.sysData.ramPercent) / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.visible; NumberAnimation { duration: (nayoriRamFace && nayoriRamFace.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(nayoriRamFace.sysData.ramGb) ? 0.0 : Math.round(nayoriRamFace.sysData.ramGb * 10) / 10.0
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: (nayoriRamFace && nayoriRamFace.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    SystemUsageCard {
        anchors.fill: parent
        blurred: !root.ryokuBare
        bgOpacity: nayoriRamFace.pythonTheme.elementOpacity
        value: root.ramUsage
        colorBase: root.ryokuBare ? "transparent" : nayoriRamFace.pythonTheme.surface0
        colorFill: Qt.lighter(nayoriRamFace.pythonTheme.mauve, 1.15)
        icon: String.fromCodePoint(0xF035C)
        title: nayoriRamFace.i18n.t("quickactions.systemusage.ram")
        valueText: root.ramUsedGb.toFixed(1) + "G"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriRamFace.scaler.s
    }
}
