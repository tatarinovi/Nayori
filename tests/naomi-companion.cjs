// Логика Naomi без QML: жест поглаживания и правила реплик.
const fs = require('fs'), vm = require('vm'), assert = require('assert')
function moduleAt(file) { const c = {}; vm.createContext(c); vm.runInContext(fs.readFileSync(file, 'utf8'), c); return c }
const pet = moduleAt('services/companion/NaomiBehavior.js')
const talk = moduleAt('services/companion/NaomiDialogue.js')
const data = moduleAt('services/companion/NaomiLines.js')
const lines = data.lines
const sysData = moduleAt('services/companion/NaomiSystemData.js').data
const ev = moduleAt('services/companion/NaomiSystemEvents.js')
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
    assert(typeof text === 'string' && text === text.trim() && text.length >= 6 && text.length <= 100, `${kind}: длина «${text}»`)
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

// Приветствие: показывается, по времени суток, и не чаще раза в два часа.
let d = make()
let greet = talk.react(d.s, 'greeting', d.rnd, { hour: 8 })
assert(lines.greeting.morning.includes(greet), 'утреннее приветствие: ' + greet)
assert(talk.visible(d.s) && d.s.text === greet)
advance(d, 9.5); assert(talk.visible(d.s) === false, 'облако гаснет само')
assert.equal(talk.react(d.s, 'greeting', d.rnd, { hour: 8 }), null, 'приветствие не чаще раза в два часа')
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

// Idle: 20–35 минут между попытками, с пропусками, максимум две за час.
d = make(11)
assert.equal(advance(d, 1199).length, 0, 'первые 20 минут тихо')
const idleSpoke = advance(d, 7200)
assert(idleSpoke.length > 0 && idleSpoke.every(t => lines.idle.includes(t)))
const hour = advance(make(5), 3600)
assert(hour.length <= 2, 'не больше двух за час: ' + hour.length)
d = make(11); assert.equal(advance(d, 1800, { active: true, quiet: true }).length, 0, 'при поглаживании молчит')
assert.equal(advance(d, 1199, { active: true }).length, 0, 'после взаимодействия минимум 20 минут тишины')
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

// --- системные реплики ---
// Полнота контрактов проверяется независимо от выбранной литературной формулировки.
const SYSTEM_KINDS = ['cpu','idle','terminal','game','battery','windows','night','update','offline','return','musicStart','musicStop','hoverStill']
const VERBATIM = Object.fromEntries(SYSTEM_KINDS.map(k => [k, lines.system[k].replace('{percent}', '10').replace('{time}', 'три часа ночи')]))
assert.deepEqual(Object.keys(lines.system).sort(), Object.keys(VERBATIM).sort(), 'тринадцать системных реплик')
const probe = ev.create(sysData, lines)
assert.deepEqual(ev.kinds(probe).sort(), Object.keys(VERBATIM).sort())
for (const [kind, text] of Object.entries(VERBATIM)) {
    assert.equal(ev.preview(probe, kind, kind === 'battery' ? 10 : kind === 'night' ? 3 : undefined, 14), text, 'дословно: ' + kind)
    assert(text.length <= 100, kind + ': влезает в облако на пять строк')
    const k = sysData.kinds[kind]
    assert(k && [1, 2, 3].includes(k.priority) && k.cooldown >= 0 && k.expire > 0, 'данные вида ' + kind)
}
assert.equal(ev.preview(probe, 'nope'), '', 'неизвестный вид — пусто')

