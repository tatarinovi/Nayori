// Чистая логика системных реплик Naomi: детекторы событий (пересечения порогов, гистерезис), очередь,
// приоритеты, кулдауны и общий интервал. Без QML, часов и случайности: время идёт шагом dt в tick().
//
// Поток: источники (CPU, niri, UPower, сеть, ввод, процессы pacman) вызывают window/battery/network/
// update/idle и подают CPU в env.cpu. Детектор лишь предлагает повод (offer). Показывает его tick(),
// когда можно: Naomi показана и настройка включена, облако свободно, не гладят, прошёл общий интервал.
// Тексты — NaomiLines.js (раздел system), числа и списки — NaomiSystemData.js; сюда они приходят в create().
//
// Правила, чтобы Naomi не мешала:
//   * при выключенной настройке или скрытой Naomi поводы не копятся, очередь сбрасывается;
//   * у каждого вида свой кулдаун, между любыми двумя системными репликами — общий интервал;
//   * повод ждёт своей очереди ограниченное время (expire) и потом устаревает;
//   * срочные (priority 3: батарея, интернет) идут вперёд очереди и могут заменить приветствие
//     и «покойную» реплику; остальные ждут, пока облако исчезнет;
//   * существовавшие до запуска окна, уже низкий заряд при старте без сети и т.п. не повод
//     (детекторы запоминают исходное состояние).

const QUEUE_LIMIT = 4
const DEFAULT_KIND = { priority: 1, cooldown: 600, expire: 30 }

function create(data, lines) {
    return {
        data: data || {}, lines: lines || {},
        time: 0, on: true, queue: [], last: {}, lastAny: -1e9, nightKey: "",
        cpu: { samples: [], acc: 0, armed: true, avg: 0 },
        win: { live: false, liveAt: 0, seen: {}, above: false },
        bat: { info: null, fired: {} },
        net: { input: "unknown", cur: "unknown", since: 0, everOnline: false, fired: false },
        upd: { known: false, running: false, absent: 0 },
        away: false
    }
}

function info(s, kind) {
    const k = s.data.kinds && s.data.kinds[kind]
    return k || DEFAULT_KIND
}

function cooling(s, kind) {
    const at = s.last[kind]
    return at !== undefined && s.time - at < info(s, kind).cooldown
}

function queued(s, kind) { return s.queue.some(e => e.kind === kind) }

// Включить или выключить системные реплики целиком. Выключение сбрасывает очередь и окно CPU.
function setOn(s, on) {
    const next = !!on
    if (next === s.on) return
    s.on = next
    s.queue = []
    s.cpu.samples = []
    s.cpu.acc = 0
}

// Предложить повод. Возвращает true, если он принят в очередь.
function offer(s, kind, ctx) {
    if (!s.on || cooling(s, kind)) return false
    const critical = kind === "battery" && Number(ctx && ctx.percent) <= 5
    const k = info(s, kind)
    s.queue = s.queue.filter(e => e.kind !== kind)
    s.queue.push({ kind: kind, ctx: ctx || {}, at: s.time, priority: critical ? 4 : k.priority })
    // Срочные вперёд, внутри приоритета — по порядку появления.
    s.queue.sort((a, b) => b.priority - a.priority || a.at - b.at)
    if (s.queue.length > QUEUE_LIMIT) s.queue.length = QUEUE_LIMIT
    return true
}

// --- классификация окон ---

function lower(v) { return String(v === undefined || v === null ? "" : v).toLowerCase() }

// "terminal", "game" или "" по app_id окна.
function classify(data, appId) {
    const id = lower(appId)
    if (id === "") return ""
    if ((data.terminals || []).indexOf(id) >= 0) return "terminal"
    if ((data.games || []).indexOf(id) >= 0) return "game"
    if ((data.gamePrefixes || []).some(p => id.indexOf(p) === 0)) return "game"
    if ((data.gameSuffixes || []).some(p => id.length > p.length && id.slice(-p.length) === p)) return "game"
    return ""
}

