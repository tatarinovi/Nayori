const fs = require('fs'), vm = require('vm'), assert = require('assert')
function moduleAt(file) { const c = {}; vm.createContext(c); vm.runInContext(fs.readFileSync(file, 'utf8'), c); return c }
const list = moduleAt('services/island/NotificationList.js'), src = moduleAt('services/island/NotificationSources.js'),
    row = moduleAt('services/island/IslandRow.js'), q = moduleAt('services/island/NotificationQueue.js')

// --- Время по-русски ---
const at = (y, mo, d, h, mi, s = 0) => new Date(y, mo - 1, d, h, mi, s).getTime()
const now = at(2026, 10, 26, 19, 5, 8)
const ago = (ms) => list.relativeTime(now, now - ms)
const MIN = 60e3, HOUR = 3600e3
assert.equal(ago(0), 'только что'); assert.equal(ago(59e3), 'только что'); assert.equal(ago(-5e3), 'только что')
assert.equal(ago(MIN), '1 мин назад'); assert.equal(ago(5 * MIN), '5 мин назад'); assert.equal(ago(59 * MIN + 59e3), '59 мин назад')
assert.equal(ago(HOUR), '1 час назад'); assert.equal(ago(2 * HOUR), '2 часа назад'); assert.equal(ago(4 * HOUR + 59 * MIN), '4 часа назад')
assert.equal(ago(5 * HOUR), '5 часов назад'); assert.equal(ago(11 * HOUR), '11 часов назад'); assert.equal(ago(12 * HOUR), '12 часов назад')
assert.equal(ago(14 * HOUR), '14 часов назад'); assert.equal(ago(21 * HOUR), '21 час назад'); assert.equal(ago(22 * HOUR), '22 часа назад')
assert.equal(list.relativeTime(now, at(2026, 10, 25, 12, 0)), 'вчера')
assert.equal(list.relativeTime(at(2026, 10, 26, 1, 0), at(2026, 10, 25, 23, 0)), '2 часа назад', 'через полночь считаются часы')
assert.equal(list.relativeTime(at(2026, 10, 26, 19, 0), at(2026, 10, 25, 18, 0)), 'вчера')
assert.equal(list.relativeTime(now, at(2026, 10, 24, 12, 0)), '2 дня назад')
assert.equal(list.relativeTime(now, at(2026, 10, 21, 12, 0)), '5 дней назад')
assert.equal(list.relativeTime(now, at(2026, 10, 12, 12, 0)), '12 окт')
assert.equal(list.relativeTime(now, 0), ''); assert.equal(list.relativeTime(now, undefined), '')
assert.equal(list.plural(1, ['а', 'б', 'в']), 'а'); assert.equal(list.plural(21, ['а', 'б', 'в']), 'а')
assert.equal(list.plural(11, ['а', 'б', 'в']), 'в'); assert.equal(list.plural(12, ['а', 'б', 'в']), 'в'); assert.equal(list.plural(3, ['а', 'б', 'в']), 'б')
assert.equal(list.plural(100, ['а', 'б', 'в']), 'в'); assert.equal(list.plural(101, ['а', 'б', 'в']), 'а')