// Подстановка процента и склонение часа.
assert.equal(ev.preview(probe, 'battery', undefined), lines.system.battery.replace('{percent}', '15'), 'по умолчанию 15%')
for (const p of [15, 10, 5, 20, 1]) assert(ev.preview(probe, 'battery', p).startsWith(`Осталось ${p}% заряда.`), 'процент ' + p)
assert(ev.preview(probe, 'battery', 14.6).startsWith('Осталось 15% заряда'), 'процент округляется')
const NIGHT = ['Уже полночь.', 'Уже час ночи.', 'Уже два часа ночи.', 'Уже три часа ночи.', 'Уже четыре часа ночи.', 'Уже пять утра.']
for (let h = 0; h <= 5; h++) {
    const text = ev.preview(probe, 'night', h)
    assert(text.startsWith(NIGHT[h] + ' Я сегодня за негромкие разговоры.'), `ночь ${h}: ${text}`)
}
assert(ev.preview(probe, 'night', undefined, 4).startsWith('Уже четыре часа ночи.'), 'ночью без значения — текущий час')
assert(ev.preview(probe, 'night', undefined, 14).startsWith('Уже три часа ночи.'), 'днём без значения — три часа ночи')
assert(!/\{|\}/.test(ev.preview(probe, 'night', 99)) && ev.preview(probe, 'night', 99).startsWith('Уже пять утра'), 'час вне диапазона не ломает текст')

// Классификация app_id: терминалы, игры, прочее. Списки живут в данных.
for (const id of ['kitty', 'foot', 'Alacritty', 'org.wezfurlong.wezterm', 'com.mitchellh.ghostty', 'org.kde.konsole', 'gnome-terminal-server', 'xterm'])
    assert.equal(ev.classify(sysData, id), 'terminal', id)
for (const id of ['steam_app_730', 'gamescope', 'lutris', 'net.lutris.Lutris', 'heroic', 'game.exe', 'steam_app_0'])
    assert.equal(ev.classify(sysData, id), 'game', id)
for (const id of ['', undefined, null, 'firefox', 'steam', 'code', 'org.telegram.desktop', '.exe', 'kittycat'])
    assert.equal(ev.classify(sysData, id), '', 'не терминал и не игра: ' + id)

// Разбор процессов обновления: только настоящее обновление, не поиск и не установка.
assert.equal(ev.scanUpdate(''), false)
assert.equal(ev.scanUpdate('1234 pacman -Syu'), true)
assert.equal(ev.scanUpdate('1234 /usr/bin/pacman -Su --noconfirm'), true)
assert.equal(ev.scanUpdate('1234 pacman -Syyu'), true)
assert.equal(ev.scanUpdate('1234 pacman --sync --sysupgrade'), true)
assert.equal(ev.scanUpdate('77 paru\n'), true, 'paru без аргументов обновляет')
assert.equal(ev.scanUpdate('77 yay -Syu'), true)
assert.equal(ev.scanUpdate('77 yay -Sua'), true)
assert.equal(ev.scanUpdate('88 topgrade'), true)
assert.equal(ev.scanUpdate('77 yay -Ss firefox'), false, 'поиск — не обновление')
assert.equal(ev.scanUpdate('77 pacman -S firefox'), false, 'установка — не обновление')
assert.equal(ev.scanUpdate('77 pacman -Qu'), false)
assert.equal(ev.scanUpdate('LOCK\n77 pacman -S firefox'), false, 'блокировка с видимой установкой — не обновление')
assert.equal(ev.scanUpdate('LOCK'), true, 'блокировка без видимых процессов')
assert.equal(ev.scanUpdate('мусор без номера\n\n'), false)

// Прогон: s — состояние детекторов; шаг 0,5 с. Возвращает показанные реплики [{kind,text}].
const ENV = { enabled: true, active: true, quiet: false, hour: 14, dayKey: 'd1', userIdle: false, cpu: 0, cloud: 'free' }
function fresh() { const s = ev.create(sysData, lines); go(s, 25); return s }   // после тишины при запуске
function go(s, secs, env) {
    const out = []
    for (let t = 0; t < secs - 1e-9; t += 0.5) { const r = ev.tick(s, 0.5, Object.assign({}, ENV, env)); if (r) out.push(r) }
    return out
}
const kindsOf = out => out.map(o => o.kind)
const win = (id, appId) => ({ id, appId })
function winList(n, extra) { const l = []; for (let i = 1; i <= n; i++) l.push(win(i, 'app' + i)); return l.concat(extra || []) }

