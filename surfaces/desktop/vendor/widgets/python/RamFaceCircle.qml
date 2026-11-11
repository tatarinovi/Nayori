import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriRamFaceCircle: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent

    property real minWidth: 90
    property real minHeight: 90
    property real maxWidth: 600
    property real maxHeight: 600
    property real minAspect: 0.5
    property real maxAspect: 2.0
    property bool isRound: false

    property bool sineWave: true
    property real lineThickness: 8

    property bool isSubscribed: false
    property bool compactMode: Math.min(root.height, root.width) < nayoriRamFaceCircle.scaler.s(110)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriRamFaceCircle.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriRamFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriRamFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawRam: isNaN(nayoriRamFaceCircle.sysData.ramPercent) ? 0.0 : Math.round(nayoriRamFaceCircle.sysData.ramPercent) / 100.0
    property real ramUsage: rawRam
    Behavior on ramUsage { enabled: root.visible; NumberAnimation { duration: (nayoriRamFaceCircle && nayoriRamFaceCircle.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    property real rawRamGb: isNaN(nayoriRamFaceCircle.sysData.ramGb) ? 0.0 : Math.round(nayoriRamFaceCircle.sysData.ramGb * 10) / 10.0
    property real ramUsedGb: rawRamGb
    Behavior on ramUsedGb { enabled: root.visible; NumberAnimation { duration: (nayoriRamFaceCircle && nayoriRamFaceCircle.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: root.ramUsage
        accentColor: Qt.lighter(nayoriRamFaceCircle.pythonTheme.mauve, 1.15)
        icon: String.fromCodePoint(0xF035C)
        title: nayoriRamFaceCircle.i18n.t("quickactions.systemusage.ram")
        valueText: root.ramUsedGb.toFixed(1) + "G"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriRamFaceCircle.scaler.s
    }
}
