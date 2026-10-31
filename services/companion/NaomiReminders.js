// Напоминания Naomi в том же облаке, что и реплики. Время идёт шагом dt, как у NaomiDialogue.js.
// Сроки считаются по времени присутствия; отсчёт отдыха идёт независимо.
// «позже» пропускает только этот раз: следующий срок уже стоит и не сдвигается.
// Глаза — 2 минуты, разминка — 3. Вода без длительности. Пока идёт отсчёт, новое облако не открываем.

const ORDER = ["water", "eyes", "move"]
const INTERVAL = { water: 60 * 60, eyes: 20 * 60, move: 60 * 60 }
const DURATION = { water: 0, eyes: 2 * 60, move: 3 * 60 }
const GAP = 45

function create(lines) {
    return {
        lines: lines || {}, t: 0, workTime: 0, intervals: Object.assign({}, INTERVAL),
        next: { water: INTERVAL.water, eyes: INTERVAL.eyes, move: INTERVAL.move },
        queue: [], phase: "idle", kind: "", line: "", remain: 0,
        ackUntil: 0, gapUntil: 0, halfSaid: false, recent: {}
    }
}

function holdFor(text) {
    const n = String(text || "").length
    return Math.max(3.5, Math.min(7, 2.8 + 0.05 * n))
}

function formatRemain(sec) {
    const left = Math.max(0, Math.ceil(Number(sec) - 1e-9))
    const m = Math.floor(left / 60)
    const r = left % 60
    return m + ":" + (r < 10 ? "0" : "") + r
}

function blocking(s) {
    return !!s && (s.phase === "prompt" || s.phase === "count" || s.phase === "ack")
}

function pickLine(s, kind, slot, rnd) {
    const set = s.lines.remind && s.lines.remind[kind]
    const all = set && set[slot]
    if (!Array.isArray(all) || all.length === 0) return ""
    const key = kind + ":" + slot
    const prev = s.recent[key]
    let fresh = prev ? all.filter(t => t !== prev) : all
    if (fresh.length === 0) fresh = all
    const r = typeof rnd === "function" ? rnd : Math.random
    const text = fresh[Math.min(fresh.length - 1, Math.floor(r() * fresh.length))]
    s.recent[key] = text
    return text
}

function beginAck(s, rnd, slot) {
    s.phase = "ack"
    s.remain = 0
    s.halfSaid = false
    const line = pickLine(s, s.kind, slot, rnd)
    if (line) s.line = line
    s.ackUntil = s.t + holdFor(s.line)
    return s.line
}

// Спрятать облако напоминания, не сдвигая расписание. Очередь ждёт паузу.
function dismiss(s) {
    if (!s) return
    s.phase = "idle"
    s.kind = ""
    s.line = ""
    s.remain = 0
    s.halfSaid = false
    s.gapUntil = s.t + GAP
}

function accepts(kind) {
    return ORDER.indexOf(kind) >= 0
}

// Сразу в очередь, без сдвига next. Показ — тот же tryShow, что у подошедшего срока.
// Занятое облако и идущий отсчёт не перебиваются: просьба остаётся в очереди.
function request(s, kind, env) {
    if (!s || !accepts(kind)) return ""
    if (s.queue.indexOf(kind) < 0) s.queue.push(kind)
    return tryShow(s, env || {})
}

function later(s) {
    if (!s || s.phase !== "prompt") return ""
    dismiss(s)
    return ""
}

function okay(s, rnd) {
    if (!s || s.phase !== "prompt") return ""
    const dur = DURATION[s.kind] || 0
    if (dur > 0) {
        s.phase = "count"
        s.remain = dur
        s.halfSaid = false
        const line = pickLine(s, s.kind, "count", rnd)
        if (line) s.line = line
        return s.line
    }
    return beginAck(s, rnd, "ack")
}

// When an interval changes, keep the accumulated active time in the current period.
function configure(s, minutes) {
    if (!s || !minutes) return
    ORDER.forEach(function(kind) {
        const v = Number(minutes[kind])
        if (!isFinite(v) || v < 5 || v > 180) return
        const next = Math.round(v) * 60
        const previous = s.intervals[kind]
        if (next === previous) return
        s.next[kind] = Math.max(s.workTime, s.next[kind] - previous + next)
        s.intervals[kind] = next
    })
}

function arm(s) {
    for (let i = 0; i < ORDER.length; i++) {
        const kind = ORDER[i]
        const step = s.intervals[kind]
        if (!(step > 0) || s.workTime + 1e-9 < s.next[kind]) continue
        const jumps = Math.floor((s.workTime - s.next[kind]) / step) + 1
        s.next[kind] += jumps * step
        if (s.queue.indexOf(kind) < 0) s.queue.push(kind)
    }
}

function tryShow(s, env) {
    if (s.phase !== "idle" || s.t < s.gapUntil) return ""
    if ((env.cloud || "free") !== "free" || s.queue.length === 0) return ""
    const kind = s.queue.shift()
    const line = pickLine(s, kind, "prompt", env.rnd)
    if (!line) return ""
    s.phase = "prompt"
    s.kind = kind
    s.line = line
    s.halfSaid = false
    return line
}

// Шаг. env: { active, cloud, rnd }. cloud "free" — можно открыть новое облако.
// Пока идёт отсчёт или реплика, срок копится в очередь и не перебивает облако.
// Возвращает новую реплику, если она только что началась, иначе "".
function tick(s, dt, env) {
    env = env || {}
    if (!s || env.active === false) return ""
    const step = Math.max(0, Number(dt) || 0)
    s.t += step
    if (env.present !== false) s.workTime += step
    let spoken = ""
    if (s.phase === "count") {
        s.remain -= step
        const dur = DURATION[s.kind] || 0
        if (!s.halfSaid && s.remain <= dur / 2 && s.remain > 0) {
            s.halfSaid = true
            const next = pickLine(s, s.kind, "count", env.rnd)
            if (next && next !== s.line) { s.line = next; spoken = next }
        }
        if (s.remain <= 0) {
            s.remain = 0
            spoken = beginAck(s, env.rnd, "done") || spoken
        }
    } else if (s.phase === "ack" && s.t >= s.ackUntil) {
        s.phase = "idle"
        s.kind = ""
        s.line = ""
        s.gapUntil = s.t + GAP
    }
    if (env.present !== false) arm(s)
    const shown = env.present === false ? "" : tryShow(s, env)
    if (shown) spoken = shown
    return spoken
}

function view(s) {
    if (!s || s.phase === "idle" || !s.line) return null
    let text = s.line
    if (s.phase === "count") text = s.line + "\n" + formatRemain(s.remain)
    return { text: text, actions: s.phase === "prompt", phase: s.phase, kind: s.kind }
}
