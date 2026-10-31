import QtQuick
import Quickshell
import Quickshell.Io
import "NotificationQueue.js" as Queue
import "NotificationList.js" as List
import "NotificationPolicy.js" as Policy
import "NotificationStore.js" as Store
import "NotificationCenter.js" as Center

// Журнал уведомлений. Очередь — NotificationQueue.js, правила — NotificationPolicy.js.
// История пишется в $XDG_STATE_HOME/nayori/notifications.json. Картинки и действия в файл не попадают.
QtObject {
    id: root
    property var state: Queue.create()
    property var archive: Store.create()
    property int revision: 0
    property var expandedViews: ({})
    property var openPages: ({})
    property bool notificationsEnabled: true
    property bool doNotDisturb: false
    property var sources: []
    property var sourceList: []
    // Включает запись на диск. Стенды оставляют false, чтобы не трогать настоящий журнал.
    property bool storeEnabled: false
    readonly property bool persist: {
        if (!storeEnabled) return false
        const flag = Quickshell.env("NAYORI_NOTIFICATION_STATE")
        if (flag === "off" || flag === "0") return false
        if (Quickshell.env("QT_QPA_PLATFORM") === "offscreen") return false
        return true
    }
    readonly property string storageFile: {
        const flag = Quickshell.env("NAYORI_NOTIFICATION_STATE")
        if (flag && flag !== "off" && flag !== "0")
            return flag.slice(-5) === ".json" ? flag : flag.replace(/\/+$/, "") + "/notifications.json"
        return Store.statePath({
            XDG_STATE_HOME: Quickshell.env("XDG_STATE_HOME"),
            HOME: Quickshell.env("HOME")
        })
    }
    readonly property string storageDirectory: storageFile.slice(0, Math.max(0, storageFile.lastIndexOf("/")))
    property bool storeReady: !persist
    property bool preserveFile: false
    property bool storeDirty: false
    property bool storeSaving: false
    // Вкладка «Уведомления» читает записи через 2 с. Баннер этот срок не ставит.
    property var dwellState: Center.create()
    property bool dwellRunning: false
    signal sourcesChangedRequested(var sources)
    // Входящие: не удалённые и не закрытые. Закрытые лежат в history. Копии видны привязкам.
    readonly property var records: { if (revision < 0) return []; return state.records.filter(r => !r.deleted && !r.closed).map(r => Object.assign({}, r)) }
    readonly property int unreadCount: { if (revision < 0) return 0; return state.records.filter(r => !r.deleted && !r.closed && !r.read).length }
    readonly property var history: { if (revision < 0) return []; return archive.history.map(r => Object.assign({}, r)) }
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

    function mirrorInbox() {
        const visible = []
        state.records.forEach(record => {
            if (!record.deleted && !record.closed) visible.push(Store.fromLive(record))
        })
        archive.inbox = visible
    }
    function scheduleSave() {
        if (!persist || !storeReady || preserveFile) return
        storeDirty = true
        storeTimer.restart()
    }
    function searchHistory(query) { return Store.searchHistory(archive, query) }
    function deleteHistory(ids) {
        Store.deleteHistory(archive, ids)
        revision++
        scheduleSave()
    }
    function deleteHistoryGroup(sourceKey) {
        Store.deleteHistoryGroup(archive, sourceKey)
        revision++
        scheduleSave()
    }
    function clearHistory() {
        Store.clearHistory(archive)
        revision++
        scheduleSave()
    }
    // Запись с диска не всплывает в свёрнутом острове: seen и live === false.
    function adoptDisk(item) {
        Queue.receive(state, {
            id: item.id, appName: item.appName, summary: item.summary, body: item.body,
            desktopEntry: item.desktopEntry, appIcon: item.appIconName || "", actions: []
        }, item.time, { quiet: false })
        const row = Queue.find(state, item.id)
        if (!row || row.deleted) return
        row.read = item.read === true
        row.seen = true
        row.closed = false
        row.live = false
        row.loadedFromDisk = true
        row.actions = []
        row.hasReply = false
        row.image = ""
    }
    function restoreStore(text) {
        if (storeReady) return
        try { root.applyStore(text || "") } catch (error) { storeReady = true }
    }
    function applyStore(text) {
        let parsed
        try { parsed = Store.load(text || "") } catch (error) { parsed = Store.load("") }
        if (!parsed || parsed.preserve) {
            preserveFile = !!(parsed && parsed.preserve)
            storeReady = true
            return
        }
        const hadSession = state.records.some(record => !record.deleted) || archive.history.length > 0
        const before = parsed.inbox.length + parsed.history.length
        Store.purge(parsed, Date.now(), Store.maxAge())
        const sessionIds = {}
        archive.history.forEach(record => { sessionIds[String(record.id)] = true })
        const history = archive.history.slice()
        const seen = {}
        history.forEach(record => { seen[String(record.id)] = true })
        parsed.history.forEach(record => {
            if (seen[String(record.id)]) return
            seen[String(record.id)] = true
            history.push(record)
        })
        archive.history = history
        const present = {}
        state.records.forEach(record => { present[String(record.id)] = true })
        for (let i = parsed.inbox.length - 1; i >= 0; i--) {
            const item = parsed.inbox[i]
            if (present[String(item.id)] || sessionIds[String(item.id)]) continue
            adoptDisk(item)
        }
        const openIds = {}
        state.records.forEach(record => { if (!record.deleted && !record.closed) openIds[String(record.id)] = true })
        archive.history = archive.history.filter(record => !openIds[String(record.id)])
        refreshCompact()
        mirrorInbox()
        storeReady = true
        revision++
        if (hadSession || before !== parsed.inbox.length + parsed.history.length) scheduleSave()
    }
    function flushStore(blocking) {
        storeTimer.stop()
        if (!persist || !storeReady || preserveFile || !storeFile.path) return
        try {
            if (storeSaving && blocking === true) storeFile.waitForJob()
            if (storeSaving) return
            mirrorInbox()
            Store.purge(archive, Date.now(), Store.maxAge())
            const text = Store.serialize(archive)
            if (storeFile.text() === text) { storeDirty = false; return }
            storeSaving = true
            storeDirty = false
            storeFile.blockWrites = blocking === true
            storeFile.setText(text)
        } catch (error) {
            storeSaving = false
            storeDirty = true
        }
    }

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
        if (existing && existing.deleted) return
        Store.deleteHistory(archive, [data && data.id])
        Queue.receive(state, data, Date.now(), { quiet: decision.quiet })
        const row = Queue.find(state, data && data.id)
        if (row && !row.deleted) {
            row.live = true
            row.loadedFromDisk = false
        }
        refreshCompact()
        mirrorInbox()
        revision++
        scheduleSave()
        noteDwell(Date.now())
    }
    // Приложение закрыло уведомление: запись остаётся в истории, сигнал закрытия наружу не шлём.
    function close(id) {
        const row = Queue.find(state, id)
        if (row && !row.deleted && !row.closed) {
            mirrorInbox()
            Store.closeToHistory(archive, [id], Date.now(), "app")
        }
        Queue.close(state, id, false)
        revision++
        scheduleSave()
    }
    function remove(id) {
        const row = Queue.find(state, id)
        if (row && !row.deleted && !row.closed) {
            mirrorInbox()
            Store.closeToHistory(archive, [id], Date.now(), "user")
        }
        Queue.close(state, id, true)
        revision++
        scheduleSave()
        dismissRequested(id)
    }
    function removeGroup(key) {
        const ids = records.filter(r => List.groupKey(r) === key).map(r => r.id)
        ids.forEach(id => remove(id))
    }
    function clear() { records.slice().forEach(r => remove(r.id)) }
    function markRead(id) { Queue.markRead(state, id); revision++; scheduleSave() }
    function markAllRead(ids) { Queue.markAllRead(state, ids); revision++; scheduleSave() }
    function activate(id) {
        const record = records.find(r => r.id === id)
        if (!record) return
        markRead(id)
        activateRequested(record)
    }
    function invoke(id, action) { actionRequested(id, action); markRead(id) }
    function reply(id, text) { replyRequested(id, text); markRead(id) }
    // key — окно или экран, раскрывший остров; страница открыта, если открыта хотя бы в одном.
    function projectDwell() {
        const inbox = []
        state.records.forEach(record => {
            if (record.deleted || record.closed) return
            inbox.push({
                id: record.id, time: record.time, arrivedAt: record.time, read: !!record.read,
                live: record.live !== false, loadedFromDisk: !!record.loadedFromDisk, quiet: !!record.quiet,
                appName: record.appName || "", desktopEntry: record.desktopEntry || ""
            })
        })
        dwellState.state.inbox = inbox
        dwellState.sources = sourceList
        dwellState.enabled = notificationsEnabled
        dwellState.dnd = doNotDisturb
    }
    function pullRead() {
        let changed = false
        const inbox = dwellState.state.inbox || []
        inbox.forEach(copy => {
            if (!copy.read) return
            const row = Queue.find(state, copy.id)
            if (row && !row.deleted && !row.read) {
                row.read = true
                changed = true
            }
        })
        if (changed) mirrorInbox()
        return changed
    }
    function armDwell() {
        if (!Center.pageOpen(dwellState)) {
            dwellRunning = false
            return
        }
        dwellRunning = state.records.some(record => !record.deleted && !record.closed && !record.read)
    }
    function noteDwell(now) {
        projectDwell()
        if (!Center.pageOpen(dwellState)) {
            armDwell()
            return
        }
        Center.tick(dwellState, now)
        if (pullRead()) {
            revision++
            scheduleSave()
        }
        armDwell()
    }
    // key — окно или экран. Вкладка хотя бы на одном острове запускает две секунды прочтения.
    function view(key, expanded, pageOpen) {
        expandedViews[key] = expanded; openPages[key] = pageOpen
        Queue.page(state, Object.keys(openPages).some(k => openPages[k]))
        projectDwell()
        Center.view(dwellState, key, pageOpen, Date.now())
        if (pullRead()) scheduleSave()
        revision++
        armDwell()
    }
    property Timer dwellTimer: Timer {
        interval: 200
        repeat: true
        running: root.dwellRunning
        onTriggered: root.noteDwell(Date.now())
    }

    property Timer storeTimer: Timer {
        interval: 250
        onTriggered: root.flushStore(false)
    }
    property Process storeDirectory: Process {
        command: ["mkdir", "-p", "--", root.storageDirectory]
        running: root.persist
        onExited: code => {
            if (!root.persist) return
            if (code === 0) root.storeFile.path = root.storageFile
            else root.storeReady = true
        }
    }
    property FileView storeFile: FileView {
        atomicWrites: true
        printErrors: false
        watchChanges: false
        onLoaded: {
            try { root.restoreStore(text()) } catch (error) { if (!root.storeReady) root.storeReady = true }
        }
        onLoadFailed: function(error) {
            if (root.storeReady) return
            root.storeReady = true
        }
        onSaved: {
            root.storeSaving = false
            if (root.storeDirty) root.storeTimer.restart()
        }
        onSaveFailed: {
            root.storeSaving = false
            root.storeDirty = true
        }
    }
    Component.onDestruction: root.flushStore(true)
}
