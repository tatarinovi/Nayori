import QtQuick
import "NotificationQueue.js" as Queue
QtObject {
    id: root
    property var state: Queue.create()
    property int revision: 0
    property bool paused: false
    property bool automatic: true
    property var expandedViews: ({})
    property var openPages: ({})
    readonly property var records: { if (revision < 0) return []; return state.records.filter(r => !r.deleted).map(r => Object.assign({}, r)) }
    readonly property int unreadCount: { if (revision < 0) return 0; return state.records.filter(r => !r.deleted && !r.read).length }
    readonly property var current: { if (revision < 0) return null; const r = state.records.find(r => r.id === state.current); return r ? Object.assign({}, r) : null }
    signal actionRequested(int notificationId, string actionId)
    signal dismissRequested(int notificationId)
    function receive(data) { Queue.receive(state, data); revision++; advance(0) }
    function close(id) { Queue.close(state, id, false); revision++ }
    function remove(id) { Queue.close(state, id, true); revision++; dismissRequested(id) }
    function clear() { records.slice().forEach(r => remove(r.id)) }
    function view(key, expanded, pageOpen) {
        expandedViews[key] = expanded; openPages[key] = pageOpen
        paused = Object.keys(expandedViews).some(k => expandedViews[k])
        Queue.page(state, Object.keys(openPages).some(k => openPages[k])); revision++
    }
    function advance(seconds) { const before = state.current; Queue.tick(state, seconds, paused); if (state.current !== before) revision++ }
    property double lastTick: Date.now()
    property Timer clock: Timer {
        interval: 50; repeat: true; running: root.automatic
        onTriggered: { const now = Date.now(); root.advance((now - root.lastTick) / 1000); root.lastTick = now }
    }
}
