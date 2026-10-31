.pragma library

// История уведомлений. Время передаётся снаружи, файл читается и пишется отдельно.
// На диске только поля записи: без картинок, путей к снимкам и действий.
// Текст уведомления в журнал оболочки не пишется.

var MAX_AGE_MS = 7776000000
var FIELDS = ["id", "appName", "summary", "body", "time", "read", "sourceKey", "desktopEntry", "appIconName", "closedBy"]

function maxAge() { return MAX_AGE_MS }

function create() { return { inbox: [], history: [], ok: true, preserve: false } }

function text(value, max) {
    if (value === undefined || value === null) return ""
    var s = String(value)
    return s.length > max ? s.slice(0, max) : s
}

function cleanKey(value) {
    var s = text(value, 256).replace(/^\s+|\s+$/g, "")
    if (!s || /[\u0000-\u001f]/.test(s)) return ""
    return s
}

function sourceKeyOf(record) {
    if (!record) return ""
    var existing = cleanKey(record.sourceKey)
    if (existing.indexOf("entry:") === 0 || existing.indexOf("name:") === 0) {
        if (cleanKey(existing.slice(existing.indexOf(":") + 1))) return existing
    }
    var entry = cleanKey(record.desktopEntry)
    if (entry) return "entry:" + entry
    var name = cleanKey(record.appName)
    if (name) return "name:" + name
    return ""
}

function iconNameOf(record) {
    var name = cleanKey(record && (record.appIconName || record.appIcon))
    if (!name || name.charAt(0) === "/" || name.indexOf("file:") === 0 || name.indexOf("image:") === 0 || name.indexOf("\\") >= 0) return ""
    return name
}

function closedByOf(value) { return value === "user" || value === "app" ? value : "" }

function timeOf(value) {
    var n = Number(value)
    return isFinite(n) ? n : 0
}

function validId(id) {
    if (typeof id === "number") return isFinite(id)
    if (typeof id === "string") return id.length > 0 && id.length <= 64 && cleanKey(id) === id
    return false
}

function persistentShape(record, closedBy) {
    var source = record || {}
    return {
        id: source.id,
        appName: text(source.appName, 256),
        summary: text(source.summary, 2000),
        body: text(source.body, 8000),
        time: timeOf(source.time),
        read: source.read === true,
        sourceKey: sourceKeyOf(source),
        desktopEntry: cleanKey(source.desktopEntry),
        appIconName: iconNameOf(source),
        closedBy: closedByOf(closedBy)
    }
}

function fromLive(record) {
    var item = persistentShape(record, "")
    var fromDisk = !!(record && record.loadedFromDisk)
    var dead = !!(record && record.live === false)
    item.live = !fromDisk && !dead
    item.loadedFromDisk = fromDisk
    item.appIcon = item.appIconName
    return item
}

function sanitize(record) {
    if (!record || typeof record !== "object" || Array.isArray(record) || !validId(record.id)) return null
    var item = persistentShape(record, record.closedBy)
    item.live = false
    item.loadedFromDisk = true
    item.appIcon = item.appIconName
    return item
}

function sanitizeList(value) {
    var out = []
    var seen = {}
    if (!Array.isArray(value)) return out
    for (var i = 0; i < value.length; i++) {
        var item = sanitize(value[i])
        if (!item) continue
        var key = String(item.id)
        if (seen[key]) {
            for (var j = 0; j < out.length; j++) if (String(out[j].id) === key) out[j] = item
        } else {
            seen[key] = true
            out.push(item)
        }
    }
    return out
}

function load(text) {
    if (text === undefined || text === null) return { inbox: [], history: [], ok: false, preserve: false }
    var raw = String(text).replace(/^\s+|\s+$/g, "")
    if (!raw) return { inbox: [], history: [], ok: false, preserve: false }
    var data
    try { data = JSON.parse(raw) } catch (e) { return { inbox: [], history: [], ok: false, preserve: false } }
    if (!data || typeof data !== "object" || Array.isArray(data)) return { inbox: [], history: [], ok: false, preserve: false }
    if (data.version !== undefined && data.version !== 1) return { inbox: [], history: [], ok: false, preserve: true }
    return { inbox: sanitizeList(data.inbox), history: sanitizeList(data.history), ok: true, preserve: false }
}

function packRecord(record) {
    var shaped = persistentShape(record, record.closedBy)
    var out = {}
    for (var i = 0; i < FIELDS.length; i++) out[FIELDS[i]] = shaped[FIELDS[i]]
    return out
}

