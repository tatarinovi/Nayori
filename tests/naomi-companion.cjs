// Логика Naomi без QML: жест поглаживания и правила реплик.
const fs = require('fs'), vm = require('vm'), assert = require('assert')
function moduleAt(file) { const c = {}; vm.createContext(c); vm.runInContext(fs.readFileSync(file, 'utf8'), c); return c }
const pet = moduleAt('services/companion/NaomiBehavior.js')
const talk = moduleAt('services/companion/NaomiDialogue.js')
const data = moduleAt('services/companion/NaomiLines.js')
const lines = data.lines
const seeded = seed => () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646 }
const ENABLED = { enabled: true, reduced: false }

// --- зона головы ---
assert(pet.inHead(437, 190), 'центр головы внутри')
assert(!pet.inHead(100, 190) && !pet.inHead(437, 600), 'вне головы — снаружи')
assert(!pet.inHead(335, 80), 'угол ограничивающего прямоугольника вне эллипса')

// Прогон: курсор водит по голове с заданной скоростью (пикселей сцены в секунду).
function stroke(s, seconds, speed, opts = {}) {
    const events = { started: 0, ended: 0, long: 0 }, fps = 60
    let t = 0, x = 437 - 70, dir = 1, last = null
    const dt = 1 / fps
    while (t < seconds) {
        x += dir * speed * dt
        if (x > 437 + 70) { x = 437 + 70; dir = -1 }
        if (x < 437 - 70) { x = 437 - 70; dir = 1 }
        pet.move(s, x, opts.y === undefined ? 190 : opts.y)
        last = pet.step(s, opts.input || ENABLED, dt)
        for (const k of Object.keys(events)) if (last[k]) events[k]++
        t += dt
    }
    return { events, last }
}
function idle(s, seconds, input) {
    const events = { started: 0, ended: 0, long: 0 }
    let last = null
    for (let t = 0; t < seconds; t += 1 / 60) {
        last = pet.step(s, input || ENABLED, 1 / 60)
        for (const k of Object.keys(events)) if (last[k]) events[k]++
    }
    return { events, last }
}

// Спокойное поглаживание включает позу один раз и держит её.
let s = pet.create()
let r = stroke(s, 3, 400)
assert.equal(r.events.started, 1, 'поглаживание началось')
assert(r.last.petting && r.last.pet > 0.6, 'поза включена: ' + r.last.pet)
r = stroke(s, 3, 400)
assert.equal(r.events.started, 0, 'второй раз не стартует: событие одно на жест')
assert(r.last.petting)

// Гистерезис: короткая пауза не обрывает позу, долгая — обрывает; возврат плавный.
r = idle(s, 0.4)
assert(r.last.petting, 'пауза 0,4 с не обрывает')
r = idle(s, 6)
assert.equal(r.events.ended, 1, 'конец жеста один')
assert(!r.last.petting)
assert(r.last.pet < 0.05, 'после конца поза почти погасла: ' + r.last.pet)
s = pet.create(); stroke(s, 3, 400)
let prev = 1, monotone = true, steps = 0
for (let t = 0; t < 4; t += 1 / 60) {
    const o = pet.step(s, ENABLED, 1 / 60)
    if (o.pet > prev + 1e-9) monotone = false
    prev = o.pet; steps++
}
assert(monotone && prev < 0.05, 'возврат монотонный и плавный')