// Список окон niri (Niri.windows) и доступность. Новые окна терминала и игр и пересечение порога
// числа окон вверх — поводы. Окна, пришедшие в первые windowGrace секунд после (пере)подключения, уже были.
function windows(s, list, available) {
    const w = s.win
    if (!available || !Array.isArray(list)) {
        w.live = false; w.seen = {}; w.above = false
        return
    }
    if (!w.live) { w.live = true; w.liveAt = s.time; w.seen = {}; w.above = false }
    const grace = s.time - w.liveAt < (s.data.windowGrace === undefined ? 3 : s.data.windowGrace)
    const newAge = s.data.windowNewAge === undefined ? 4 : s.data.windowNewAge
    const present = {}
    for (const win of list) {
        if (!win) continue
        const id = win.id, appId = lower(win.appId)
        present[id] = true
        let rec = w.seen[id]
        if (!rec) {
            rec = w.seen[id] = { t: s.time, appId: appId, old: grace, fired: false }
            if (grace) continue
        } else if (appId !== rec.appId) {
            // app_id мог появиться чуть позже открытия окна.
            rec.appId = appId
            if (rec.old || rec.fired || s.time - rec.t > newAge) continue
        } else continue
        const kind = classify(s.data, appId)
        if (kind !== "") { rec.fired = true; offer(s, kind, { appId: appId }) }
    }
    for (const id of Object.keys(w.seen)) if (!present[id]) delete w.seen[id]
    const limit = s.data.windowsLimit === undefined ? 5 : s.data.windowsLimit
    const count = list.length
    if (grace) w.above = count > limit
    else if (!w.above && count > limit) { w.above = true; offer(s, "windows", { count: count }) }
    else if (w.above && count <= limit) w.above = false
}

// --- батарея ---

// info: { present, percent (0–100), charging }. Нет батареи (десктоп) — ничего не происходит.
function battery(s, input) {
    s.bat.info = input || null
    evalBattery(s)
}

function evalBattery(s) {
    const b = s.bat, i = b.info
    if (!s.on) return
    if (!i || !i.present || !isFinite(Number(i.percent))) { b.fired = {}; return }
    const p = Math.round(Number(i.percent))
    const cfg = s.data.battery || { levels: [20, 10, 5], rearm: 25 }
    if (i.charging || p > cfg.rearm) { b.fired = {}; return }
    const crossed = cfg.levels.filter(l => p <= l && !b.fired[l])
    if (crossed.length === 0) return
    for (const l of crossed) b.fired[l] = true
    offer(s, "battery", { percent: p })
}

// --- интернет ---

// state: "online" | "offline" | "unknown". Реплика — после offlineAfter секунд устойчивой потери
// и только если до этого связь была (старт без сети не повод).
function network(s, state) {
    const next = state === "online" || state === "offline" ? state : "unknown"
    s.net.input = next
    if (next !== s.net.cur) { s.net.cur = next; s.net.since = 0 }
    if (next === "online") { s.net.everOnline = true; s.net.fired = false }
}

function evalNetwork(s, dt) {
    const n = s.net
    n.since += dt
    if (!s.on || n.cur !== "offline" || !n.everOnline || n.fired) return
    if (n.since >= (s.data.offlineAfter === undefined ? 8 : s.data.offlineAfter)) {
        n.fired = true
        offer(s, "offline", {})
    }
}

// --- обновление системы ---

function upgradeArgs(args) {
    let sync = false, up = false
    for (const a of args) {
        if (a === "--sync") sync = true
        else if (a === "--sysupgrade") up = true
        else if (/^-[A-Za-z]+$/.test(a)) {
            if (a.indexOf("S") >= 0) sync = true
            if (a.indexOf("u") >= 0) up = true
        }
    }
    return sync && up
}

