// Чистая логика реплик Naomi: когда говорить, что именно и как долго держать облако.
// Время приходит шагом dt, случайность — функцией rnd (0..1): всё детерминированно проверяется node.
//
// Правила, чтобы Naomi не мешала:
//   * автоматическая реплика не перебивает показанную, кроме реплик поглаживания,
//     которые заменяют приветствие и «покойную» реплику;
//   * у каждого вида реплик свой минимальный интервал, а после любой реплики — пауза;
//   * «покойные» реплики редки (несколько минут) и не звучат во время поглаживания;
//   * одну и ту же реплику подряд не повторяем;
//   * say(text) из кода показывает облако всегда и перебивает любое другое.

// Минимальный интервал между репликами одного вида, секунды.
const MIN_INTERVAL = { greeting: 600, idle: 240, petStart: 8, petAgain: 8, petLong: 25, petEnd: 20 }
// Пауза после исчезновения любой автоматической реплики, секунды.
const GAP = 2
// Следующая «покойная» реплика — через столько секунд после предыдущей реплики, случайно в этом диапазоне.
const IDLE_MIN = 300
const IDLE_MAX = 600
// Новое поглаживание в течение этого времени после начала предыдущего — «снова».
const AGAIN_WITHIN = 90
// Конец поглаживания комментируется, только если оно длилось не меньше стольких секунд.
const END_MIN_PET = 3
// Реплики, которые могут заменить уже показанную.
const PET_KINDS = ["petStart", "petAgain", "petLong", "petEnd"]

function create(lines, rnd) {
    const r = rnd || Math.random
    return { lines: lines || {}, time: 0, text: "", until: -1e9, shownAt: -1e9, kind: "",
        last: {}, recent: {}, lastPetStart: -1e9,
        nextIdle: IDLE_MIN + r() * (IDLE_MAX - IDLE_MIN) }
}

// Сколько секунд держать облако с этим текстом.
function holdFor(text) {
    const n = String(text || "").length
    return Math.max(4, Math.min(9, 3.2 + 0.055 * n))
}

function visible(s) { return s.time < s.until }

function daypart(hour) {
    const h = Number(hour)
    if (!isFinite(h)) return "any"
    if (h >= 5 && h < 11) return "morning"
    if (h >= 11 && h < 17) return "day"
    if (h >= 17 && h < 23) return "evening"
    return "night"
}

function pool(s, kind, hour) {
    const set = s.lines[kind]
    if (!set) return []
    if (Array.isArray(set)) return set
    const part = set[daypart(hour)]
    if (part && part.length) return part
    return set.any || []
}

// Выбор реплики без повтора двух последних того же вида.
function pick(s, kind, rnd, hour) {
    const all = pool(s, kind, hour)
    if (all.length === 0) return null
    const key = kind + ":" + daypart(hour)
    const recent = s.recent[key] || []
    let fresh = all.filter(t => recent.indexOf(t) < 0)
    if (fresh.length === 0) fresh = all
    const text = fresh[Math.min(fresh.length - 1, Math.floor((rnd || Math.random)() * fresh.length))]
    s.recent[key] = recent.concat([text]).slice(-Math.min(2, all.length - 1 || 1))
    return text
}

function show(s, text, kind, hold, rnd) {
    s.text = text
    s.kind = kind
    s.shownAt = s.time
    s.until = s.time + (hold > 0 ? hold : holdFor(text))
    s.last[kind] = s.time
    // Любая реплика отодвигает следующую «покойную».
    s.nextIdle = s.until + IDLE_MIN + (rnd || Math.random)() * (IDLE_MAX - IDLE_MIN)
}

// Показать произвольный текст из кода. Возвращает показанный текст или "".
function say(s, text, hold, rnd) {
    const t = String(text === undefined || text === null ? "" : text).trim()
    if (t === "") return ""
    show(s, t, "say", hold, rnd)
    return t
}

// Спрятать облако сразу.
function hide(s) { s.until = Math.min(s.until, s.time) }

// Событие-повод для реплики. ctx: { hour, duration }. Возвращает показанный текст или null.
function react(s, kind, rnd, ctx) {
    ctx = ctx || {}
    let k = kind
    if (kind === "petStart") {
        const again = s.time - s.lastPetStart < AGAIN_WITHIN
        s.lastPetStart = s.time
        if (again) k = "petAgain"
    }
    if (kind === "petEnd" && !(ctx.duration >= END_MIN_PET)) return null
    const isPet = PET_KINDS.indexOf(k) >= 0
    if (visible(s)) {
        // Автоматическая реплика перебивает только приветствие и «покойную» реплику.
        const replaceable = s.kind === "greeting" || s.kind === "idle"
        if (!(isPet && replaceable)) return null
    } else if (s.time < s.until + GAP) {
        return null
    }
    const since = s.time - (s.last[k] === undefined ? -1e9 : s.last[k])
    if (since < (MIN_INTERVAL[k] || 0)) return null
    const text = pick(s, k, rnd, ctx.hour)
    if (text === null) return null
    show(s, text, k, 0, rnd)
    return text
}

// Шаг времени. ctx: { active, quiet, hour }. quiet=true — не говорить сам (гладят, курсор на голове).
// Возвращает текст «покойной» реплики, если пора, иначе null.
function tick(s, dt, rnd, ctx) {
    ctx = ctx || {}
    s.time += Math.max(0, Math.min(1, Number(dt) || 0))
    if (ctx.active === false || ctx.quiet) {
        // Пока нельзя говорить, реплика откладывается минимум на 30 с вперёд: после паузы она не прилетит сразу.
        s.nextIdle = Math.max(s.nextIdle, s.time + 30)
        return null
    }
    if (s.time >= s.nextIdle && !visible(s)) {
        const text = react(s, "idle", rnd, ctx)
        if (text === null) s.nextIdle = s.time + 60
        return text
    }
    return null
}