// Тишина после запуска: реплика не раньше startupQuiet.
let s2 = ev.create(sysData, lines)
ev.battery(s2, { present: true, percent: 8, charging: false })
assert.deepEqual(go(s2, 10), [], 'первые секунды после запуска тихо')
assert.deepEqual(kindsOf(go(s2, 12)), ['battery'], 'потом заряд всё же упомянут')

// CPU: устойчиво выше 85% в среднем за 30 с, с гистерезисом и кулдауном.
s2 = fresh()
assert.deepEqual(go(s2, 12, { cpu: 0.99 }), [], 'короткий всплеск не повод')
assert.deepEqual(go(s2, 60, { cpu: 0.1 }), [])
s2 = fresh()
let out = go(s2, 20, { cpu: 0.95 }); assert.equal(out.length, 0, 'среднее за 30 с ещё ниже порога — рано')
out = go(s2, 15, { cpu: 0.95 }); assert.deepEqual(kindsOf(out), ['cpu'], 'устойчиво высокая нагрузка — реплика')
assert.equal(out[0].text, VERBATIM.cpu)
assert.deepEqual(go(s2, 300, { cpu: 0.99 }), [], 'пока висит — молчит')
assert.deepEqual(go(s2, 120, { cpu: 0.7 }), [], 'между порогами снова не взводится'); assert.equal(s2.cpu.armed, false)
go(s2, 40, { cpu: 0.3 }); assert.equal(s2.cpu.armed, true, 'ниже 60% — взведено')
assert.deepEqual(go(s2, 60, { cpu: 0.99 }), [], 'кулдаун 20 минут держит повтор')
go(s2, 1300, { cpu: 0.2 })
assert.deepEqual(kindsOf(go(s2, 40, { cpu: 0.99 })), ['cpu'], 'после кулдауна — снова')
s2 = fresh()
assert.deepEqual(go(s2, 120, { cpu: 0.8 }), [], '80% — ниже порога')
assert.deepEqual(go(s2, 5, { cpu: NaN }), [], 'мусорные отсчёты не ломают')

// Бездействие и возвращение. idle10 и return не конфликтуют, у каждого свой кулдаун.
s2 = fresh()
ev.idle(s2, 'away', true)
assert.deepEqual(go(s2, 5), [], 'ушёл на минуту — молчим')
ev.idle(s2, 'away', false)
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['return']); assert.equal(out[0].text, VERBATIM.return)
ev.idle(s2, 'away', true); ev.idle(s2, 'away', false)
assert.deepEqual(go(s2, 100), [], 'возвращение не чаще раза в 30 минут')
ev.idle(s2, 'away', false); assert.deepEqual(go(s2, 5), [], 'действие без ухода — не возвращение')
s2 = fresh()
ev.idle(s2, 'away', true); ev.idle(s2, 'long', true)
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['idle']); assert.equal(out[0].text, VERBATIM.idle)
go(s2, 180)
ev.idle(s2, 'long', false); ev.idle(s2, 'away', false)
assert.deepEqual(kindsOf(go(s2, 1)), ['return'], 'после реплики про бездействие возвращение тоже говорит')
ev.idle(s2, 'long', true); assert.deepEqual(go(s2, 60), [], 'кулдаун бездействия')
// Вернулся сразу после реплики про бездействие: возвращение ждёт общий интервал, но устаревает за 20 с.
s2 = fresh(); ev.idle(s2, 'away', true); ev.idle(s2, 'long', true); go(s2, 1)
ev.idle(s2, 'long', false); ev.idle(s2, 'away', false)
assert.deepEqual(go(s2, 60), [], 'возвращение сразу за репликой про бездействие не наслаивается')

