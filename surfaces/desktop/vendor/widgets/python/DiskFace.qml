import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriDiskFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

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
    property bool compactMode: root.height < nayoriDiskFace.scaler.s(100) || root.width < nayoriDiskFace.scaler.s(140)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriDiskFace.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriDiskFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriDiskFace.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawDisk: isNaN(nayoriDiskFace.sysData.diskPercent) ? 0.0 : nayoriDiskFace.sysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.visible; NumberAnimation { duration: (nayoriDiskFace && nayoriDiskFace.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    property string diskUsedText: nayoriDiskFace.sysData.diskGb > 0 ? (nayoriDiskFace.sysData.diskGb.toFixed(1) + "G") : "..."
    property string diskTotalText: nayoriDiskFace.sysData.diskTotalGb > 0 ? (nayoriDiskFace.sysData.diskTotalGb.toFixed(1) + "G") : ""

    SystemUsageCard {
        anchors.fill: parent
        blurred: !root.ryokuBare
        bgOpacity: nayoriDiskFace.pythonTheme.elementOpacity
        value: root.diskUsagePercent
        colorBase: root.ryokuBare ? "transparent" : nayoriDiskFace.pythonTheme.surface0
        colorFill: Qt.darker(nayoriDiskFace.pythonTheme.mauve, 1.15)
        icon: String.fromCodePoint(0xF02CA)
        title: root.diskTotalText
        subText: root.diskUsedText
        valueText: Math.round(root.diskUsagePercent * 100) + "%"
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriDiskFace.scaler.s
    }
}
