import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
pragma Singleton

import QtQuick
import Quickshell

// One clock for every silent Organic field: separate timers land on separate frames, so three
// drifting fields repainted the desktop three times per tick instead of once.
Singleton {
    readonly property var nayoriOrganicIdleClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property int users: 0
    signal tick(real dt)

    Timer {
        interval: 42
        repeat: true
        running: root.users > 0
        onTriggered: root.tick(interval / 1000)
    }
}
