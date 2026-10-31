.pragma library

// Свёрнутый остров: какое уведомление стоит в центре и до какого момента.
// Время приходит в now, часы внутри не читаются. Прочтение эта функция не меняет.
//
// items: { id, time, eligible }[]. eligible уже вычислен вызывающим:
// «Не беспокоить», отключённый источник и «только развёрнутый» сюда не проходят.
// shown: { id, until } или null — прошлый выбор.
// Возвращает { currentId, until }. Пока until > now, currentId на острове.
// until <= now снимает его с острова, но не из списка: currentId становится null.

function select(input) {
    const src = input || {}
    const items = Array.isArray(src.items) ? src.items : []
    const now = Number(src.now)
    const dwell = src.dwellMs === undefined || src.dwellMs === null ? 30000 : Number(src.dwellMs)
    const shown = src.shown && typeof src.shown === "object" && !Array.isArray(src.shown)
        && src.shown.id !== undefined && src.shown.id !== null ? src.shown : null

    function rankTime(value) {
        const n = Number(value)
        return isFinite(n) ? n : -Infinity
    }
    function newer(a, b) {
        const ta = rankTime(a && a.time)
        const tb = rankTime(b && b.time)
        if (ta !== tb) return ta > tb
        const ia = Number(a && a.id)
        const ib = Number(b && b.id)
        if (isFinite(ia) && isFinite(ib)) return ia > ib
        return String(a && a.id) > String(b && b.id)
    }
    function findId(id) {
        for (let i = 0; i < items.length; i++)
            if (items[i] && items[i].id === id) return items[i]
        return null
    }

    let newest = null
    for (let i = 0; i < items.length; i++) {
        const item = items[i]
        if (!item || item.eligible !== true) continue
        if (!newest || newer(item, newest)) newest = item
    }

    if (!shown) {
        if (!newest || !isFinite(now)) return { currentId: null, until: null }
        return { currentId: newest.id, until: now + dwell }
    }

    const current = findId(shown.id)
    if (!current) return { currentId: null, until: null }

    if (newest && newest.id !== shown.id && newer(newest, current)) {
        if (!isFinite(now)) return { currentId: null, until: null }
        return { currentId: newest.id, until: now + dwell }
    }

    const until = Number(shown.until)
    if (current.eligible !== true || !isFinite(until) || until <= now)
        return { currentId: null, until: isFinite(until) ? until : null }
    return { currentId: shown.id, until: until }
}