// Разбор вывода проверки: необязательная строка LOCK (есть db.lck) и строки pgrep -a «PID команда».
// true — идёт обновление: pacman -Syu/-Su, paru/yay без аргументов или с -Syu, topgrade, либо стоит
// блокировка, а процессов pacman не видно (например, pamac).
function scanUpdate(text) {
    let lock = false, family = false
    for (const raw of String(text || "").split("\n")) {
        const t = raw.trim()
        if (t === "") continue
        if (t === "LOCK") { lock = true; continue }
        const m = /^\d+\s+(.+)$/.exec(t)
        if (!m) continue
        const argv = m[1].split(/\s+/)
        const name = argv[0].split("/").pop()
        const args = argv.slice(1)
        if (name === "topgrade") return true
        if (name === "pacman" || name === "paru" || name === "yay") {
            family = true
            if (upgradeArgs(args)) return true
            if (name !== "pacman" && args.length === 0) return true
        }
    }
    return lock && !family
}

// running — результат scanUpdate очередного опроса. Реплика на начало; первый опрос — исходное состояние.
// Конец обновления засчитывается после трёх пустых опросов подряд: у paru/yay между шагами бывают паузы.
function update(s, running) {
    const u = s.upd
    if (running) {
        u.absent = 0
        if (u.known && !u.running) offer(s, "update", {})
        u.running = true
    } else {
        u.absent++
        if (u.absent >= 3) u.running = false
    }
    u.known = true
}

// Media playback is presence even when the mouse and keyboard are idle.
// Starting playback clears stale absence/return events without announcing a return.
function mediaPlayback(s, playing) {
    s.mediaPlaying = !!playing
    if (s.mediaPlaying) {
        s.away = false
        s.queue = s.queue.filter(e => e.kind !== "return" && e.kind !== "idle")
    }
}

// --- бездействие ---

// level: "long" (десять минут) или "away" (две минуты без ввода и воспроизведения).
// Конец отсутствия — первое действие пользователя, возвращение.
function idle(s, level, isIdle) {
    if (s.mediaPlaying) return
    if (level === "long") {
        if (isIdle) offer(s, "idle", {})
    } else if (level === "away") {
        if (isIdle) s.away = true
        else if (s.away) { s.away = false; offer(s, "return", {}) }
    }
}

// --- время и показ ---

function sampleCpu(s, load) {
    const c = s.cpu, cfg = s.data.cpu || { window: 30, enter: 0.85, exit: 0.6 }
    const v = Number(load)
    if (!isFinite(v)) return
    c.samples.push(Math.max(0, Math.min(1, v)))
    if (c.samples.length > cfg.window) c.samples.shift()
    c.avg = c.samples.reduce((a, b) => a + b, 0) / c.samples.length
    if (c.samples.length < cfg.window) return
    if (c.armed && c.avg >= cfg.enter) { c.armed = false; offer(s, "cpu", { avg: c.avg }) }
    else if (!c.armed && c.avg <= cfg.exit) c.armed = true
}

function inNight(s, hour) {
    const n = s.data.night || { from: 0, to: 5 }
    const h = Number(hour)
    return isFinite(h) && h >= n.from && h <= n.to
}

// «три часа ночи» по часу 0–5; вне диапазона — ближайшая из подготовленных формулировок.
function nightPhrase(lines, hour) {
    const list = lines.nightTimes || []
    if (list.length === 0) return ""
    const h = Math.max(0, Math.min(list.length - 1, Math.floor(Number(hour) || 0)))
    return list[h]
}

// Исходная реплика и варианты из systemVariants. Без rnd — всегда исходная строка.
function chooseLine(s, kind, rnd) {
    const base = s.lines.system && s.lines.system[kind]
    if (typeof base !== "string" || base === "") return ""
    const more = s.lines.systemVariants && s.lines.systemVariants[kind]
    const all = [base]
    if (Array.isArray(more)) {
        for (let i = 0; i < more.length; i++) if (typeof more[i] === "string" && more[i] !== "") all.push(more[i])
    }
    if (typeof rnd !== "function" || all.length < 2) return all[0]
    if (!s.recentSys) s.recentSys = {}
    const prev = s.recentSys[kind]
    const fresh = prev ? all.filter(t => t !== prev) : all
    const pool = fresh.length ? fresh : all
    const tpl = pool[Math.min(pool.length - 1, Math.floor(rnd() * pool.length))]
    s.recentSys[kind] = tpl
    return tpl
}

