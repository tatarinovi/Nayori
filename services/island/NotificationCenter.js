.pragma library
.import "NotificationBanner.js" as Banner
.import "NotificationRead.js" as Read
.import "NotificationStore.js" as Store
.import "NotificationPolicy.js" as Policy
.import "NotificationList.js" as List

// Сборка баннера, прочтения и истории. Время приходит аргументом.
// Политика показа — NotificationPolicy: здесь она не копируется.
// В журнал не пишутся текст уведомления и ответ.

var RETENTION_MS = 90 * 24 * 60 * 60 * 1000
var BANNER_MS = 30000
var READ_MS = 2000

function storePath(env) {
    const from = env || {}
    if (from.NAYORI_NOTIFICATION_STORE) return String(from.NAYORI_NOTIFICATION_STORE)
    return Store.statePath(from)
}

function create() {
    return {
        enabled: true,
        dnd: false,
        sources: [],
        state: emptyState(),
        tabs: {},
        pendingUntil: null,
        banner: { id: null, until: 0, currentId: null, time: 0 }
    }
}

function emptyState() {
    try {
        const state = Store.load("")
        if (state && Array.isArray(state.inbox) && Array.isArray(state.history))
            return { inbox: state.inbox.slice(), history: state.history.slice(), ok: true }
    } catch (error) {}
    return { inbox: [], history: [], ok: true }
}

function configure(session, options, now) {
    const opts = options || {}
    if (opts.enabled !== undefined) session.enabled = !!opts.enabled
    if (opts.dnd !== undefined) session.dnd = !!opts.dnd
    if (opts.sources) session.sources = opts.sources
    if (typeof now === "number") return sync(session, now)
    return false
}

function tabSince(session) {
    const tabs = session.tabs || {}
    let since = null
    const keys = Object.keys(tabs)
    for (let i = 0; i < keys.length; i++) {
        const value = tabs[keys[i]]
        if (value == null) continue
        if (since == null || value < since) since = value
    }
    return since
}

function pageOpen(session) { return tabSince(session) != null }

function find(list, id) {
    const items = list || []
    for (let i = 0; i < items.length; i++) if (items[i].id === id) return items[i]
    return null
}

function findAny(state, id) {
    return find(state.inbox, id) || find(state.history, id)
}

function iconName(value) {
    const text = value == null ? "" : String(value)
    if (!text || text.indexOf("/") >= 0 || text.indexOf("image:") === 0 || text.indexOf("file:") === 0) return ""
    return text
}

function eligible(session, record) {
    if (!record || record.live === false || record.loadedFromDisk) return false
    if (record.quiet || record.closedBy) return false
    return Policy.modeOf(session.sources, record) === "normal"
}

function hiddenField(key) {
    return key === "image" || key === "actions" || key === "hasReply" || key === "replyPlaceholder"
        || key === "reply" || key === "replyText" || key === "inlineReply" || key === "appIcon"
}

function forDisk(state) {
    const out = {}
    const source = state || {}
    const keys = Object.keys(source)
    for (let i = 0; i < keys.length; i++) {
        const key = keys[i]
        if (key === "inbox" || key === "history") out[key] = stripList(source[key])
        else out[key] = source[key]
    }
    if (!out.inbox) out.inbox = []
    if (!out.history) out.history = []
    return out
}

function stripList(list) {
    const out = []
    const items = list || []
    for (let i = 0; i < items.length; i++) {
        const record = items[i]
        if (!record) continue
        const copy = {}
        const keys = Object.keys(record)
        for (let k = 0; k < keys.length; k++) {
            if (!hiddenField(keys[k])) copy[keys[k]] = record[keys[k]]
        }
        if (!copy.appIconName) copy.appIconName = iconName(record.appIcon)
        out.push(copy)
    }
    return out
}

function scrubHistory(state) {
    const items = state && state.history || []
    for (let i = 0; i < items.length; i++) {
        const record = items[i]
        record.live = false
        record.loadedFromDisk = !!record.loadedFromDisk
        record.actions = []
        record.image = ""
        record.hasReply = false
        record.replyPlaceholder = ""
        record.closed = true
        if (!record.appIcon) record.appIcon = record.appIconName || ""
    }
}

function freezeLoaded(state) {
    function mark(list) {
        const items = list || []
        for (let i = 0; i < items.length; i++) {
            const record = items[i]
            record.live = false
            record.loadedFromDisk = true
            record.actions = []
            record.image = ""
            record.hasReply = false
            record.replyPlaceholder = ""
            record.closed = true
            if (!record.appIcon) record.appIcon = record.appIconName || ""
            if (record.arrivedAt == null) record.arrivedAt = record.time
        }
    }
    mark(state.inbox)
    mark(state.history)
    return state
}

