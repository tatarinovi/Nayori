const fs = require('fs')
const vm = require('vm')
const assert = require('assert')

function load(file) {
    const context = {}
    vm.createContext(context)
    vm.runInContext(fs.readFileSync(file, 'utf8').replace(/^\.pragma.*$/m, ''), context)
    return context
}

const read = load('services/island/NotificationRead.js')
const source = fs.readFileSync('services/island/NotificationRead.js', 'utf8')
assert.equal(source.indexOf('Date.now'), -1, 'время только аргументом')
assert.equal(typeof read.dwell, 'function')

const dwell = 2000

// Вкладка закрыта — ничего не читать, даже если записи старые и срок уже передавали.
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }, { id: 2, arrivedAt: 0 }],
        now: 100000,
        tabSince: null,
        pendingUntil: 5000
    }),
    { readIds: [], pendingUntil: null }
)
assert.deepEqual(read.dwell({ inbox: [{ id: 1, arrivedAt: 0 }], now: 5000 }), { readIds: [], pendingUntil: null })
assert.deepEqual(read.dwell(null), { readIds: [], pendingUntil: null })

// Вкладка открыта меньше 2 с: старые записи ждут открытия, а не своего arrivedAt.
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }, { id: 2, arrivedAt: 100 }],
        now: 1999,
        tabSince: 0,
        pendingUntil: null,
        dwellMs: dwell
    }),
    { readIds: [], pendingUntil: null }
)

// Ровно 2 с после открытия: то, что уже лежало, прочитано.
// Пришедшее на 100 мс позже ждёт свои 2 с и в этот залп не входит.
const opened = read.dwell({
    inbox: [{ id: 7, arrivedAt: 0 }, { id: 8, arrivedAt: 100 }, { id: 9, arrivedAt: 0 }],
    now: 2000,
    tabSince: 0,
    pendingUntil: null
})
assert.deepEqual(opened, { readIds: [7, 9], pendingUntil: 2000 })
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 8, arrivedAt: 100 }],
        now: 2100,
        tabSince: 0,
        pendingUntil: opened.pendingUntil
    }),
    { readIds: [8], pendingUntil: 2000 }
)

// Повторный вызов сохраняет pendingUntil и не требует ждать его как следующий срок.
const again = read.dwell({
    inbox: [{ id: 7, arrivedAt: 0 }, { id: 8, arrivedAt: 100 }],
    now: 2500,
    tabSince: 0,
    pendingUntil: opened.pendingUntil
})
assert.deepEqual(again, { readIds: [7, 8], pendingUntil: 2000 })

// Новая запись после срабатывания ждёт 2 с со своего arrivedAt, а не с открытия вкладки.
const fresh = read.dwell({
    inbox: [{ id: 7, arrivedAt: 0 }, { id: 11, arrivedAt: 2000 }],
    now: 3999,
    tabSince: 0,
    pendingUntil: 2000
})
assert.deepEqual(fresh.readIds, [7])
assert.equal(fresh.pendingUntil, 2000)
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 7, arrivedAt: 0 }, { id: 11, arrivedAt: 2000 }],
        now: 4000,
        tabSince: 0,
        pendingUntil: 2000
    }),
    { readIds: [7, 11], pendingUntil: 2000 }
)

// Пришла, пока вкладка уже открыта, и к моменту «вкладка открыта 2 с» ещё не вылежала свои 2 с.
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }, { id: 2, arrivedAt: 1000 }],
        now: 2000,
        tabSince: 0,
        pendingUntil: null
    }),
    { readIds: [1], pendingUntil: 2000 }
)
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 2, arrivedAt: 1000 }],
        now: 3000,
        tabSince: 0,
        pendingUntil: 2000
    }),
    { readIds: [2], pendingUntil: 2000 }
)

// Уход со вкладки отменяет выдержку этого вызова.
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }, { id: 2, arrivedAt: 1000 }],
        now: 5000,
        tabSince: null,
        pendingUntil: 2000
    }),
    { readIds: [], pendingUntil: null }
)

// После нового открытия срок считается заново: старый pendingUntil не читает список сразу.
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }],
        now: 6000,
        tabSince: 5500,
        pendingUntil: 2000
    }),
    { readIds: [], pendingUntil: null }
)
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 1, arrivedAt: 0 }, { id: 3, arrivedAt: 5600 }],
        now: 7500,
        tabSince: 5500,
        pendingUntil: null
    }),
    { readIds: [1], pendingUntil: 7500 }
)
assert.deepEqual(
    read.dwell({
        inbox: [{ id: 3, arrivedAt: 5600 }],
        now: 7600,
        tabSince: 5500,
        pendingUntil: 7500
    }),
    { readIds: [3], pendingUntil: 7500 }
)

// Пустой список: вкладка уже выдержана, читать нечего, pendingUntil ставится.
assert.deepEqual(
    read.dwell({ inbox: [], now: 2000, tabSince: 0, pendingUntil: null }),
    { readIds: [], pendingUntil: 2000 }
)

// Свой срок, без дублей, без мутации входа. Нечисловой arrivedAt пропускается.
const inbox = [{ id: 'a', arrivedAt: 0 }, { id: 'a', arrivedAt: 0 }, { id: 'b', arrivedAt: 0 }, null, { id: 'c' }]
const inboxCopy = JSON.stringify(inbox)
assert.deepEqual(
    read.dwell({ inbox: inbox, now: 500, tabSince: 0, pendingUntil: null, dwellMs: 500 }),
    { readIds: ['a', 'b'], pendingUntil: 500 }
)
assert.equal(JSON.stringify(inbox), inboxCopy)
assert.equal(inbox[0].read, undefined)

// Один остров из нескольких: вызывающий передаёт самый ранний tabSince, не null.
assert.deepEqual(
    read.dwell({ inbox: [{ id: 1, arrivedAt: 10 }], now: 80, tabSince: 40, dwellMs: 40 }).readIds,
    [1]
)

console.log('NOTIFICATION_READ_PASS')
