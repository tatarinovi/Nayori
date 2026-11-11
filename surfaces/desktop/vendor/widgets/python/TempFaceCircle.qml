import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriTempFaceCircle: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

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
    property bool compactMode: Math.min(root.height, root.width) < nayoriTempFaceCircle.scaler.s(110)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriTempFaceCircle.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriTempFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriTempFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawTemp: isNaN(nayoriTempFaceCircle.sysData.temp) ? 0.0 : Math.round(nayoriTempFaceCircle.sysData.temp)
    property real tempC: rawTemp
    Behavior on tempC { enabled: root.visible; NumberAnimation { duration: (nayoriTempFaceCircle && nayoriTempFaceCircle.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    SystemUsageCircle {
        anchors.fill: parent
        value: Math.max(0.0, Math.min(1.0, root.tempC / 100.0))
        accentColor: nayoriTempFaceCircle.pythonTheme.mauve
        icon: String.fromCodePoint(0xF050F)
        title: nayoriTempFaceCircle.i18n.t("quickactions.systemusage.temp")
        valueText: Math.round(root.tempC) + "°"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriTempFaceCircle.scaler.s
    }
}
