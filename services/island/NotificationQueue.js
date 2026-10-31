// Чистая логика журнала уведомлений. Без QML и таймеров: время приходит аргументом.
//
// У записи независимые признаки:
//   seen    — показана ли она в свёрнутом острове; страница «Уведомления» считает такие записи просмотренными;
//   read    — прочитана ли она в списке (раскрыта, нажата или удалена); от этого зависят точка и фильтр;
//   quiet   — поступила в режиме «Не беспокоить»; в свёрнутый остров не возвращается;
//   compact — можно ли показывать её в свёрнутом острове при текущем режиме источника;
//   closed  — приложение само её закрыло, deleted — удалил пользователь.
//
// Свёрнутый остров не использует таймер: самое раннее непросмотренное уведомление
// закреплено в центре (pinned), остальные непросмотренные показываются значками справа.
const MAX_ICONS = 3

function create() { return { records: [], pageOpen: false } }

function find(s, id) { return s.records.find(function(r) { return r.id === id }) }

function receive(s, data, now, options) {
    const opts = options || {}
    let r = find(s, data.id)
    if (r && r.deleted) return
    if (r) {
        // Обновление приложением: служебные признаки и время поступления остаются.
        // quiet липкий: уведомление из режима «Не беспокоить» не становится видимым в свёрнутом острове.
        const quiet = !!r.quiet || !!opts.quiet
        const compact = quiet ? false : opts.compact !== false
        const keep = { read: r.read, seen: r.seen, closed: r.closed, deleted: r.deleted, time: r.time, quiet: quiet, compact: compact }
        Object.assign(r, data, keep)
        // Закрытое приложением уведомление, пришедшее снова, снова открыто.
        r.closed = false
        r.quiet = quiet
        r.compact = compact
        return
    }
    const time = typeof now === 'number' ? now : (typeof data.time === 'number' ? data.time : 0)
    const quiet = !!opts.quiet
    r = Object.assign({}, data, {
        time: time, read: false, seen: s.pageOpen, closed: false, deleted: false,
        quiet: quiet, compact: !quiet && opts.compact !== false
    })
    s.records.unshift(r)
}

function live(r) { return !r.deleted && !r.closed }
function showsCollapsed(r) { return live(r) && !r.seen && !r.quiet && r.compact !== false }
function unseen(s) { return s.records.filter(showsCollapsed) }

// Самое раннее из непросмотренных: оно остаётся в центре, пока страницу не откроют.
function pinned(s) {
    const list = unseen(s)
    return list.length ? list[list.length - 1] : null
}

// Остальные непросмотренные: не больше max самых свежих, слева направо от старого к новому.
function pending(s, max) {
    const limit = max === undefined ? MAX_ICONS : max
    const list = unseen(s)
    list.pop()
    return list.slice(0, Math.max(0, limit)).reverse()
}

// Сколько непросмотренных ждёт, кроме закреплённого (в значках показаны только последние).
function pendingTotal(s) { return Math.max(0, unseen(s).length - 1) }

function markSeen(s) { s.records.forEach(function(r) { if (!r.deleted) r.seen = true }) }
function page(s, open) { s.pageOpen = open; if (open) markSeen(s) }

function markRead(s, id) {
    const r = find(s, id)
    if (r && !r.deleted) { r.read = true; r.seen = true }
}
function markAllRead(s, ids) {
    s.records.forEach(function(r) {
        if (!r.deleted && (!ids || ids.indexOf(r.id) >= 0)) { r.read = true; r.seen = true }
    })
}
function close(s, id, deleted) {
    const r = find(s, id)
    if (!r) return
    if (deleted) r.deleted = true
    else r.closed = true
}
function unreadCount(s) { return s.records.filter(function(r) { return !r.deleted && !r.read }).length }
