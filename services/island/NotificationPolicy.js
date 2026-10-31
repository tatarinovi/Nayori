// Правила показа уведомлений. Без QML: проверяется вместе с очередью в tests/notifications.cjs.
//
// Источник — desktopEntry, если он есть. Иначе имя приложения.
// Режим: normal (свёрнутый и развёрнутый остров), expanded (только история), off (не сохранять).

const MONTHS = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]
const MAX_SOURCES = 200

function clean(value) {
    const text = value === undefined || value === null ? "" : String(value).trim()
    if (!text || text.length > 256 || /[\x00-\x1f]/.test(text)) return ""
    return text
}

function sourceKey(record) {
    if (!record) return ""
    const entry = clean(record.desktopEntry)
    if (entry) return "entry:" + entry
    const name = clean(record.appName)
    if (name) return "name:" + name
    return ""
}

function identity(data, existing) {
    return {
        desktopEntry: clean(data && data.desktopEntry) || clean(existing && existing.desktopEntry),
        appName: clean(data && data.appName) || clean(existing && existing.appName)
    }
}

function normalizeMode(value) {
    return value === "expanded" || value === "off" ? value : "normal"
}

function sourceTitle(record, key) {
    return clean(record && record.appName) || clean(record && record.desktopEntry) || clean(record && record.title) || key.slice(key.indexOf(":") + 1)
}

function normalizeSources(value) {
    const out = []
    const seen = {}
    if (!Array.isArray(value)) return out
    for (let i = 0; i < value.length && out.length < MAX_SOURCES; i++) {
        const item = value[i]
        if (!item || typeof item !== "object") continue
        const key = clean(item.key)
        if (!key || seen[key] || (key.indexOf("entry:") !== 0 && key.indexOf("name:") !== 0)) continue
        const id = key.slice(key.indexOf(":") + 1)
        if (!clean(id)) continue
        seen[key] = true
        const desktopEntry = key.indexOf("entry:") === 0 ? id : clean(item.desktopEntry)
        const appName = clean(item.appName) || (key.indexOf("name:") === 0 ? id : "")
        out.push({
            key: key,
            title: clean(item.title) || appName || desktopEntry || id,
            desktopEntry: desktopEntry,
            appName: appName,
            mode: normalizeMode(item.mode)
        })
    }
    return out
}

function same(left, right) {
    const a = normalizeSources(left)
    const b = normalizeSources(right)
    if (a.length !== b.length) return false
    for (let i = 0; i < a.length; i++) {
        if (a[i].key !== b[i].key || a[i].title !== b[i].title || a[i].desktopEntry !== b[i].desktopEntry
            || a[i].appName !== b[i].appName || a[i].mode !== b[i].mode) return false
    }
    return true
}

function modeOf(sources, record) {
    const key = sourceKey(record)
    if (!key) return "normal"
    const list = sources || []
    for (let i = 0; i < list.length; i++)
        if (list[i].key === key) return normalizeMode(list[i].mode)
    return "normal"
}

function noteSource(sources, record) {
    const list = normalizeSources(sources)
    const key = sourceKey(record)
    if (!key) return { list: list, changed: false }
    const title = sourceTitle(record, key)
    for (let i = 0; i < list.length; i++) {
        if (list[i].key !== key) continue
        const appName = clean(record.appName) || list[i].appName
        const desktopEntry = clean(record.desktopEntry) || list[i].desktopEntry
        if (list[i].title === title && list[i].appName === appName && list[i].desktopEntry === desktopEntry)
            return { list: list, changed: false }
        const next = list.slice()
        next[i] = { key: key, title: title, desktopEntry: desktopEntry, appName: appName, mode: list[i].mode }
        return { list: next, changed: true }
    }
    if (list.length >= MAX_SOURCES) return { list: list, changed: false }
    list.push({
        key: key,
        title: title,
        desktopEntry: clean(record.desktopEntry),
        appName: clean(record.appName),
        mode: "normal"
    })
    return { list: list, changed: true }
}

// Сохранённые режимы важнее. Из incoming берутся новые ключи и более свежие имена.
function mergeSources(saved, incoming) {
    const base = normalizeSources(saved)
    const extra = normalizeSources(incoming)
    const index = {}
    for (let i = 0; i < base.length; i++) index[base[i].key] = i
    let changed = false
    for (let i = 0; i < extra.length && base.length < MAX_SOURCES; i++) {
        const item = extra[i]
        const at = index[item.key]
        if (at === undefined) {
            base.push(item)
            index[item.key] = base.length - 1
            changed = true
            continue
        }
        const current = base[at]
        const title = item.title || current.title
        const appName = item.appName || current.appName
        const desktopEntry = item.desktopEntry || current.desktopEntry
        if (current.title !== title || current.appName !== appName || current.desktopEntry !== desktopEntry) {
            base[at] = { key: current.key, title: title, desktopEntry: desktopEntry, appName: appName, mode: current.mode }
            changed = true
        }
    }
    return { list: base, changed: changed }
}

function setMode(sources, key, mode) {
    const list = normalizeSources(sources)
    const nextMode = normalizeMode(mode)
    for (let i = 0; i < list.length; i++) {
        if (list[i].key !== key) continue
        if (list[i].mode === nextMode) return { list: list, changed: false }
        const next = list.slice()
        next[i] = {
            key: list[i].key, title: list[i].title, desktopEntry: list[i].desktopEntry,
            appName: list[i].appName, mode: nextMode
        }
        return { list: next, changed: true }
    }
    return { list: list, changed: false }
}

function admit(options) {
    const enabled = !options || options.enabled !== false
    const record = options && options.record || {}
    const sources = options && options.sources || []
    const mode = modeOf(sources, record)
    if (!enabled || mode === "off") return { drop: true, quiet: false, mode: mode }
    return { drop: false, quiet: !!(options && options.dnd), mode: mode }
}

function dndActive(manual, until, now) {
    if (manual === true) return true
    const end = Number(until)
    const clock = Number(now)
    return isFinite(end) && isFinite(clock) && end > clock
}

function untilFromMinutes(now, minutes) {
    const count = Math.round(Number(minutes))
    const clock = Number(now)
    if (!isFinite(count) || !isFinite(clock)) return 0
    return clock + Math.max(1, Math.min(1440, count)) * 60000
}

function pad(value) { return (value < 10 ? "0" : "") + value }

function untilLabel(until, now) {
    if (!dndActive(false, until, now)) return ""
    const end = new Date(Number(until))
    const start = new Date(Number(now))
    const time = pad(end.getHours()) + ":" + pad(end.getMinutes())
    const sameDay = end.getFullYear() === start.getFullYear() && end.getMonth() === start.getMonth() && end.getDate() === start.getDate()
    if (sameDay) return "до " + time
    return "до " + end.getDate() + " " + MONTHS[end.getMonth()] + ", " + time
}
