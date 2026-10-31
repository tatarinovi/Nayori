.pragma library

// Прочтение на открытой вкладке «Уведомления». Время приходит в now,
// часы внутри не читаются. Записи не удаляются и не уходят в историю.
//
// inbox: { id, arrivedAt }[]. tabSince — самое раннее открытие вкладки
// на любом острове; null, если вкладка нигде не открыта.
// Идентификатор попадает в readIds, когда вкладка открыта и с момента
// max(tabSince, arrivedAt) прошло не меньше dwellMs (по умолчанию 2000).
// Закрытие вкладки (tabSince === null) ничего не помечает.
// pendingUntil — момент, когда выдержка вкладки уже сработала; до этого null.
// Новые идентификаторы ждут свои arrivedAt, а не повтор всего списка.

function dwell(input) {
    const src = input || {}
    if (src.tabSince === null || src.tabSince === undefined)
        return { readIds: [], pendingUntil: null }

    const now = Number(src.now)
    const opened = Number(src.tabSince)
    const dwell = src.dwellMs === undefined || src.dwellMs === null ? 2000 : Number(src.dwellMs)
    const inbox = Array.isArray(src.inbox) ? src.inbox : []
    const readIds = []
    const seen = Object.create(null)

    if (isFinite(now) && isFinite(opened) && isFinite(dwell)) {
        for (let i = 0; i < inbox.length; i++) {
            const item = inbox[i]
            if (!item || item.id === undefined || item.id === null) continue
            const arrived = Number(item.arrivedAt)
            if (!isFinite(arrived)) continue
            const start = opened > arrived ? opened : arrived
            if (now - start < dwell) continue
            const key = String(item.id)
            if (seen[key]) continue
            seen[key] = true
            readIds.push(item.id)
        }
    }

    const fired = isFinite(now) && isFinite(opened) && isFinite(dwell) && now - opened >= dwell
    let pendingUntil = null
    if (fired)
        pendingUntil = src.pendingUntil === null || src.pendingUntil === undefined ? now : src.pendingUntil
    return { readIds: readIds, pendingUntil: pendingUntil }
}