// Быстрый пролёт через голову и медленное ведение не включают жест.
s = pet.create()
for (let x = 300; x < 600; x += 40) { pet.move(s, x, 190); pet.step(s, ENABLED, 0.01) }
assert(!s.petting && s.energy < 300, 'пролёт курсора не поглаживание')
s = pet.create()
r = stroke(s, 8, 90)
assert.equal(r.events.started, 0, 'медленное ведение не поглаживание: ' + s.energy)
// Дрожь на месте — тоже нет.
s = pet.create()
for (let i = 0; i < 600; i++) { pet.move(s, 437 + (i % 2) * 0.8, 190); pet.step(s, ENABLED, 1 / 60) }
assert(!s.petting, 'дрожь на месте не поглаживание')
// Движение вне головы не копит энергию.
s = pet.create()
r = stroke(s, 4, 500, { y: 600 })
assert.equal(r.events.started, 0, 'движение по телу — не по голове')
// Скачок (вход в окно) не считается путём.
s = pet.create(); pet.move(s, 0, 0); pet.move(s, 437, 190)
assert.equal(s.energy, 0, 'скачок не копит энергию')
// Один редкий отсчёт даёт не больше STEP_CAP.
s = pet.create(); pet.move(s, 400, 190); pet.move(s, 400 + 200, 190)
assert(s.energy === 0, 'слишком большой скачок отброшен'); pet.move(s, 400 + 250, 190)
assert(s.energy <= 90 + 1e-9, 'шаг ограничен')

// Выход курсора гасит энергию быстрее и обрывает жест.
s = pet.create(); stroke(s, 3, 400); assert(s.petting)
pet.leave(s)
r = idle(s, 2)
assert(!r.last.petting && r.events.ended === 1, 'уход курсора заканчивает жест')

// «Долго гладят» срабатывает один раз за жест.
s = pet.create()
r = stroke(s, 10, 400)
assert.equal(r.events.long, 1, 'долгое поглаживание — одно событие')
assert.equal(r.events.started, 1)

// Независимость от частоты кадров: тот же жест при 30 и 120 кадрах.
function run(fps) {
    const st = pet.create(); let x = 437 - 70, dir = 1, started = 0
    for (let t = 0; t < 3; t += 1 / fps) {
        x += dir * 400 / fps
        if (x > 507) { x = 507; dir = -1 } if (x < 367) { x = 367; dir = 1 }
        pet.move(st, x, 190)
        if (pet.step(st, ENABLED, 1 / fps).started) started++
    }
    return { started, energy: st.energy }
}
const a = run(30), b = run(120)
assert(a.started === 1 && b.started === 1, 'жест распознан при любом fps')
assert(Math.abs(a.energy - b.energy) / b.energy < 0.2, `энергия не зависит от fps: ${a.energy} ${b.energy}`)

// Наклон следует за рукой и гаснет с позой.
s = pet.create()
for (let i = 0; i < 180; i++) { pet.move(s, 437 + 90 - (i % 2) * 8, 190); pet.step(s, ENABLED, 1 / 60) }
let o = pet.step(s, ENABLED, 1 / 60)
assert(o.lean > 0.2, 'рука справа — наклон вправо: ' + o.lean)
assert(o.lean <= 1)
s = pet.create()
for (let i = 0; i < 180; i++) { pet.move(s, 437 - 90 + (i % 2) * 8, 190); pet.step(s, ENABLED, 1 / 60) }
o = pet.step(s, ENABLED, 1 / 60)
assert(o.petting && o.lean < -0.2, 'рука слева — наклон влево: ' + o.lean)

// Выключенная реакция гасит всё сразу и отдаёт конец жеста.
s = pet.create(); stroke(s, 3, 400)
o = pet.step(s, { enabled: false, reduced: false }, 0.016)
assert(o.ended && !o.petting && o.pet === 0 && o.lean === 0, 'выключение гасит позу')
pet.move(s, 400, 190); o = pet.step(s, { enabled: false }, 0.016)
assert(!o.petting && o.pet === 0)

// Без анимаций поза включается мгновенно.
s = pet.create()
r = stroke(s, 3, 400, { input: { enabled: true, reduced: true } })
assert(r.last.petting && Math.abs(r.last.pet - r.last.intensity) < 1e-9, 'reduced: без плавности')
r = idle(s, 6, { enabled: true, reduced: true })
assert(r.last.pet === 0, 'reduced: сразу в обычную позу')

