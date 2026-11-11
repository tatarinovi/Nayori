import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick





AbstractBackgroundWidget {
    readonly property var nayoriDialClockWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "clock_dial"

    implicitWidth: 240
    implicitHeight: 240

    property bool wallpaperSafetyTriggered: false

    visibleWhenLocked: root.lockBehavior === "keep" || root.lockBehavior === "custom" || root.lockBehavior === "center" || root.lockBehavior === "lockOnly"
    opacity: {
        if (root.lockBehavior === "lockOnly") return nayoriDialClockWidget.globalStates.screenLocked ? 1 : 0;
        if (nayoriDialClockWidget.globalStates.screenLocked && !visibleWhenLocked) return 0;
        return 1;
    }

    needsColText: false

    // Supersampled: DialClock is a Canvas, so it rasterises at its own item
    // size. Without this it would be a stretched bitmap once the widget grows.
    Supersampled {
        anchors.fill: parent
        factor: root.renderScale

        DialClock {
            anchors.fill: parent
            live: root.live
        }
    }
}
