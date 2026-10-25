// Pure, time-based channels. Shared by the runtime and deterministic tests.
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)) }
function follow(a, b, dt, tau) { return b + (a - b) * Math.exp(-dt / tau) }
function create() { return { cpu: 0, energy: 0, phase: 0, time: 0, beatAge: 1, beatStrength: 0, x: 0, y: 0, tail: 0, head: 0 } }
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
    s.x = follow(s.x, input.hover ? clamp(input.x, -1, 1) : 0, dt, 0.1)
    s.y = follow(s.y, input.hover ? clamp(input.y, -1, 1) : 0, dt, 0.1)
    if (input.visible === false || input.reducedMotion) return { breath: 0, tail: 0, head: 0, x: 0, y: 0, marker: !!input.unread }
    s.time += dt
    const music = input.playing && input.audioAvailable
    const frequency = music ? 0.5 + s.energy * 2.5 : 0.5 + clamp((s.cpu - 0.05) / 0.95, 0, 1) * 2.5
    s.phase = (s.phase + dt * frequency * Math.PI * 2) % (Math.PI * 2)
    const amplitude = music ? s.energy * 4 + pulse * 2 : (s.cpu > 0.05 ? 4 : 0)
    s.tail = follow(s.tail, Math.sin(s.phase) * amplitude, dt, 0.08)
    s.head = follow(s.head, music ? s.energy * 0.5 + pulse : 0, dt, 0.08)
    return { breath: (1 - Math.cos(s.time * Math.PI / 1.6)) * 0.65, tail: s.tail, head: s.head, x: s.x, y: s.y, marker: !!input.unread }
}