// Окна: терминал, игра, число окон. Исходные окна и висящее «много окон» поводом не считаются.
s2 = ev.create(sysData, lines); go(s2, 25)
ev.windows(s2, winList(8, [win(20, 'kitty'), win(21, 'steam_app_1')]), true)
go(s2, 4); ev.windows(s2, winList(8, [win(20, 'kitty'), win(21, 'steam_app_1')]), true)
assert.deepEqual(go(s2, 60), [], 'окна, открытые до запуска, не повод')
ev.windows(s2, winList(8, [win(20, 'kitty'), win(21, 'steam_app_1'), win(22, 'foot')]), true)
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['terminal'], 'новый терминал'); assert.equal(out[0].text, VERBATIM.terminal)
ev.windows(s2, winList(8, [win(20, 'kitty'), win(21, 'steam_app_1'), win(22, 'foot'), win(23, 'alacritty')]), true)
assert.deepEqual(go(s2, 180), [], 'второй терминал сразу — кулдаун вида и общий интервал')
ev.windows(s2, winList(8, [win(20, 'kitty'), win(21, 'steam_app_1'), win(22, 'foot'), win(23, 'alacritty'), win(24, 'steam_app_7')]), true)
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['game'], 'новая игра'); assert.equal(out[0].text, VERBATIM.game)
ev.windows(s2, [], false); ev.windows(s2, winList(3), true)
assert.deepEqual(go(s2, 30), [], 'переподключение к niri — снова исходные окна')

s2 = fresh(); ev.windows(s2, [], true)
go(s2, 4); ev.windows(s2, winList(2), true)
out = go(s2, 1); assert.deepEqual(out, [], 'окна есть, но не терминал')
ev.windows(s2, [win(1, ''), win(2, 'firefox')], true); ev.windows(s2, [win(1, 'kitty'), win(2, 'firefox')], true)
assert.deepEqual(kindsOf(go(s2, 1)), ['terminal'], 'app_id пришёл сразу после открытия')
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4)
ev.windows(s2, [win(1, '')], true); go(s2, 10); ev.windows(s2, [win(1, 'kitty')], true)
assert.deepEqual(go(s2, 5), [], 'app_id сменился через долгое время — не новое окно')

// Больше пяти окон: при пересечении вверх, не пока висит, повтор — после кулдауна.
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4)
for (let n = 1; n <= 5; n++) ev.windows(s2, winList(n), true)
assert.deepEqual(go(s2, 5), [], 'пять окон — ещё не больше пяти')
ev.windows(s2, winList(6), true)
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['windows']); assert.equal(out[0].text, VERBATIM.windows)
ev.windows(s2, winList(7), true); ev.windows(s2, winList(9), true)
assert.deepEqual(go(s2, 100), [], 'пока висит — молчит')
ev.windows(s2, winList(5), true); ev.windows(s2, winList(6), true)
assert.deepEqual(go(s2, 100), [], 'снова вверх, но кулдаун 30 минут')
ev.windows(s2, winList(4), true); go(s2, 1800); ev.windows(s2, winList(6), true)
assert.deepEqual(kindsOf(go(s2, 1)), ['windows'], 'после кулдауна — снова')