// --- Группы и фильтры ---
const R = (id, appName, time, extra) => Object.assign({ id, appName, summary: 's' + id, body: 'b' + id, time, read: false, closed: false, deleted: false, actions: [] }, extra)
const records = [
    R(1, 'Telegram Desktop', now - 5 * MIN, { desktopEntry: 'org.telegram.desktop' }),
    R(2, 'Telegram Desktop', now - 12 * MIN, { read: true }),
    R(3, 'Telegram Desktop', now - 28 * MIN, { read: true }),
    R(4, 'niri', now - HOUR, {}),
    R(5, 'niri', now - 2 * HOUR, { read: true }),
    R(6, 'Система', now - 3 * HOUR, { read: true }),
    R(7, 'Gone', now - 1000, { deleted: true })
]
const groups = list.group(list.filter(records, 'all', src.systemSources()))
assert.deepEqual(groups.map(g => g.appName), ['Telegram Desktop', 'niri', 'Система'])
assert.deepEqual(groups.map(g => g.count), [3, 2, 1]); assert.deepEqual(groups.map(g => g.unread), [1, 1, 0])
assert.equal(groups[0].latest.id, 1); assert.deepEqual(groups[0].rest.map(r => r.id), [2, 3])
assert.deepEqual(groups[1].ids, [4, 5])
assert.deepEqual(list.group(list.filter(records, 'unread', [])).map(g => [g.appName, g.count]), [['Telegram Desktop', 1], ['niri', 1]])
assert.deepEqual(list.group(list.filter(records, 'system', src.systemSources())).map(g => g.appName), ['niri', 'Система'])
assert.equal(list.groupKey({ appName: 'Telegram Desktop' }), list.groupKey({ appName: 'telegram-desktop' }))
assert.equal(list.groupKey({ appName: '', desktopEntry: 'foo' }), 'foo'); assert.equal(list.groupKey({}), 'other')
// Порядок групп: по самому свежему уведомлению, а не по порядку записей.
const shuffled = list.group([R(10, 'A', 100), R(11, 'B', 300), R(12, 'A', 200)])
assert.deepEqual(shuffled.map(g => g.appName), ['B', 'A']); assert.deepEqual(shuffled[1].items.map(r => r.id), [12, 10])
assert.deepEqual(list.group([]), [])

// Дополнительные значки не повторяют приложение в центре или друг друга.
const pinned = R(1, 'Telegram Desktop', 1)
const pending = [R(2, 'Firefox', 2), R(3, 'Telegram Desktop', 3), R(4, 'Система', 4), R(5, 'firefox', 5), R(6, 'telegram-desktop', 6)]
assert.deepEqual(list.pendingSources(pending, pinned).map(r => r.id), [4, 5])
assert.deepEqual(list.pendingSources([R(7, 'telegram-desktop', 7)], pinned), [])
assert.deepEqual(list.pendingSources(pending.concat([R(7, 'niri', 7), R(8, 'Music', 8)]), pinned).map(r => r.id), [5, 7, 8])
assert.deepEqual(list.pendingSources([], pinned), [])
assert.deepEqual(list.pendingSources(pending, pinned, 0), [])

// --- Источники как данные ---
assert(src.systemSources().includes('niri') && src.systemSources().includes('система'))
assert(list.isSystem({ appName: 'Niri' }, src.systemSources()) && list.isSystem({ appName: 'x', desktopEntry: 'upower' }, src.systemSources()))
assert(!list.isSystem({ appName: 'Telegram Desktop' }, src.systemSources()))
assert.equal(list.sourceStyle({ appName: 'Система' }, src.sourceStyles()).glyph, 'battery')
assert.equal(list.sourceStyle({ appName: 'Система' }, src.sourceStyles()).tone, 'warning')
assert.equal(list.sourceStyle({ appName: 'niri' }, src.sourceStyles()).glyph, 'terminal')
assert.equal(list.sourceStyle({ appName: 'Telegram' }, src.sourceStyles()), null)

// --- Подпись размера и окно приложения ---
assert.equal(list.imageCaption(1920, 1080), '1920 \u00d7 1080'); assert.equal(list.imageCaption(96, 96), ''); assert.equal(list.imageCaption(0, 10), '')
const windows = [{ id: 7, appId: 'foot' }, { id: 8, appId: 'org.telegram.desktop' }, { id: 9, appId: 'firefox' }]
assert.equal(list.matchWindow({ appName: 'Telegram Desktop', desktopEntry: 'org.telegram.desktop' }, windows).id, 8)
assert.equal(list.matchWindow({ appName: 'Telegram Desktop' }, windows).id, 8)
assert.equal(list.matchWindow({ appName: 'Firefox' }, windows).id, 9)
assert.equal(list.matchWindow({ appName: 'Система' }, windows), null); assert.equal(list.matchWindow({ appName: 'a' }, windows), null)
assert.equal(list.matchWindow({ appName: 'Telegram' }, []), null)
assert.equal(list.defaultAction({ actions: [{ id: 'default', text: 'Открыть' }, { id: 'reply', text: 'Ответить' }] }), 'default')
assert.equal(list.defaultAction({ actions: [] }), '')
assert.deepEqual(list.visibleActions({ actions: [{ id: 'default', text: 'Открыть' }, { id: 'reply', text: 'Ответить' }, { id: 'x', text: '' }] }).map(a => a.id), ['reply'])