function pack(list) {
    var out = []
    for (var i = 0; i < (list || []).length; i++) {
        var record = list[i]
        if (!record || !validId(record.id)) continue
        out.push(packRecord(record))
    }
    return out
}

function serialize(state) {
    var current = ensure(state)
    return JSON.stringify({ version: 1, inbox: pack(current.inbox), history: pack(current.history) }) + "\n"
}

function ensure(state) {
    if (!state || typeof state !== "object" || Array.isArray(state)) return create()
    if (!Array.isArray(state.inbox)) state.inbox = []
    if (!Array.isArray(state.history)) state.history = []
    return state
}

function sameId(record, id) { return !!record && String(record.id) === String(id) }

function upsertHistory(state, record) {
    for (var i = 0; i < state.history.length; i++) {
        if (sameId(state.history[i], record.id)) { state.history[i] = record; return }
    }
    state.history.push(record)
}

function wanted(ids) {
    var map = {}
    var list = Array.isArray(ids) ? ids : [ids]
    for (var i = 0; i < list.length; i++) {
        if (list[i] === undefined || list[i] === null || list[i] === "") continue
        map[String(list[i])] = true
    }
    return map
}

// Новая запись встаёт в начало. Повтор того же id остаётся на своём месте.
function insertInbox(state, record, now) {
    var current = ensure(state)
    if (!record || !validId(record.id)) return current
    var next = fromLive(record)
    if (!(next.time > 0)) next.time = timeOf(now)
    var index = -1
    for (var i = 0; i < current.inbox.length; i++) if (sameId(current.inbox[i], next.id)) { index = i; break }
    if (index >= 0) current.inbox[index] = next
    else current.inbox.unshift(next)
    var history = []
    for (var h = 0; h < current.history.length; h++) if (!sameId(current.history[h], next.id)) history.push(current.history[h])
    current.history = history
    return current
}

// by "user" — закрыл человек. by "app" — закрыло приложение. Оба варианта остаются в истории.
function closeToHistory(state, ids, now, by) {
    var current = ensure(state)
    var map = wanted(ids)
    var kept = []
    var moved = []
    for (var i = 0; i < current.inbox.length; i++) {
        if (current.inbox[i] && map[String(current.inbox[i].id)]) moved.push(current.inbox[i])
        else kept.push(current.inbox[i])
    }
    current.inbox = kept
    var clock = Number(now)
    for (var j = 0; j < moved.length; j++) {
        var next = persistentShape(moved[j], closedByOf(by))
        if (!(next.time > 0) && isFinite(clock)) next.time = clock
        next.read = moved[j].read === true
        next.live = false
        next.loadedFromDisk = false
        next.appIcon = next.appIconName
        upsertHistory(current, next)
    }
    return current
}

function clearInbox(state, now) {
    var current = ensure(state)
    var ids = []
    for (var i = 0; i < current.inbox.length; i++) if (current.inbox[i]) ids.push(current.inbox[i].id)
    return closeToHistory(current, ids, now, "user")
}

function deleteHistory(state, ids) {
    var current = ensure(state)
    var map = wanted(ids)
    var kept = []
    for (var i = 0; i < current.history.length; i++) if (!current.history[i] || !map[String(current.history[i].id)]) kept.push(current.history[i])
    current.history = kept
    return current
}

function groupKey(record) { return sourceKeyOf(record) || "other" }

function deleteHistoryGroup(state, sourceKey) {
    var current = ensure(state)
    var key = String(sourceKey || "")
    var kept = []
    for (var i = 0; i < current.history.length; i++) if (groupKey(current.history[i]) !== key) kept.push(current.history[i])
    current.history = kept
    return current
}

function clearHistory(state) {
    var current = ensure(state)
    current.history = []
    return current
}

function stale(record, clock, age) {
    var t = Number(record && record.time)
    if (!isFinite(t) || t <= 0) return false
    return clock - t > age
}

function purge(state, now, maxAgeMs) {
    var current = ensure(state)
    var clock = Number(now)
    var age = maxAgeMs === undefined || maxAgeMs === null ? MAX_AGE_MS : Number(maxAgeMs)
    if (!isFinite(clock) || !isFinite(age) || age < 0) return current
    current.inbox = current.inbox.filter(function(r) { return !stale(r, clock, age) })
    current.history = current.history.filter(function(r) { return !stale(r, clock, age) })
    return current
}

