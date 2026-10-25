// Чистая логика поглаживания Naomi. Без QML и без часов: время приходит шагом dt,
// поэтому её целиком проверяет node-тест (tests/naomi-companion.cjs).
//
// Жест: курсор над головой и волосами и движется. Каждый сдвиг внутри зоны головы
// копит «энергию» (путь в пикселях источника), она затухает по экспоненте.
// Поглаживание начинается выше порога ON и заканчивается ниже OFF (гистерезис),
// поэтому пауза в движении или дрожь руки не обрывают позу, а быстрый пролёт
// курсора через голову её не включает.
//
// Координаты — в системе сцены Naomi (864 × 1152, как у NaomiLayers.js).

// Зона головы и волос: эллипс по габаритам слоя head.png (329..546 × 65..305), без плеч.
const HEAD = { x: 333, y: 78, w: 208, h: 226 }
const HEAD_CENTER_X = HEAD.x + HEAD.w / 2
// Порог начала поглаживания, пиксели пути: примерно туда-сюда по всей голове.
const ON = 300
// Порог конца поглаживания. Меньше ON: пауза не обрывает позу.
const OFF = 110
// Постоянная затухания энергии, секунды. Медленный сдвиг со скоростью < ON/TAU не накопит порог.
const TAU = 1.1
// Вне головы энергия гаснет быстрее.
const TAU_AWAY = 0.3
// Скачок больше этого (вход в окно, телепорт курсора) не считается движением.
const JUMP = 260
// Один отсчёт вкладывает не больше этого: редкие отсчёты не дают «пролёт» за поглаживание.
const STEP_CAP = 90
// Дрожь мыши меньше этого не считается.
const MIN_STEP = 1.2
// Через сколько секунд непрерывного поглаживания даётся «долгое» событие.
const LONG_AFTER = 6

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)) }
function follow(a, b, dt, tau) { return b + (a - b) * Math.exp(-dt / tau) }

// Копия зоны головы для QML: по ней иллюстрация считает область наведения и маску окна.
function zone() { return { x: HEAD.x, y: HEAD.y, w: HEAD.w, h: HEAD.h } }

function inHead(x, y) {
    const nx = (x - (HEAD.x + HEAD.w / 2)) / (HEAD.w / 2)
    const ny = (y - (HEAD.y + HEAD.h / 2)) / (HEAD.h / 2)
    return nx * nx + ny * ny <= 1
}

function create() {
    return { x: 0, y: 0, has: false, inside: false, energy: 0, petting: false, petTime: 0, longFired: false,
        pet: 0, lean: 0, intensity: 0 }
}

// Курсор сдвинулся в точку (x, y) сцены. Вызывать на каждое событие мыши внутри компонента.
function move(s, x, y) {
    x = Number(x) || 0; y = Number(y) || 0
    const inside = inHead(x, y)
    if (s.has && s.inside && inside) {
        const d = Math.hypot(x - s.x, y - s.y)
        if (d >= MIN_STEP && d <= JUMP) s.energy += Math.min(d, STEP_CAP)
    }
    s.x = x; s.y = y; s.has = true; s.inside = inside
}

// Курсор ушёл из компонента.
function leave(s) { s.has = false; s.inside = false }

// Шаг времени. input: { enabled, reduced }. Возвращает позу и события этого шага.
function step(s, input, dt) {
    dt = clamp(dt, 0, 1)
    const out = { started: false, ended: false, long: false, duration: 0 }
    if (!input.enabled) {
        // Реакция выключена: сразу гасим позу, событие конца отдаём один раз.
        if (s.petting) { out.ended = true; out.duration = s.petTime }
        s.energy = 0; s.petting = false; s.petTime = 0; s.longFired = false; s.has = false; s.inside = false
        s.pet = 0; s.lean = 0; s.intensity = 0
        return finish(s, out)
    }
    s.energy = follow(s.energy, 0, dt, s.inside ? TAU : TAU_AWAY)
    if (!s.petting && s.energy >= ON) {
        s.petting = true; s.petTime = 0; s.longFired = false; out.started = true
    } else if (s.petting && s.energy < OFF) {
        s.petting = false; out.ended = true; out.duration = s.petTime; s.petTime = 0; s.longFired = false
    }
    if (s.petting) {
        s.petTime += dt
        if (!s.longFired && s.petTime >= LONG_AFTER) { s.longFired = true; out.long = true }
    }
    s.intensity = s.petting ? clamp(0.6 + 0.4 * (s.energy - OFF) / (ON * 1.6), 0.6, 1) : 0
    const target = s.petting ? s.intensity : 0
    if (input.reduced) {
        s.pet = target
    } else {
        // Поза входит быстрее, чем выходит: возвращение в обычный вид плавное.
        s.pet = follow(s.pet, target, dt, target > s.pet ? 0.22 : 0.6)
        if (Math.abs(s.pet - target) < 0.002) s.pet = target
    }
    // Рука справа от центра головы — наклон вправо; сглаживается, чтобы голова шла за рукой.
    // После конца жеста наклон держится, пока поза плавно возвращается, и обнуляется в самом конце.
    let leanTarget = s.lean
    if (s.petting && s.inside) leanTarget = clamp((s.x - HEAD_CENTER_X) / (HEAD.w / 2), -1, 1)
    else if (s.pet < 0.01) leanTarget = 0
    s.lean = input.reduced ? leanTarget : follow(s.lean, leanTarget, dt, 0.25)
    return finish(s, out)
}

function finish(s, out) {
    out.pet = s.pet
    out.petting = s.petting
    out.lean = s.lean
    out.intensity = s.intensity
    out.energy = s.energy
    out.petTime = s.petTime
    return out
}