// --- Очередь: просмотрено и прочитано независимы ---
{
    const s = q.create()
    for (let id = 1; id <= 5; id++) q.receive(s, { id, appName: 'A' }, id)
    assert.equal(q.pinned(s).id, 1); assert.deepEqual(q.pending(s).map(r => r.id), [3, 4, 5]); assert.equal(q.pending(s, 2).map(r => r.id).join(), '4,5')
    q.close(s, 1, false); assert.equal(q.pinned(s).id, 2, 'закрытое приложением уходит, следующее закрепляется')
    q.markRead(s, 2); assert.equal(q.pinned(s).id, 3); assert.equal(q.unreadCount(s), 4)
    q.page(s, true); assert.equal(q.pinned(s), null); assert.equal(q.unreadCount(s), 4, 'страница не делает прочитанным')
    q.receive(s, { id: 6 }, 6); assert(s.records[0].seen && !s.records[0].read)
    q.markAllRead(s, [4, 5]); assert.equal(q.unreadCount(s), 3)
    q.markAllRead(s); assert.equal(q.unreadCount(s), 0)
}

// --- Раскладка свёрнутой строки ---
const base = { yielded: false, volume: false, notification: false, lyrics: false, title: false, controls: false, pending: 0 }
const P = (o) => row.plan(Object.assign({}, base, o))
let p = P({}); assert.equal(p.main, 'rest'); assert(!p.clock && p.icons === 0 && !p.controls)
p = P({ title: true, controls: true }); assert.equal(p.main, 'music'); assert(!p.clock && p.controls, 'часы остаются слева, кнопки справа')
p = P({ lyrics: true, title: true }); assert.equal(p.main, 'lyrics'); assert(p.clock, 'текст песни показывает отдельные часы слева')
p = P({ notification: true, lyrics: true, title: true, controls: true, pending: 2 }); assert.equal(p.main, 'notification'); assert(p.clock && p.controls && p.icons === 2)
p = P({ notification: true, volume: true, pending: 1 }); assert.equal(p.main, 'volume'); assert(p.clock, 'громкость не двигает часы'); assert.equal(p.icons, 1)
p = P({ volume: true }); assert.equal(p.main, 'volume'); assert(!p.clock)
p = P({ pending: 7 }); assert.equal(p.icons, 3, 'не больше трёх значков')
p = P({ yielded: true, notification: true, controls: true, pending: 3 }); assert(p.hidden && !p.clock && !p.controls && p.icons === 0)
const M = { pad: 10, right: 14, plus: 14, icon: 18, iconGap: 4, clock: 66, controls: 88 }
const wide = row.tail(P({ notification: true, controls: true, pending: 3 }), M)
assert.deepEqual(wide.parts, ['icons'])
assert.equal(wide.x.icons + row.iconsWidth(3, M) + M.right, wide.width)
assert.equal(wide.dividers.length, 1)
assert.equal(row.tail(P({ lyrics: true, controls: true }), M).width, 0, 'часы и управление вынесены в отдельные острова')
assert.equal(row.tail(P({}), M).width, 0)
for (const combo of [{ controls: true }, { notification: true, pending: 3 }, { notification: true, pending: 3, controls: true }, { lyrics: true, controls: true }]) {
    const t = row.tail(P(combo), M)
    for (const big of [352, 400, 448]) {
        const s = row.size(big, t.width)
        assert(s.total <= row.size(448, 0).total + 192 && s.total <= 640, 'остров не шире окна: ' + JSON.stringify(s))
        assert(s.main >= 336, 'центру хватает места')
    }
}
assert.deepEqual(row.size(448, 290), { main: 350, total: 640 }); assert.deepEqual(row.size(352, 0), { main: 352, total: 352 })
assert(row.controlsVisible({ player: {} }, 20)); assert(row.controlsVisible({ player: null, held: {}, alive: true, pausedFor: 5 }, 20))
assert(!row.controlsVisible({ player: null, held: {}, alive: true, pausedFor: 21 }, 20)); assert(!row.controlsVisible({ player: null, held: {}, alive: false, pausedFor: 1 }, 20))
assert(!row.controlsVisible({ player: null, held: null, alive: false, pausedFor: 0 }, 20))
console.log('NOTIFICATIONS_LOGIC_PASS')