// Текст по виду и обстоятельствам: подставляет {percent} и {time}. rnd выбирает вариант.
function compose(s, kind, ctx, rnd) {
    const tpl = chooseLine(s, kind, rnd)
    if (tpl === "") return ""
    const c = ctx || {}
    return tpl.replace("{percent}", String(Math.round(Number(c.percent))))
              .replace("{time}", nightPhrase(s.lines, c.hour))
}

// Повод устарел, если обстоятельства изменились, пока он ждал очереди.
function stale(s, e) {
    if (e.kind === "musicStart") return s.musicPlaying === false
    if (e.kind === "musicStop") return s.musicPlaying === true
    if (e.kind === "hoverStill") return s.pointerInside === false
    if (e.kind === "offline") return s.net.cur === "online"
    if (e.kind === "battery") return !!(s.bat.info && s.bat.info.charging)
    return false
}

// Шаг времени. env: { enabled, active, quiet, hour, dayKey, userIdle, cpu, cloud }.
//   cloud: "free" — облако свободно; "replaceable" — показано приветствие или «покойная» реплика;
//   "busy" — занято (или пауза после облака).
// Возвращает { kind, text, priority } — показать сейчас, или null.
function tick(s, dt, env) {
    env = env || {}
    const step = Math.max(0, Math.min(1, Number(dt) || 0))
    s.time += step
    setOn(s, env.enabled !== false && env.active !== false)
    if (!s.on) return null
    s.cpu.acc += step
    while (s.cpu.acc >= 1) { s.cpu.acc -= 1; sampleCpu(s, env.cpu) }
    evalNetwork(s, step)
    evalBattery(s)
    if (inNight(s, env.hour) && env.dayKey && s.nightKey !== env.dayKey && !env.userIdle && !s.away
            && !queued(s, "night"))
        offer(s, "night", { hour: env.hour, dayKey: env.dayKey })

    s.queue = s.queue.filter(e => s.time - e.at <= info(s, e.kind).expire && !cooling(s, e.kind) && !stale(s, e))
    if (s.queue.length === 0) return null
    for (let i = 0; i < s.queue.length; i++) {
        const e = s.queue[i]
        const interactive = info(s, e.kind).interaction === true
        const cloud = (interactive ? env.interactionCloud : env.cloud) || env.cloud || "free"
        const critical = e.priority >= 4
        const urgent = e.priority >= 3
        if (!critical && ((env.quiet && !(e.kind === "hoverStill" && !env.petting)) || env.optionalQuiet || s.time < (s.data.startupQuiet || 0))) continue
        if (cloud === "busy" && !critical || env.criticalVisible) continue
        if (cloud === "replaceable" && !urgent) continue
        if (!critical && s.time - s.lastAny < (interactive ? (s.data.interactionGap || 15) : urgent ? s.data.urgentGap : s.data.globalGap)) continue
        s.queue.splice(i, 1)
        s.last[e.kind] = s.time
        s.lastAny = s.time
        if (e.kind === "night") s.nightKey = e.ctx.dayKey
        const text = compose(s, e.kind, e.ctx, env.rnd)
        if (text === "") return null
        return { kind: e.kind, text: text, priority: e.priority }
    }
    return null
}

// Вид реплики из набора и подходящий текст вручную (проверка без реальных событий). Кулдауны и очередь
// не трогает. value: заряд для battery, час 0–5 для night; без значения — 15 % и текущий час в ночное
// время (иначе три часа ночи). Возвращает текст или "" для неизвестного вида.
function preview(s, kind, value, hour, rnd) {
    if (!s.lines.system || typeof s.lines.system[kind] !== "string") return ""
    const v = Number(value)
    const ctx = {}
    if (kind === "battery") ctx.percent = value !== undefined && value !== "" && isFinite(v) ? Math.max(0, Math.min(100, v)) : 15
    if (kind === "night") ctx.hour = value !== undefined && value !== "" && isFinite(v) ? v : (inNight(s, hour) ? hour : 3)
    return compose(s, kind, ctx, rnd)
}

// Все виды реплик (для справки и IPC).
function kinds(s) { return Object.keys(s.lines.system || {}) }