// Батарея: пороги 20/10/5 по одному разу, зарядка взводит заново, без батареи ничего.
s2 = fresh()
ev.battery(s2, { present: false, percent: 3, charging: false }); assert.deepEqual(go(s2, 30), [], 'нет батареи (десктоп)')
ev.battery(s2, { present: true, percent: 50, charging: false }); assert.deepEqual(go(s2, 30), [])
ev.battery(s2, { present: true, percent: 20, charging: true }); assert.deepEqual(go(s2, 30), [], 'на зарядке молчит')
ev.battery(s2, { present: true, percent: 21, charging: false }); assert.deepEqual(go(s2, 30), [], '21% — ещё не порог')
ev.battery(s2, { present: true, percent: 20, charging: false })
out = go(s2, 1); assert.equal(out.length, 1); assert(out[0].text.includes('20% заряда'))
ev.battery(s2, { present: true, percent: 19, charging: false }); assert.deepEqual(go(s2, 60), [], 'порог 20 один раз')
ev.battery(s2, { present: true, percent: 10, charging: false })
out = go(s2, 1); assert.equal(out.length, 1); assert(out[0].text.includes('10%'), out[0].text)
ev.battery(s2, { present: true, percent: 5, charging: false }); out = go(s2, 11)
assert.equal(out.length, 1); assert(out[0].text.includes('5%'), 'порог 5%: ' + out[0].text)
assert.deepEqual(go(s2, 600), [], 'ниже 5% — больше ничего')
ev.battery(s2, { present: true, percent: 40, charging: true }); go(s2, 30)
ev.battery(s2, { present: true, percent: 17, charging: false })
assert.equal(go(s2, 12).length, 1, 'после зарядки пороги работают снова')
s2 = fresh(); ev.battery(s2, { present: true, percent: 4, charging: false })
out = go(s2, 60); assert.equal(out.length, 1, 'резкое падение сразу ниже всех порогов — одна реплика'); assert(out[0].text.includes('4%'))
s2 = fresh(); ev.battery(s2, { present: true, percent: 30, charging: false }); ev.battery(s2, { present: true, percent: 24, charging: false })
assert.deepEqual(go(s2, 30), [], '24% — выше порога'); ev.battery(s2, { present: true, percent: 18, charging: false }); assert.equal(go(s2, 2).length, 1)
ev.battery(s2, { present: true, percent: 22, charging: false }); ev.battery(s2, { present: true, percent: 19, charging: false })
assert.deepEqual(go(s2, 60), [], 'колебание около порога без выхода выше 25% не повторяет')
ev.battery(s2, { present: true, percent: NaN, charging: false }); assert.deepEqual(go(s2, 5), [], 'мусор не ломает')
s2 = fresh(); ev.battery(s2, { present: true, percent: 15, charging: false }); ev.battery(s2, { present: true, percent: 15, charging: true })
assert.deepEqual(go(s2, 5), [], 'поставили на зарядку, пока реплика ждала, — устарела')

// Интернет: после устойчивой потери 8 с и только если до этого был.
s2 = fresh()
ev.network(s2, 'offline'); assert.deepEqual(go(s2, 60), [], 'запуск без сети не повод')
ev.network(s2, 'online'); go(s2, 10)
ev.network(s2, 'offline'); assert.deepEqual(go(s2, 5), [], 'короткий обрыв не повод')
ev.network(s2, 'online'); assert.deepEqual(go(s2, 20), [])
ev.network(s2, 'offline'); assert.deepEqual(go(s2, 7), [], '7 с ещё рано')
out = go(s2, 2); assert.deepEqual(kindsOf(out), ['offline']); assert.equal(out[0].text, VERBATIM.offline)
assert.deepEqual(go(s2, 100), [], 'пока нет сети — один раз')
ev.network(s2, 'online'); go(s2, 5); ev.network(s2, 'offline')
assert.deepEqual(go(s2, 60), [], 'новый обрыв в пределах 10 минут — кулдаун')
go(s2, 100); ev.network(s2, 'online'); go(s2, 700); ev.network(s2, 'offline')
assert.deepEqual(kindsOf(go(s2, 10)), ['offline'], 'через 10 минут — снова')
s2 = fresh(); ev.network(s2, 'online'); go(s2, 5); ev.network(s2, 'unknown'); assert.deepEqual(go(s2, 60), [], 'неизвестное состояние — не потеря')
s2 = fresh(); ev.network(s2, 'online'); go(s2, 5); ev.network(s2, 'offline'); go(s2, 9, { cloud: 'busy' }); ev.network(s2, 'online')
assert.deepEqual(go(s2, 5), [], 'пока ждала очереди, сеть вернулась — реплика устарела')

// Обновление системы: начало, а не наличие; первый опрос — исходное состояние.
s2 = fresh(); ev.update(s2, true); assert.deepEqual(go(s2, 30), [], 'обновление уже шло до запуска оболочки')
for (let i = 0; i < 3; i++) ev.update(s2, false)
ev.update(s2, true); out = go(s2, 1); assert.deepEqual(kindsOf(out), ['update']); assert.equal(out[0].text, VERBATIM.update)
ev.update(s2, true); ev.update(s2, false); ev.update(s2, true)
assert.deepEqual(go(s2, 100), [], 'пауза между шагами paru — не новое обновление')
s2 = fresh(); ev.update(s2, false); ev.update(s2, true); assert.deepEqual(kindsOf(go(s2, 1)), ['update'], 'нет → есть: начало')

