import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick


// Per-wave facade over the shared WaveTick: registers with the tick while
// `running` and republishes the shared phase, so a caller binds
// `wavePhase: waveClock.phase` exactly as it used to bind the property of its
// own infinite NumberAnimation.
QtObject {
    readonly property var nayoriWaveClock: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: clock

    property bool running: false
    property bool motionEnabled: true
    property bool disposed: false
    property int duration: (nayoriWaveClock && nayoriWaveClock.reducedMotion ? 0 : 3400)

    readonly property real phase: clock.running && clock.motionEnabled ? WaveTick.phase(clock.duration) : 0.0

    function _sync(): void {
        const i = WaveTick.clients.indexOf(clock);
        const active = clock.running && clock.motionEnabled && !clock.disposed
        if (active && i < 0)
            WaveTick.clients = WaveTick.clients.concat([clock]);
        else if (!active && i >= 0) {
            const next = WaveTick.clients.slice();
            next.splice(i, 1);
            WaveTick.clients = next;
        }
    }

    onRunningChanged: _sync()
    onMotionEnabledChanged: _sync()
    Component.onDestruction: { disposed = true; _sync() }
}
