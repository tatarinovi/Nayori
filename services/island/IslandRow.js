// Чистая раскладка свёрнутой строки острова: что показывается в центре («main»)
// и какие блоки стоят справа («хвост»). QML только рисует результат.
//
// Приоритеты центра (выше — главнее):
//   1. volume        — короткая вспышка громкости, прямой отклик на колесо или среднюю кнопку;
//   2. notification  — закреплённое уведомление, пока не открыта страница «Уведомления»;
//   3. lyrics        — строка синхронного текста песни;
//   4. music         — название трека рядом с лисой;
//   5. rest          — часы, лиса, дата или погода.
// Внутри строки справа — только «+» и до трёх значков уведомлений.
// clock и controls — признаки отдельных мини-островов слева и справа;
// они не участвуют в ширине и разделителях основного острова.
const MAX_ICONS = 3
// Остров не шире этого значения: раскрытый — 680, окно — 712.
const MAX_WIDTH = 640
// Центру нужно не меньше: сообщение, громкость и текст песни.
const MIN_MAIN = 336

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)) }

// input: { yielded, volume, notification, lyrics, title, controls, pending }
function plan(input) {
    const hidden = !!input.yielded
    const base = input.notification ? "notification" : input.lyrics ? "lyrics" : input.title ? "music" : "rest"
    return {
        hidden: hidden,
        base: base,
        main: input.volume ? "volume" : base,
        // Часы уходят вправо вместе с центром, который их вытеснил. Вспышка громкости
        // на секунду закрывает всё, но часы ради неё не перескакивают.
        clock: !hidden && (base === "notification" || base === "lyrics"),
        icons: hidden ? 0 : clamp(Math.floor(input.pending), 0, MAX_ICONS),
        controls: !hidden && !!input.controls
    }
}

// metrics: { pad, right, plus, icon, iconGap, clock, controls }
function iconsWidth(n, m) { return n > 0 ? m.plus + n * (m.icon + m.iconGap) : 0 }

function tail(p, m) {
    const parts = []
    if (p.icons > 0) parts.push({ name: "icons", width: iconsWidth(p.icons, m) })
    const out = { width: 0, x: {}, dividers: [], parts: parts.map(function(q) { return q.name }) }
    if (!parts.length) return out
    let x = 0
    parts.forEach(function(q) {
        out.dividers.push(x)
        x += 1 + m.pad
        out.x[q.name] = x
        x += q.width + m.pad
    })
    out.width = x - m.pad + m.right
    return out
}

// Ширина острова: центр, обычно 352–448, уступает место хвосту, чтобы всё влезло в MAX_WIDTH.
function size(mainBase, tailWidth, minimum) {
    const main = Math.max(minimum === undefined ? MIN_MAIN : minimum, Math.min(mainBase, MAX_WIDTH - tailWidth))
    return { main: main, total: main + tailWidth }
}

// Кнопки музыки остаются на экране ещё holdSeconds после паузы, чтобы нажать «Воспроизвести».
// state: { player (играет сейчас), held (последний играющий), pausedFor (с), alive (held всё ещё выбран) }
function controlsVisible(state, holdSeconds) {
    if (state.player) return true
    return !!state.held && !!state.alive && state.pausedFor < holdSeconds
}
