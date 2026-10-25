// Pure, time-based channels. Shared by the runtime and deterministic tests.
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)) }
function follow(a, b, dt, tau) { return b + (a - b) * Math.exp(-dt / tau) }
// Seconds without any activity (music or CPU above the threshold) before the
// fox lies down. Standing up is immediate; the delay only prevents flicker
// while the load hovers around the 5% threshold. Single source of truth.
const REST_DELAY = 5
// Duration of the lie-down / stand-up transition, seconds.
const RISE_TIME = 0.45
const CPU_ACTIVE = 0.05
function create() { return { cpu: 0, energy: 0, phase: 0, time: 0, beatAge: 1, beatStrength: 0, x: 0, y: 0, tail: 0, head: 0,
    idle: REST_DELAY, restT: 1, walk: 0 } }
function ease(v) { return v * v * (3 - 2 * v) }
// Distance in pixels from the fox centre at which the head is turned fully; farther
// cursors are clamped (direction kept), so a far pointer never breaks the pose.
const LOOK_RANGE = 60
function lookVector(dx, dy) {
    let x = (Number(dx) || 0) / LOOK_RANGE, y = (Number(dy) || 0) / LOOK_RANGE
    const m = Math.max(Math.abs(x), Math.abs(y))
    if (m > 1) { x /= m; y /= m }
    return { x: x, y: y }
}
function step(s, input, dt) {
    dt = clamp(dt, 0, 1)
    s.cpu = follow(s.cpu, clamp(input.cpu, 0, 1), dt, 1)
    const energy = input.playing && input.audioAvailable ? clamp(input.energy, 0, 1) : 0
    s.energy = follow(s.energy, energy, dt, energy > s.energy ? 0.08 : 0.25)
    if (input.beat > 0 && input.playing && input.audioAvailable) {
        s.beatAge = 0; s.beatStrength = clamp(input.beat, 0, 1)
    }
    s.beatAge += dt
    const pulse = s.beatStrength * (s.beatAge < 0.03 ? s.beatAge / 0.03 : Math.exp(-(s.beatAge - 0.03) / 0.22))
    // Pointer over the fox wins; otherwise, while the island is expanded (input.look),
    // the head follows the cursor anywhere in it. Losing the cursor eases back to 0.
    // Without hover the head is slower (also on the return) so quick sweeps do not twitch.
    const look = !input.hover && input.look ? lookVector(input.lookX, input.lookY) : null
    const tx = input.hover ? clamp(input.x, -1, 1) : look ? look.x : 0
    const ty = input.hover ? clamp(input.y, -1, 1) : look ? look.y : 0
    s.x = follow(s.x, tx, dt, input.hover ? 0.1 : 0.16)
    s.y = follow(s.y, ty, dt, input.hover ? 0.1 : 0.16)
    if (input.visible === false || input.reducedMotion) {
        // Static lying pose; the next activity stands the fox up from here.
        s.idle = REST_DELAY; s.restT = 1; s.walk = 0
        return { breath: 0, tail: 0, head: 0, x: 0, y: 0, marker: !!input.unread, rest: 1, walk: 0, stride: 0 }
    }
    s.time += dt
    const music = input.playing && input.audioAvailable
    const active = music || s.cpu > CPU_ACTIVE
    // Activity resets the idle timer at once; lying down needs REST_DELAY of continuous calm.
    s.idle = active ? 0 : Math.min(REST_DELAY, s.idle + dt)
    const lying = s.idle >= REST_DELAY - 1e-9
    s.restT = clamp(s.restT + (lying ? dt : -dt) / RISE_TIME, 0, 1)
    // Pointer over an active fox: stop walking and stand, tail sways calmly.
    const standing = active && !!input.hover
    s.walk = follow(s.walk, active && !input.hover ? 1 : 0, dt, 0.15)
    const frequency = standing ? 0.7 : music ? 0.5 + s.energy * 2.5 : 0.5 + clamp((s.cpu - 0.05) / 0.95, 0, 1) * 2.5
    s.phase = (s.phase + dt * frequency * Math.PI * 2) % (Math.PI * 2)
    const amplitude = standing ? 2.2 : music ? s.energy * 4 + pulse * 2 : (s.cpu > 0.05 ? 4 : 0)
    s.tail = follow(s.tail, Math.sin(s.phase) * amplitude, dt, 0.08)
    s.head = follow(s.head, music ? s.energy * 0.5 + pulse : 0, dt, 0.08)
    return { breath: (1 - Math.cos(s.time * Math.PI / 1.6)) * 0.65, tail: s.tail, head: s.head, x: s.x, y: s.y, marker: !!input.unread, rest: ease(s.restT), walk: s.walk, stride: s.phase }
}