// Невалидные значения не ломают состояние.
s = pet.create()
pet.move(s, NaN, undefined); o = pet.step(s, ENABLED, NaN)
assert(Number.isFinite(o.pet) && Number.isFinite(o.lean) && Number.isFinite(o.energy))
o = pet.step(s, ENABLED, -5); assert(Number.isFinite(o.pet))
console.log('NAOMI_PET_PASS')

// --- реплики ---
// Данные: все виды заполнены, тексты короткие, на русском, без hex и лишних пробелов.
const flat = []
for (const kind of ['greeting', 'idle', 'petStart', 'petAgain', 'petLong', 'petEnd']) {
    const set = lines[kind]; assert(set, 'нет набора ' + kind)
    const groups = Array.isArray(set) ? [set] : Object.values(set)
    for (const g of groups) { assert(g.length >= 1, kind + ': пустая группа'); flat.push(...g.map(t => [kind, t])) }
}
for (const part of ['morning', 'day', 'evening', 'night', 'any']) assert(lines.greeting[part].length >= 1, 'приветствие ' + part)
for (const [kind, text] of flat) {
    assert(typeof text === 'string' && text === text.trim() && text.length >= 6 && text.length <= 52, `${kind}: длина «${text}»`)
    assert(/[А-Яа-яЁё]/.test(text), `${kind}: русский текст «${text}»`)
    assert(!/[!]{2,}|\s{2,}|#[0-9a-f]{3,}/i.test(text), `${kind}: чистый текст «${text}»`)
}
assert.equal(new Set(flat.map(f => f[1])).size, flat.length, 'реплики не дублируются')
assert(lines.petStart.length >= 3 && lines.idle.length >= 5)

assert.equal(talk.daypart(7), 'morning'); assert.equal(talk.daypart(12), 'day')
assert.equal(talk.daypart(20), 'evening'); assert.equal(talk.daypart(2), 'night')
assert.equal(talk.daypart(undefined), 'any')
assert(talk.holdFor('а') === 4 && talk.holdFor('а'.repeat(500)) === 9, 'время показа ограничено 4…9 с')
assert(talk.holdFor('Ой… приятно.') >= 4)

function make(seed = 7) { const rnd = seeded(seed); return { s: talk.create(lines, rnd), rnd } }
function advance(d, secs, ctx) { let spoke = []; for (let t = 0; t < secs; t += 0.1) { const x = talk.tick(d.s, 0.1, d.rnd, ctx || { active: true, hour: 14 }); if (x) spoke.push(x) } return spoke }

// Приветствие: показывается, по времени суток, и не чаще раза в 10 минут.
let d = make()
let greet = talk.react(d.s, 'greeting', d.rnd, { hour: 8 })
assert(lines.greeting.morning.includes(greet), 'утреннее приветствие: ' + greet)
assert(talk.visible(d.s) && d.s.text === greet)
advance(d, 9.5); assert(talk.visible(d.s) === false, 'облако гаснет само')
assert.equal(talk.react(d.s, 'greeting', d.rnd, { hour: 8 }), null, 'приветствие не чаще раза в 10 минут')
d = make(); assert(lines.greeting.night.includes(talk.react(d.s, 'greeting', d.rnd, { hour: 3 })))
d = make(); assert(lines.greeting.any.includes(talk.react(d.s, 'greeting', d.rnd, {})), 'без часа — общее приветствие')

// Поглаживание перебивает приветствие, но не другую показанную реплику.
d = make(); talk.react(d.s, 'greeting', d.rnd, { hour: 12 })
let p1 = talk.react(d.s, 'petStart', d.rnd, { hour: 12 })
assert(lines.petStart.includes(p1), 'реплика поглаживания заменила приветствие')
assert.equal(talk.react(d.s, 'idle', d.rnd, {}), null, 'idle не перебивает показанную')
assert.equal(talk.react(d.s, 'petLong', d.rnd, {}), null, 'петля поглаживания не перебивает petStart: ' + d.s.kind)
advance(d, 5)
// Кулдауны: следующее поглаживание сразу после — «снова», но не раньше 8 с.
assert.equal(talk.react(d.s, 'petStart', d.rnd, {}), null, 'кулдаун реплик поглаживания 8 с')
advance(d, 4)
let p2 = talk.react(d.s, 'petStart', d.rnd, {})
assert(lines.petAgain.includes(p2), '«снова» вскоре после первого: ' + p2)
advance(d, 200)
let p3 = talk.react(d.s, 'petStart', d.rnd, {})
assert(lines.petStart.includes(p3), 'через 90 с снова «первое»')

// Конец поглаживания: коротко — молчим, долго — прощаемся.
d = make()
assert.equal(talk.react(d.s, 'petEnd', d.rnd, { duration: 1 }), null, 'короткое поглаживание без реплики')
assert(lines.petEnd.includes(talk.react(d.s, 'petEnd', d.rnd, { duration: 5 })))
// Нет повтора двух последних реплик.
d = make(3); const seen = []
for (let i = 0; i < 12; i++) { const t = talk.react(d.s, 'petLong', d.rnd, {}); if (t) seen.push(t); advance(d, 40) }
assert(seen.length >= 10)
for (let i = 1; i < seen.length; i++) assert.notEqual(seen[i], seen[i - 1], 'нет повтора подряд')

// Покойные реплики: редки, не в первые 5 минут, не при поглаживании, не при неактивном окне.
d = make(11)
assert.equal(advance(d, 290).length, 0, 'за 290 с покоя — ни слова')
let idleSpoke = advance(d, 330)
assert.equal(idleSpoke.length, 1, 'одна покойная реплика в пределах 10 минут')
assert(lines.idle.includes(idleSpoke[0]))
const hour = advance(make(5), 3600)
assert(hour.length >= 3 && hour.length <= 12, 'реплик за час: ' + hour.length)
d = make(11); assert.equal(advance(d, 1800, { active: true, quiet: true }).length, 0, 'при поглаживании молчит')
let afterQuiet = advance(d, 25, { active: true })
assert.equal(afterQuiet.length, 0, 'после тишины реплика не вылетает мгновенно')
d = make(11); assert.equal(advance(d, 1800, { active: false }).length, 0, 'неактивное окно молчит')

// say(): из кода, всегда, перебивает; пустое не показывает; держит указанное время.
d = make(); talk.react(d.s, 'greeting', d.rnd, { hour: 8 })
assert.equal(talk.say(d.s, '  Уведомление: готово.  ', 0, d.rnd), 'Уведомление: готово.', 'say перебивает и обрезает пробелы')
assert.equal(d.s.text, 'Уведомление: готово.')
assert.equal(talk.say(d.s, '   ', 0, d.rnd), '', 'пустой текст не показывается')
assert.equal(d.s.text, 'Уведомление: готово.')
talk.say(d.s, 'Коротко', 12, d.rnd); advance(d, 11); assert(talk.visible(d.s), 'явное время показа держится')
advance(d, 1.5); assert(!talk.visible(d.s))
assert.equal(talk.say(d.s, null), '' , 'null — пусто')
assert.equal(talk.react(d.s, 'petStart', d.rnd, {}), null, 'своя реплика (say) не перебивается автоматической')
talk.say(d.s, 'Ещё', 0, d.rnd); talk.hide(d.s); assert(!talk.visible(d.s), 'hide прячет облако')
// say не мешает последующим репликам после паузы.
advance(d, 3); assert(talk.react(d.s, 'petStart', d.rnd, {}) !== null, 'после say и паузы поглаживание снова реагирует')

// Пустые данные не ломают.
const empty = talk.create({}, seeded(1)); assert.equal(talk.react(empty, 'petStart', seeded(1), {}), null)
assert.equal(talk.react(talk.create(null), 'petStart', null, {}), null)
// pick не падает на единственной реплике.
const single = talk.create({ petStart: ['Только я.'] }, seeded(1))
assert.equal(talk.react(single, 'petStart', seeded(2), {}), 'Только я.')
console.log('NAOMI_DIALOGUE_PASS')