// Ночь: один раз за ночь, по часу, не днём, не когда ушёл.
s2 = fresh()
assert.deepEqual(go(s2, 60, { hour: 14 }), [], 'днём не говорит')
out = go(s2, 1, { hour: 3, dayKey: 'n1' }); assert.equal(out.length, 1); assert.equal(out[0].text, VERBATIM.night)
assert.deepEqual(go(s2, 7200, { hour: 4, dayKey: 'n1' }), [], 'в ту же ночь — один раз')
go(s2, 25000, { hour: 14, dayKey: 'n1' })
out = go(s2, 1, { hour: 2, dayKey: 'n2' }); assert.equal(out.length, 1); assert(out[0].text.startsWith('Уже два часа ночи.'), 'следующая ночь — снова, по её часу')
s2 = fresh(); assert.deepEqual(go(s2, 60, { hour: 3, dayKey: 'x', userIdle: true }), [], 'ушёл от компьютера — не ночная работа')
for (const [h, word] of [[0, 'Уже полночь.'], [1, 'Уже час ночи.'], [5, 'Уже пять утра.']]) {
    s2 = fresh(); out = go(s2, 1, { hour: h, dayKey: 'k' + h }); assert(out[0].text.startsWith(word), out[0].text)
}
s2 = fresh(); assert.deepEqual(go(s2, 5, { hour: 6, dayKey: 'k' }), [], '06:00 — уже не ночь'); assert.deepEqual(go(s2, 5, { hour: 23, dayKey: 'k' }), [], '23:00 — ещё не ночь')

// Приоритеты, общий интервал, очередь, устаревание.
s2 = fresh()
ev.windows(s2, [], true); go(s2, 4)
ev.windows(s2, [win(1, 'kitty')], true); ev.battery(s2, { present: true, percent: 9, charging: false }); ev.network(s2, 'online')
out = go(s2, 1, { cloud: 'busy' }); assert.deepEqual(out, [], 'облако занято — ждём')
out = go(s2, 1); assert.deepEqual(kindsOf(out), ['battery'], 'срочное идёт вперёд болтовни')
assert.deepEqual(go(s2, 30), [], 'общий интервал 45 с между системными репликами')
assert.deepEqual(go(s2, 20), [], 'терминал ждал интервал дольше 30 с — повод устарел')
go(s2, 180)
ev.windows(s2, [win(1, 'kitty'), win(2, 'foot')], true)
assert.deepEqual(kindsOf(go(s2, 180)), ['terminal'], 'следующая — по истечении общего интервала')
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4)
ev.windows(s2, [win(1, 'kitty')], true); ev.battery(s2, { present: true, percent: 9, charging: false })
out = go(s2, 1, { cloud: 'replaceable' }); assert.deepEqual(kindsOf(out), ['battery'], 'срочная заменяет приветствие')
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4); ev.windows(s2, [win(1, 'kitty')], true)
assert.deepEqual(go(s2, 10, { cloud: 'replaceable' }), [], 'обычная реплика приветствие не заменяет')
assert.deepEqual(kindsOf(go(s2, 1)), ['terminal'], 'зато выходит, когда облако свободно')
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4); ev.windows(s2, [win(1, 'kitty')], true)
assert.deepEqual(go(s2, 29, { cloud: 'busy' }), [], 'ждёт облако'); assert.deepEqual(go(s2, 3, { cloud: 'busy' }), []); assert.deepEqual(go(s2, 5), [], 'повод устарел (30 с)')
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4); ev.windows(s2, [win(1, 'kitty')], true)
assert.deepEqual(go(s2, 20, { quiet: true }), [], 'гладят — молчим'); assert.deepEqual(kindsOf(go(s2, 1)), ['terminal'], 'перестали гладить — сказала')
// Два срочных подряд идут через urgentGap, а не общий.
s2 = fresh(); ev.network(s2, 'online'); go(s2, 5); ev.network(s2, 'offline'); ev.battery(s2, { present: true, percent: 9, charging: false })
out = go(s2, 30); assert.deepEqual(kindsOf(out), ['battery', 'offline'], 'батарея и интернет — по срочному интервалу 10 с')