function adopt(session, next) {
    if (!next || typeof next !== "object") return
    if (!Array.isArray(next.inbox) && !Array.isArray(next.history)) return
    if (!Array.isArray(next.inbox)) next.inbox = session.state.inbox || []
    if (!Array.isArray(next.history)) next.history = session.state.history || []
    session.state = next
}

function callSelect(input) {
    const out = Banner.select(input) || {}
    const currentId = out.currentId !== undefined ? out.currentId : out.id
    return { currentId: currentId == null ? null : currentId, until: out.until }
}

function callDwell(input) {
    const out = Read.dwell({
        inbox: input.inbox,
        inboxIds: input.inbox.map(function (item) { return item.id }),
        now: input.now,
        tabSince: input.tabSince,
        pendingUntil: input.pendingUntil,
        dwellMs: input.dwellMs
    })
    if (Array.isArray(out)) return { readIds: out, pendingUntil: null }
    const readIds = out && (out.readIds || out.ids) || []
    const pendingUntil = out && Object.prototype.hasOwnProperty.call(out, "pendingUntil") ? out.pendingUntil : null
    return { readIds: readIds, pendingUntil: pendingUntil }
}

function syncBanner(session, now) {
    const items = []
    const inbox = session.state.inbox || []
    for (let i = 0; i < inbox.length; i++) {
        const record = inbox[i]
        items.push({ id: record.id, time: Number(record.time) || 0, eligible: eligible(session, record) })
    }
    const previous = session.banner || {}
    const shown = previous.id != null ? { id: previous.id, until: previous.until } : null
    // Ушедшая из списка запись остаётся неподходящим ориентиром: новое её сменяет,
    // более старое само не занимает остров. Так устроен select, если id ещё в items.
    if (shown && !find(inbox, shown.id))
        items.push({ id: shown.id, time: Number(previous.time) || 0, eligible: false })
    const next = callSelect({ items: items, now: now, shown: shown, dwellMs: BANNER_MS })
    let time = previous.time
    if (next.currentId != null) {
        for (let i = 0; i < items.length; i++) {
            if (items[i].id === next.currentId) time = items[i].time
        }
    }
    const currentId = next.currentId == null ? null : next.currentId
    session.banner = {
        id: currentId != null ? currentId : (shown ? shown.id : null),
        until: next.until != null ? next.until : (shown ? shown.until : 0),
        currentId: currentId,
        time: time == null ? 0 : time
    }
}

function syncRead(session, now) {
    const inbox = []
    const items = session.state.inbox || []
    for (let i = 0; i < items.length; i++) {
        const record = items[i]
        inbox.push({ id: record.id, arrivedAt: record.arrivedAt != null ? record.arrivedAt : record.time })
    }
    const result = callDwell({
        inbox: inbox,
        now: now,
        tabSince: tabSince(session),
        pendingUntil: session.pendingUntil,
        dwellMs: READ_MS
    })
    session.pendingUntil = result.pendingUntil
    if (!result.readIds || !result.readIds.length) return
    for (let i = 0; i < items.length; i++) {
        const record = items[i]
        for (let j = 0; j < result.readIds.length; j++) {
            if (result.readIds[j] === record.id) record.read = true
        }
    }
}

function signature(session) {
    const banner = session.banner || {}
    let reads = ""
    const inbox = session.state.inbox || []
    for (let i = 0; i < inbox.length; i++) reads += inbox[i].id + (inbox[i].read ? "1" : "0") + ","
    return (banner.currentId == null ? "" : banner.currentId) + ":" + (banner.until || 0) + "|" + reads
}

function sync(session, now) {
    const before = signature(session)
    syncBanner(session, now)
    syncRead(session, now)
    return signature(session) !== before
}

function tick(session, now) { return sync(session, now) }

function needsClock(session, now) {
    const banner = session.banner
    if (banner && banner.currentId != null && banner.until > now) return true
    if (tabSince(session) == null) return false
    const inbox = session.state.inbox || []
    for (let i = 0; i < inbox.length; i++) if (!inbox[i].read) return true
    return false
}

