import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriTempFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

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
    property bool compactMode: root.height < nayoriTempFace.scaler.s(100) || root.width < nayoriTempFace.scaler.s(140)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriTempFace.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriTempFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriTempFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawTemp: isNaN(nayoriTempFace.sysData.temp) ? 0.0 : Math.round(nayoriTempFace.sysData.temp)
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.visible; NumberAnimation { duration: (nayoriTempFace && nayoriTempFace.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    SystemUsageCard {
        anchors.fill: parent
        blurred: !root.ryokuBare
        bgOpacity: nayoriTempFace.pythonTheme.elementOpacity
        value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
        colorBase: root.ryokuBare ? "transparent" : nayoriTempFace.pythonTheme.surface0
        colorFill: nayoriTempFace.pythonTheme.mauve
        icon: String.fromCodePoint(0xF050F)
        title: nayoriTempFace.i18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriTempFace.scaler.s
    }
}