// Выключено и скрыто: ничего не копится и не показывается.
for (const off of [{ enabled: false }, { active: false }]) {
    s2 = fresh()
    ev.windows(s2, [], true); go(s2, 4, off)
    ev.windows(s2, [win(1, 'kitty')], true); ev.battery(s2, { present: true, percent: 5, charging: false }); ev.idle(s2, 'away', true); ev.idle(s2, 'away', false)
    assert.deepEqual(go(s2, 600, Object.assign({ cpu: 0.99, hour: 3, dayKey: 'z' }, off)), [], 'молчит при ' + JSON.stringify(off))
    assert.equal(s2.queue.length, 0, 'очередь пуста')
    // Накопленных событий нет; низкий заряд — состояние, а не событие: после включения о нём напомнят один раз.
    out = go(s2, 15, { cpu: 0.2 }); assert.deepEqual(kindsOf(out), ['battery'], 'старые поводы после включения не всплывают')
}
// Окна, открытые при выключенной настройке, не считаются новыми после включения.
s2 = fresh(); ev.windows(s2, [], true); go(s2, 4, { enabled: false }); ev.windows(s2, winList(7, [win(30, 'kitty')]), true)
go(s2, 10, { enabled: false }); assert.deepEqual(go(s2, 30), [], 'включили настройку — прежние окна не повод')
ev.windows(s2, winList(7, [win(30, 'kitty'), win(31, 'foot')]), true); assert.deepEqual(kindsOf(go(s2, 1)), ['terminal'], 'зато новые — повод')

// Сводка по виду: у каждого есть свой кулдаун из данных, ночь — раз за ночь.
for (const k of Object.keys(VERBATIM)) assert(k in sysData.kinds, 'данные: ' + k)
assert(sysData.kinds.battery.priority === 3 && sysData.kinds.offline.priority === 3 && sysData.kinds.terminal.priority < 3, 'батарея и интернет важнее болтовни')
assert(sysData.globalGap >= 30 && sysData.urgentGap < sysData.globalGap, 'общий интервал задан')

// Связка с облаком: слот, показ системной реплики, поглаживание её не перебивает.
d = make()
assert.equal(talk.slot(d.s), 'free')
talk.react(d.s, 'greeting', d.rnd, { hour: 12 }); assert.equal(talk.slot(d.s), 'replaceable', 'приветствие можно заменить срочной')
advance(d, 55); assert.equal(talk.slot(d.s), 'free', 'после паузы свободно')
assert.equal(talk.system(d.s, VERBATIM.cpu, d.rnd), VERBATIM.cpu); assert(talk.visible(d.s) && d.s.kind === 'system')
assert.equal(talk.slot(d.s), 'busy', 'системная реплика занимает облако')
assert.equal(talk.react(d.s, 'petStart', d.rnd, {}), null, 'поглаживание не перебивает системную реплику')
assert.equal(talk.system(d.s, '  ', d.rnd), '', 'пустое не показывается')
advance(d, 8); assert.equal(talk.slot(d.s), 'busy', 'пауза после облака'); advance(d, 46); assert.equal(talk.slot(d.s), 'free')
const longest = Math.max(...Object.values(VERBATIM).map(t => t.length))
assert(talk.holdFor(VERBATIM.night) >= 4 && talk.holdFor(VERBATIM.night) <= 9, 'долгая реплика держится 6–9 с: ' + talk.holdFor(VERBATIM.night) + ' ' + longest)
console.log('NAOMI_SYSTEM_PASS')