function ingest(session, data, now) {
    const payload = data || {}
    const before = session.sources
    const existing = findAny(session.state, payload.id)
    if (existing && existing.closedBy === "user") return { dropped: true, sourcesChanged: false }
    const who = Policy.identity(payload, existing)
    const noted = Policy.noteSource(session.sources, who)
    session.sources = noted.list
    const decision = Policy.admit({
        enabled: session.enabled,
        dnd: session.dnd,
        sources: session.sources,
        record: who
    })
    const sourcesChanged = !Policy.same(before, session.sources)
    if (decision.drop) return { dropped: true, sourcesChanged: sourcesChanged }
    const quiet = !!(existing && existing.quiet) || !!decision.quiet
    const record = {
        id: payload.id,
        appName: who.appName || "",
        summary: payload.summary != null ? payload.summary : (existing && existing.summary) || "",
        body: payload.body != null ? payload.body : (existing && existing.body) || "",
        time: existing ? existing.time : now,
        arrivedAt: existing && existing.arrivedAt != null ? existing.arrivedAt : (existing ? existing.time : now),
        read: existing ? !!existing.read : false,
        sourceKey: Policy.sourceKey(who),
        desktopEntry: who.desktopEntry || "",
        appIconName: iconName(payload.appIcon) || (existing && existing.appIconName) || "",
        appIcon: payload.appIcon || (existing && existing.appIcon) || "",
        closedBy: "",
        quiet: quiet,
        live: true,
        loadedFromDisk: false,
        closed: false,
        image: payload.image || "",
        actions: Array.isArray(payload.actions) ? payload.actions : [],
        hasReply: !!payload.hasReply,
        replyPlaceholder: payload.replyPlaceholder || "",
        urgency: payload.urgency || 0
    }
    if (existing && existing.closedBy === "app") {
        session.state.history = (session.state.history || []).filter(function (item) { return item.id !== payload.id })
    }
    const inbox = (session.state.inbox || []).filter(function (item) { return item.id !== payload.id })
    inbox.unshift(record)
    session.state.inbox = inbox
    sync(session, now)
    return { dropped: false, sourcesChanged: sourcesChanged }
}

function view(session, key, open, now) {
    if (!session.tabs) session.tabs = {}
    if (open) {
        if (session.tabs[key] == null) session.tabs[key] = now
    } else delete session.tabs[key]
    return sync(session, now)
}

function closeUser(session, ids, now) {
    const next = Store.closeToHistory(session.state, ids, now, "user")
    adopt(session, next)
    scrubHistory(session.state)
    sync(session, now)
}

function closeGroup(session, key, now) {
    const ids = []
    const inbox = session.state.inbox || []
    for (let i = 0; i < inbox.length; i++) {
        const record = inbox[i]
        if (record.sourceKey === key || List.groupKey(record) === key) ids.push(record.id)
    }
    if (!ids.length) return
    closeUser(session, ids, now)
}

function clearAll(session, now) {
    const next = Store.clearInbox(session.state, now)
    adopt(session, next)
    scrubHistory(session.state)
    sync(session, now)
}

function closeApp(session, id, now) {
    const next = Store.closeToHistory(session.state, [id], now, "app")
    adopt(session, next)
    scrubHistory(session.state)
    sync(session, now)
}

function markRead(session, ids) {
    const all = ids == null
    function touch(list) {
        const items = list || []
        for (let i = 0; i < items.length; i++) {
            const record = items[i]
            if (all || ids.indexOf(record.id) >= 0) record.read = true
        }
    }
    touch(session.state.inbox)
    touch(session.state.history)
}

function load(session, text, now) {
    let state
    try {
        state = Store.load(text == null ? "" : String(text))
    } catch (error) {
        state = null
    }
    if (!state || !Array.isArray(state.inbox) || !Array.isArray(state.history)) state = emptyState()
    const before = state.inbox.length + state.history.length
    try {
        const purged = Store.purge(state, now, RETENTION_MS)
        if (purged && Array.isArray(purged.inbox) && Array.isArray(purged.history)) state = purged
    } catch (error) {}
    freezeLoaded(state)
    session.state = state
    session.banner = { id: null, until: 0, currentId: null, time: 0 }
    session.pendingUntil = null
    session.purged = state.inbox.length + state.history.length < before
    sync(session, now)
    return session
}

function serialize(session, now) {
    if (typeof now === "number") {
        try {
            const purged = Store.purge(session.state, now, RETENTION_MS)
            adopt(session, purged)
        } catch (error) {}
    }
    return Store.serialize(forDisk(session.state))
}

function searchHistory(session, query) {
    return Store.searchHistory(session.state, query == null ? "" : String(query))
}

function historyGroups(session, query) {
    return searchHistory(session, query)
}

function deleteHistory(session, ids) {
    const list = Array.isArray(ids) ? ids : [ids]
    adopt(session, Store.deleteHistory(session.state, list))
    scrubHistory(session.state)
}

function deleteHistoryGroup(session, sourceKey) {
    adopt(session, Store.deleteHistoryGroup(session.state, sourceKey))
    scrubHistory(session.state)
}

function clearHistory(session) {
    adopt(session, Store.clearHistory(session.state))
}

function inbox(session) { return session.state.inbox || [] }
function history(session) { return session.state.history || [] }

function banner(session) {
    const current = session.banner || {}
    return { currentId: current.currentId == null ? null : current.currentId, until: current.until || 0 }
}

function bannerRecord(session) {
    const id = session.banner && session.banner.currentId
    if (id == null) return null
    return find(session.state.inbox, id)
}

function offeredActions(record) {
    if (!record || record.live === false || record.loadedFromDisk || record.closed) return []
    return Array.isArray(record.actions) ? record.actions : []
}

function offeredImage(record) {
    if (!record || record.live === false || record.loadedFromDisk) return ""
    return record.image ? String(record.image) : ""
}