function newestFirst(list) {
    return (list || []).slice().sort(function(a, b) {
        var dt = timeOf(b && b.time) - timeOf(a && a.time)
        if (dt) return dt
        var ai = Number(a && a.id), bi = Number(b && b.id)
        if (isFinite(ai) && isFinite(bi) && ai !== bi) return bi - ai
        var as = String(a && a.id), bs = String(b && b.id)
        if (as < bs) return 1
        if (as > bs) return -1
        return 0
    })
}

function matches(record, query) {
    if (!query) return true
    var name = String(record.appName || "").toLowerCase()
    var summary = String(record.summary || "").toLowerCase()
    var body = String(record.body || "").toLowerCase()
    return name.indexOf(query) >= 0 || summary.indexOf(query) >= 0 || body.indexOf(query) >= 0
}

function copyView(record) {
    var item = persistentShape(record, record && record.closedBy)
    item.live = record.live === true
    item.loadedFromDisk = record.loadedFromDisk === true
    item.appIcon = item.appIconName
    return item
}

function groupRecords(records) {
    var map = {}
    var order = []
    for (var i = 0; i < records.length; i++) {
        var view = copyView(records[i])
        var key = groupKey(view)
        if (!map[key]) {
            map[key] = {
                key: key, sourceKey: key, appName: view.appName || "Приложение",
                appIcon: view.appIconName, appIconName: view.appIconName, desktopEntry: view.desktopEntry, items: []
            }
            order.push(key)
        }
        var group = map[key]
        if (!group.appName || group.appName === "Приложение") group.appName = view.appName || group.appName
        group.items.push(view)
    }
    var groups = []
    for (var g = 0; g < order.length; g++) {
        var item = map[order[g]]
        item.count = item.items.length
        item.unread = 0
        item.ids = []
        for (var n = 0; n < item.items.length; n++) {
            if (!item.items[n].read) item.unread++
            item.ids.push(item.items[n].id)
        }
        item.time = item.items[0].time
        groups.push(item)
    }
    return groups
}

function searchHistory(state, query) {
    var current = ensure(state)
    var q = String(query || "").replace(/^\s+|\s+$/g, "").toLowerCase()
    var matched = []
    for (var i = 0; i < current.history.length; i++) if (matches(current.history[i], q)) matched.push(current.history[i])
    return groupRecords(newestFirst(matched))
}

function stateDirectory(xdgState, home) {
    var base = xdgState ? String(xdgState).replace(/\/+$/, "") : String(home || "") + "/.local/state"
    return base + "/nayori"
}

function statePath(env) {
    var e = env || {}
    return stateDirectory(e.XDG_STATE_HOME, e.HOME) + "/notifications.json"
}

function readFile(fs, filePath) {
    try {
        if (!fs || !filePath) return ""
        return fs.readFileSync(filePath, "utf8")
    } catch (e) { return "" }
}

function writeFile(fs, filePath, text) {
    var tmp = ""
    var fd = -1
    try {
        if (!fs || !filePath) return false
        var slash = String(filePath).lastIndexOf("/")
        var dir = slash > 0 ? String(filePath).slice(0, slash) : ""
        if (dir) fs.mkdirSync(dir, { recursive: true, mode: 0o700 })
        var stamp = (typeof process !== "undefined" && process && process.pid) ? process.pid : 0
        tmp = filePath + "." + stamp + ".tmp"
        fd = fs.openSync(tmp, "w", 0o600)
        fs.writeSync(fd, String(text))
        if (typeof fs.fsyncSync === "function") fs.fsyncSync(fd)
        fs.closeSync(fd)
        fd = -1
        fs.renameSync(tmp, filePath)
        tmp = ""
        return true
    } catch (e) {
        if (fd >= 0) { try { fs.closeSync(fd) } catch (ignore) {} }
        if (tmp) { try { fs.unlinkSync(tmp) } catch (ignore2) {} }
        return false
    }
}

function loadFromFile(fs, filePath, now) {
    var state = load(readFile(fs, filePath))
    purge(state, now, MAX_AGE_MS)
    return state
}

function saveToFile(fs, filePath, state, now) {
    var current = ensure(state)
    if (current.preserve) return false
    purge(current, now, MAX_AGE_MS)
    return writeFile(fs, filePath, serialize(current))
}
