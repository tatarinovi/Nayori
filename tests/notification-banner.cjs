const fs = require('fs')
const vm = require('vm')
const assert = require('assert')

function load(file) {
    const context = {}
    vm.createContext(context)
    vm.runInContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma.*$/m, ''), context)
    return context
}

const banner = load('services/island/NotificationBanner.js')
const policy = load('services/island/NotificationPolicy.js')
const source = fs.readFileSync('services/island/NotificationBanner.js', 'utf8')
assert.equal(source.indexOf('Date.now'), -1, 'время только аргументом')
assert.equal(typeof banner.select, 'function')

function item(id, time, eligible) { return { id: id, time: time, eligible: eligible } }

// Пусто и неподходящие не становятся текущими.
assert.deepEqual(banner.select({ items: [], now: 1000, shown: null }), { currentId: null, until: null })
assert.deepEqual(banner.select({ items: null, now: 1000, shown: null }), { currentId: null, until: null })
assert.deepEqual(banner.select(null), { currentId: null, until: null })
assert.deepEqual(
    banner.select({ items: [item(1, 100, false), item(2, 500, false)], now: 1000, shown: null }),
    { currentId: null, until: null }
)

// Самое новое подходящее. При равном времени побеждает больший id.
assert.deepEqual(
    banner.select({
        items: [item(1, 100, true), item(3, 150, true), item(2, 200, true), item(9, 200, false)],
        now: 1000,
        shown: null
    }),
    { currentId: 2, until: 31000 }
)
assert.deepEqual(
    banner.select({
        items: [item(1, 200, true), item(5, 200, true), item(3, 200, true)],
        now: 0,
        shown: null
    }),
    { currentId: 5, until: 30000 }
)

// Показ не ставит прочтение и не меняет вход.
const held = [item(4, 10, true)]
const heldShown = null
const heldCopy = JSON.stringify(held)
const first = banner.select({ items: held, now: 50, shown: heldShown })
assert.deepEqual(first, { currentId: 4, until: 30050 })
assert.equal(JSON.stringify(held), heldCopy)
assert.equal(held[0].read, undefined)

// Таймер не сбрасывается, пока это всё ещё самое новое и срок не вышел.
assert.deepEqual(
    banner.select({ items: [item(4, 10, true), item(1, 5, true)], now: 1000, shown: { id: 4, until: 30050 } }),
    { currentId: 4, until: 30050 }
)

// until <= now: ушло с острова, в списке остаётся, таймер того же показа не начинается заново.
assert.deepEqual(
    banner.select({ items: [item(4, 10, true), item(1, 5, true)], now: 30050, shown: { id: 4, until: 30050 } }),
    { currentId: null, until: 30050 }
)
assert.deepEqual(
    banner.select({ items: [item(4, 10, true)], now: 40000, shown: { id: 4, until: 30050 } }),
    { currentId: null, until: 30050 }
)

// Более новое заменяет баннер и заново включает 30 с, в том числе после срока предыдущего.
assert.deepEqual(
    banner.select({
        items: [item(4, 10, true), item(8, 20, true)],
        now: 2000,
        shown: { id: 4, until: 30050 }
    }),
    { currentId: 8, until: 32000 }
)
assert.deepEqual(
    banner.select({
        items: [item(4, 10, true), item(8, 20, true)],
        now: 40000,
        shown: { id: 4, until: 30050 }
    }),
    { currentId: 8, until: 70000 }
)

// Более новое, но неподходящее, текущее не вытесняет. Более старое после срока не занимает центр.
assert.deepEqual(
    banner.select({
        items: [item(4, 10, true), item(8, 99, false)],
        now: 2000,
        shown: { id: 4, until: 30050 }
    }),
    { currentId: 4, until: 30050 }
)
assert.deepEqual(
    banner.select({
        items: [item(4, 20, true), item(1, 10, true)],
        now: 9000,
        shown: { id: 4, until: 5000 }
    }),
    { currentId: null, until: 5000 }
)

// Равный time: больший id считается новее и перезапускает срок.
assert.deepEqual(
    banner.select({
        items: [item(4, 20, true), item(7, 20, true)],
        now: 100,
        shown: { id: 4, until: 5000 },
        dwellMs: 1000
    }),
    { currentId: 7, until: 1100 }
)

// Текущее пропало из items — баннер сбрасывается, даже если старше осталось подходящее.
assert.deepEqual(
    banner.select({
        items: [item(1, 10, true)],
        now: 2000,
        shown: { id: 4, until: 9000 }
    }),
    { currentId: null, until: null }
)

// Неподходящее не остаётся текущим. Срок сессии сохраняется: если снова подойдёт до until, показ продолжится.
assert.deepEqual(
    banner.select({
        items: [item(4, 10, false), item(1, 5, true)],
        now: 2000,
        shown: { id: 4, until: 9000 }
    }),
    { currentId: null, until: 9000 }
)
assert.deepEqual(
    banner.select({
        items: [item(4, 10, true), item(1, 5, true)],
        now: 2000,
        shown: { id: 4, until: 9000 }
    }),
    { currentId: 4, until: 9000 }
)

// Свой срок вместо 30 с.
assert.equal(banner.select({ items: [item(1, 1, true)], now: 10, shown: null, dwellMs: 2500 }).until, 2510)

// Вызывающий ставит eligible через NotificationPolicy, без второй копии правил.
function callerEligible(record, settings) {
    const decision = policy.admit({
        enabled: settings.enabled,
        dnd: false,
        sources: settings.sources,
        record: record
    })
    return !record.deleted && !record.closed && !record.quiet && record.live !== false
        && record.loadedFromDisk !== true && !decision.drop && decision.mode === 'normal'
}
const settings = { enabled: true, sources: [] }
const quiet = { id: 1, time: 10, appName: 'Почта', quiet: true, closed: false, deleted: false }
const live = { id: 2, time: 20, appName: 'Почта', quiet: false, closed: false, deleted: false }
assert.equal(callerEligible(quiet, settings), false)
assert.equal(callerEligible(live, settings), true)
assert.equal(callerEligible(live, { enabled: true, dnd: true, sources: [] }), true, 'уже принятое не гаснет от текущего режима')
const noted = policy.noteSource([], { appName: 'Telegram', desktopEntry: 'org.telegram.desktop' })
settings.sources = policy.setMode(noted.list, 'entry:org.telegram.desktop', 'expanded').list
const telegram = { id: 3, time: 30, appName: 'Telegram', desktopEntry: 'org.telegram.desktop', quiet: false, closed: false, deleted: false }
assert.equal(callerEligible(telegram, settings), false)
settings.sources = policy.setMode(settings.sources, 'entry:org.telegram.desktop', 'off').list
assert.equal(callerEligible(telegram, settings), false)
settings.sources = policy.setMode(settings.sources, 'entry:org.telegram.desktop', 'normal').list
assert.equal(callerEligible(telegram, settings), true)
assert.equal(callerEligible(telegram, { enabled: false, sources: settings.sources }), false)
assert.equal(callerEligible(Object.assign({}, telegram, { closed: true }), settings), false)
assert.equal(callerEligible(Object.assign({}, telegram, { live: false, loadedFromDisk: true }), settings), false, 'запись с диска не всплывает')
const rows = [quiet, live, telegram].map(record => ({ id: record.id, time: record.time, eligible: callerEligible(record, settings) }))
assert.deepEqual(banner.select({ items: rows, now: 100, shown: null }), { currentId: 3, until: 30100 })

console.log('NOTIFICATION_BANNER_PASS')
