// Чистая логика страницы «Уведомления»: время по-русски, группы, фильтры, подбор окна.
// Без QML: проверяется в Node (tests/notifications.cjs).

const MONTHS = ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"]

// plural(5, ["час", "часа", "часов"]) → "часов"
function plural(n, forms) {
    const a = Math.abs(Math.trunc(Number(n) || 0)), b = a % 100, c = a % 10
    if (b >= 11 && b <= 14) return forms[2]
    if (c === 1) return forms[0]
    if (c >= 2 && c <= 4) return forms[1]
    return forms[2]
}

function startOfDay(ms) { const d = new Date(ms); return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime() }

// Время поступления по-русски: «только что», «5 мин назад», «1 час назад»,
// «2 часа назад», «вчера», «3 дня назад», дальше — дата «12 окт».
function relativeTime(now, then) {
    now = Number(now); then = Number(then)
    if (!isFinite(now) || !isFinite(then) || then <= 0) return ""
    const seconds = Math.max(0, (now - then) / 1000)
    if (seconds < 60) return "только что"
    const minutes = Math.floor(seconds / 60)
    if (minutes < 60) return minutes + " мин назад"
    const hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + " " + plural(hours, ["час", "часа", "часов"]) + " назад"
    const days = Math.round((startOfDay(now) - startOfDay(then)) / 86400000)
    if (days <= 1) return "вчера"
    if (days < 7) return days + " " + plural(days, ["день", "дня", "дней"]) + " назад"
    const d = new Date(then)
    return d.getDate() + " " + MONTHS[d.getMonth()]
}

function normalize(text) { return String(text === undefined || text === null ? "" : text).toLowerCase().replace(/[^a-z0-9а-яё]/g, "") }

// Ключ группы — приложение. Один ключ для «Telegram Desktop» и «telegram-desktop».
function groupKey(record) { return normalize(record.appName) || normalize(record.desktopEntry) || "other" }

// Дополнительные значки: по одному на приложение, кроме уже закреплённого.
// Вход — уведомления от старых к новым; оставляем самые свежие источники.
function pendingSources(records, pinned, max) {
    const limit = max === undefined ? 3 : Math.max(0, max)
    const used = Object.create(null)
    if (pinned) used[groupKey(pinned)] = true
    const result = []
    for (let i = records.length - 1; i >= 0 && result.length < limit; i--) {
        const key = groupKey(records[i])
        if (used[key]) continue
        used[key] = true
        result.push(records[i])
    }
    return result.reverse()
}

function isSystem(record, sources) {
    const names = (sources || []).map(normalize)
    return names.indexOf(normalize(record.appName)) >= 0 || (!!record.desktopEntry && names.indexOf(normalize(record.desktopEntry)) >= 0)
}

// Оформление источника без иконки в теме: { glyph, tone } или null.
function sourceStyle(record, styles) {
    const keys = [normalize(record.appName), normalize(record.desktopEntry)]
    for (let i = 0; i < (styles || []).length; i++) {
        const names = styles[i].match.map(normalize)
        if (keys.some(function(k) { return k && names.indexOf(k) >= 0 })) return { glyph: styles[i].glyph, tone: styles[i].tone || "accent" }
    }
    return null
}

// mode: "all" | "unread" | "system"
function filter(records, mode, sources) {
    return records.filter(function(r) {
        if (r.deleted) return false
        if (mode === "unread") return !r.read
        if (mode === "system") return isSystem(r, sources)
        return true
    })
}

function newer(a, b) { return (b.time - a.time) || (b.id - a.id) }

// Группы по приложениям. Внутри — от нового к старому, сами группы — по самому свежему.
function group(records) {
    const map = {}, order = []
    records.slice().sort(newer).forEach(function(r) {
        const key = groupKey(r)
        if (!map[key]) { map[key] = { key: key, appName: r.appName || "Приложение", appIcon: r.appIcon || "", desktopEntry: r.desktopEntry || "", items: [] }; order.push(key) }
        map[key].items.push(r)
    })
    return order.map(function(key) {
        const g = map[key]
        g.count = g.items.length
        g.unread = g.items.filter(function(r) { return !r.read }).length
        g.time = g.items[0].time
        g.latest = g.items[0]
        g.rest = g.items.slice(1)
        g.ids = g.items.map(function(r) { return r.id })
        return g
    })
}

// «1920 × 1080» для широких картинок (скриншоты); квадратные аватары без подписи.
function imageCaption(width, height) {
    const w = Math.round(Number(width) || 0), h = Math.round(Number(height) || 0)
    if (w <= 0 || h <= 0) return ""
    const ratio = w / h
    if (ratio > 0.9 && ratio < 1.1) return ""
    return w + " \u00d7 " + h
}

// Окно приложения, которое показывает уведомление: по desktop-entry или имени приложения.
// windows — список niri { id, appId }. Возвращает окно или null.
function matchWindow(record, windows) {
    const keys = [normalize(record.desktopEntry), normalize(record.appName)].filter(function(k) { return k.length >= 3 })
    if (!keys.length) return null
    const list = windows || []
    // Сначала точное совпадение, потом вхождение (org.telegram.desktop ↔ Telegram Desktop).
    for (let i = 0; i < list.length; i++) {
        const id = normalize(list[i].appId)
        if (id && keys.indexOf(id) >= 0) return list[i]
    }
    for (let i = 0; i < list.length; i++) {
        const id = normalize(list[i].appId)
        if (id.length >= 4 && keys.some(function(k) { return k.indexOf(id) >= 0 || id.indexOf(k) >= 0 })) return list[i]
    }
    return null
}

function defaultAction(record) {
    const a = (record.actions || []).find(function(a) { return a.id === "default" })
    return a ? a.id : ""
}

// Кнопки действий: «default» — это клик по самой карточке, отдельной кнопки у него нет.
function visibleActions(record) {
    return (record.actions || []).filter(function(a) { return a.id !== "default" && a.text })
}
