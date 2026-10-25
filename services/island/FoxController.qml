import QtQuick
import "Behavior.js" as Behavior
QtObject {
    id: root
    property real cpu: 0
    property bool playing: false
    property bool audioAvailable: false
    property real energy: 0
    property real pendingBeat: 0
    property bool hovered: false
    property real pointerX: 0
    property real pointerY: 0
    // Expanded island: cursor offset in pixels from the fox centre, from anywhere.
    property bool looking: false
    property real lookX: 0
    property real lookY: 0
    property bool active: true
    property bool reducedMotion: false
    property bool unread: false
    property bool automatic: true
    property var state: Behavior.create()
    property var pose: ({ breath: 0, tail: 0, head: 0, x: 0, y: 0, marker: false, rest: 1, walk: 0, stride: 0 })
    property double lastTick: Date.now()
    function beat(strength) { pendingBeat = Math.max(pendingBeat, strength) }
    function advance(dt) {
        pose = Behavior.step(state, {cpu:cpu, playing:playing, audioAvailable:audioAvailable,
            energy:energy, beat:pendingBeat, hover:hovered, x:pointerX, y:pointerY,
            look:looking, lookX:lookX, lookY:lookY,
            visible:active, reducedMotion:reducedMotion, unread:unread}, dt)
        pendingBeat = 0
    }
    onActiveChanged: { lastTick = Date.now(); advance(0) }
    onReducedMotionChanged: { lastTick = Date.now(); advance(0) }
    onUnreadChanged: advance(0)
    property Timer ticker: Timer {
        interval: 33; repeat: true; running: root.automatic && root.active && !root.reducedMotion
        onTriggered: { const now = Date.now(); root.advance((now-root.lastTick)/1000); root.lastTick = now }
    }
}
