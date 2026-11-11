import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick
import Quickshell



Item {
    readonly property var nayoriDiskFaceCircle: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

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
    property bool compactMode: Math.min(root.height, root.width) < nayoriDiskFaceCircle.scaler.s(110)

    function updateSubscription() {
        if (root.visible && !root.isSubscribed) {
            nayoriDiskFaceCircle.sysData.subscribe();
            root.isSubscribed = true;
        } else if (!root.visible && root.isSubscribed) {
            nayoriDiskFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    onVisibleChanged: updateSubscription()
    Component.onCompleted: updateSubscription()
    Component.onDestruction: {
        if (root.isSubscribed) {
            nayoriDiskFaceCircle.sysData.unsubscribe();
            root.isSubscribed = false;
        }
    }

    property real rawDisk: isNaN(nayoriDiskFaceCircle.sysData.diskPercent) ? 0.0 : nayoriDiskFaceCircle.sysData.diskPercent / 100.0
    property real diskUsagePercent: rawDisk
    Behavior on diskUsagePercent { enabled: root.visible; NumberAnimation { duration: (nayoriDiskFaceCircle && nayoriDiskFaceCircle.reducedMotion ? 0 : 800); easing.type: Easing.OutQuint } }

    property string diskTotalText: nayoriDiskFaceCircle.sysData.diskTotalGb > 0 ? (nayoriDiskFaceCircle.sysData.diskTotalGb.toFixed(1) + "G") : ""

    SystemUsageCircle {
        anchors.fill: parent
        value: root.diskUsagePercent
        accentColor: Qt.darker(nayoriDiskFaceCircle.pythonTheme.mauve, 1.15)
        icon: String.fromCodePoint(0xF02CA)
        title: root.diskTotalText
        valueText: Math.round(root.diskUsagePercent * 100) + "%"
        useSineWave: root.sineWave
        lineThickness: root.lineThickness
        isLive: root.visible
        compact: root.compactMode
        scaleFunc: nayoriDiskFaceCircle.scaler.s
    }
}
