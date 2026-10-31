import QtQuick
import "NotificationQueue.js" as Queue
import "NotificationList.js" as List
import "NotificationPolicy.js" as Policy

// Журнал уведомлений в памяти. Логика — в NotificationQueue.js и NotificationPolicy.js.
QtObject {
    id: root
    property var state: Queue.create()
    property int revision: 0
    property var expandedViews: ({})
    property var openPages: ({})
    property bool notificationsEnabled: true
    property bool doNotDisturb: false
    property var sources: []
    property var sourceList: []
    signal sourcesChangedRequested(var sources)
    // Записи от нового к старому. Копии: изменения списка видны привязкам.
    readonly property var records: { if (revision < 0) return []; return state.records.filter(r => !r.deleted).map(r => Object.assign({}, r)) }
    readonly property int unreadCount: { if (revision < 0) return 0; return Queue.unreadCount(state) }
    // Закреплено в свёрнутом острове: самое раннее непросмотренное, пока страницу не открыли.
    readonly property var current: { if (revision < 0) return null; const r = Queue.pinned(state); return r ? Object.assign({}, r) : null }
    // Значки справа: до трёх разных приложений, кроме закреплённого, от старого к новому.
    readonly property var pending: { if (revision < 0) return []; return List.pendingSources(Queue.pending(state, state.records.length), Queue.pinned(state)).map(r => Object.assign({}, r)) }
    readonly property int pendingTotal: { if (revision < 0) return 0; return Queue.pendingTotal(state) }
    readonly property bool pageOpen: { if (revision < 0) return false; return state.pageOpen }
    signal actionRequested(int notificationId, string actionId)
    signal replyRequested(int notificationId, string text)
    signal dismissRequested(int notificationId)
    // Нажатие на уведомление: открыть приложение и выполнить действие по умолчанию.
    signal activateRequested(var record)

    function refreshCompact() {
        const list = sourceList
        state.records.forEach(record => {
            record.compact = !record.quiet && Policy.modeOf(list, record) === "normal"
        })
    }
    function adoptSources() {
        const merged = Policy.mergeSources(sources, sourceList)
        sourceList = merged.list
        refreshCompact()
        revision++
        if (merged.changed) sourcesChangedRequested(merged.list)
    }
    onSourcesChanged: adoptSources()
    Component.onCompleted: adoptSources()

    function receive(data) {
        const existing = Queue.find(state, data && data.id)
        const who = Policy.identity(data, existing && !existing.deleted ? existing : null)
        const noted = Policy.noteSource(sourceList, who)
        if (noted.changed) {
            sourceList = noted.list
            sourcesChangedRequested(noted.list)
        }
        const decision = Policy.admit({
            enabled: notificationsEnabled,
            dnd: doNotDisturb,
            sources: sourceList,
            record: who
        })
        if (decision.drop) return
        Queue.receive(state, data, Date.now(), { quiet: decision.quiet })
        refreshCompact()
        revision++
    }
    function close(id) { Queue.close(state, id, false); revision++ }
    function remove(id) { Queue.close(state, id, true); revision++; dismissRequested(id) }
    function removeGroup(key) {
        const ids = records.filter(r => List.groupKey(r) === key).map(r => r.id)
        ids.forEach(id => remove(id))
    }
    function clear() { records.slice().forEach(r => remove(r.id)) }
    function markRead(id) { Queue.markRead(state, id); revision++ }
    function markAllRead(ids) { Queue.markAllRead(state, ids); revision++ }
    function activate(id) {
        const record = records.find(r => r.id === id)
        if (!record) return
        markRead(id)
        activateRequested(record)
    }
    function invoke(id, action) { actionRequested(id, action); markRead(id) }
    function reply(id, text) { replyRequested(id, text); markRead(id) }
    // key — окно или экран, раскрывший остров; страница открыта, если открыта хотя бы в одном.
    function view(key, expanded, pageOpen) {
        expandedViews[key] = expanded; openPages[key] = pageOpen
        Queue.page(state, Object.keys(openPages).some(k => openPages[k])); revision++
    }
}
