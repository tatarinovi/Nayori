const fs = require('fs'), vm = require('vm'), assert = require('assert')
function moduleAt(file) { const c = {}; vm.createContext(c); vm.runInContext(fs.readFileSync(file, 'utf8'), c); return c }
const b = moduleAt('services/island/Behavior.js'), q = moduleAt('services/island/NotificationQueue.js')
let s = b.create(), i = { cpu: 1, visible: true }
b.step(s, i, 1); assert(Math.abs(s.cpu - (1 - Math.exp(-1))) < 1e-9)
s = b.create(); for (let n=0;n<100;n++) b.step(s,{cpu:0.05},0.1); assert.equal(s.tail,0)
let o = b.step(s,{playing:true,audioAvailable:true,energy:1,beat:1,hover:true,x:1,y:-1,unread:true},0.03)
assert(o.head>0 && o.x>0 && o.y<0 && o.marker)
o=b.step(s,{reducedMotion:true,unread:true},0.1); assert.equal(o.tail,0); assert(o.marker)
s=q.create(); [1,2,3].forEach(id=>q.receive(s,{id})); q.tick(s,0,false); assert.equal(s.current,1)
q.tick(s,5,false); q.tick(s,0,false); assert.equal(s.current,2)
q.tick(s,2,true); assert.equal(s.elapsed,0)
q.page(s,true); assert.equal(s.current,null); q.page(s,false); q.tick(s,10,false); assert.equal(s.current,null)
q.receive(s,{id:1,summary:'updated'}); q.tick(s,0,false); assert.equal(s.current,null)
q.receive(s,{id:4}); q.close(s,4,false); assert(s.records[0].closed); q.tick(s,0,false); assert.equal(s.current,null)
q.receive(s,{id:5}); q.close(s,5,true); assert(s.records[0].deleted)
s=q.create(); [1,2,3].forEach(id=>q.receive(s,{id})); q.tick(s,15,false); assert(s.records.every(r=>r.shown)); assert(s.records.every(r=>!r.read))
console.log('ISLAND_CONTROLLERS_PASS')
// Smoothing is independent of frame count and channel priorities are local.
for (const load of [0, 0.05, 0.06, 0.5, 1]) {
    const state = b.create(); let movement = 0
    for (let n=0;n<600;n++) movement += Math.abs(b.step(state,{cpu:load},1/30).tail)
    assert.equal(movement > 0, load > 0.05)
}
const one=b.create(), many=b.create()
b.step(one,{cpu:1,playing:true,audioAvailable:true,energy:1},0.3)
for(let n=0;n<30;n++) b.step(many,{cpu:1,playing:true,audioAvailable:true,energy:1},0.01)
assert(Math.abs(one.cpu-many.cpu)<1e-9 && Math.abs(one.energy-many.energy)<1e-9)
s=b.create(); b.step(s,{playing:true,audioAvailable:true,beat:1},0.01)
const peak=b.step(s,{playing:true,audioAvailable:true},0.02).head
for(let n=0;n<100;n++) o=b.step(s,{playing:true,audioAvailable:true},0.03)
assert(o.head < peak/10)
const time=s.time; b.step(s,{visible:false},0.5); assert.equal(s.time,time)
s=q.create(); q.page(s,true); q.receive(s,{id:1}); assert(s.records[0].read); q.page(s,false); q.tick(s,5,false); assert.equal(s.current,null)
s=q.create(); [1,2,3].forEach(id=>q.receive(s,{id})); q.tick(s,2,false); q.tick(s,20,true); assert.equal(s.elapsed,2)
q.close(s,1,false); q.tick(s,0,false); assert.equal(s.current,2)
q.receive(s,{id:2,summary:'replacement'}); assert.equal(s.records.length,3); assert.equal(s.current,2)
q.close(s,2,true); q.receive(s,{id:2,summary:'do not resurrect'}); q.tick(s,0,false); assert.equal(s.current,3)
console.log('ISLAND_EDGE_CASES_PASS')
// The single tail still waves only with activity and is still in reduced motion or when hidden.
{
    const st=b.create(); let max=0, o
    for(let n=0;n<300;n++){ o=b.step(st,{cpu:1,visible:true},1/30); max=Math.max(max,Math.abs(o.tail)) }
    assert(max>1 && max<=4.01)
    const calm=b.create(); for(let n=0;n<100;n++) o=b.step(calm,{cpu:0.05,visible:true},0.1)
    assert.equal(o.tail,0)
    o=b.step(st,{reducedMotion:true,unread:true},0.1); assert.equal(o.tail,0); assert.equal(o.breath,0); assert(o.marker)
    o=b.step(st,{visible:false},0.1); assert.equal(o.tail,0)
    assert(!('tailB' in o) && !('tailC' in o))
    assert('breath' in o && 'tail' in o && 'head' in o && 'x' in o && 'y' in o && 'marker' in o)
}
console.log('ISLAND_FOX_TAIL_PASS')
// Lying only without activity: stand at once, lie after REST_DELAY of continuous calm.
{
    const music = { playing: true, audioAvailable: true, energy: 0.5, visible: true }, calm = { visible: true }
    const run = (st, input, seconds, dt = 0.1) => { let o; for (let n = 0; n < Math.round(seconds / dt); n++) o = b.step(st, input, dt); return o }
    let st = b.create(), o = b.step(st, calm, 0.1)
    assert.equal(o.rest, 1); assert.equal(o.walk, 0)                       // starts lying
    o = b.step(st, music, 0.1)
    assert(o.rest < 1, 'activity starts the rise immediately')
    o = run(st, music, 0.6); assert.equal(o.rest, 0)                        // transition ~0.45 s, then on paws
    o = run(st, music, 1); assert(o.walk > 0.9)
    let mid = b.create(); b.step(mid, music, 0.1); o = b.step(mid, music, 0.2); assert(o.rest > 0 && o.rest < 1, 'transition is continuous')
    // Short drop (< 5 s) never lies; new activity resets the timer.
    o = run(st, calm, 4.9); assert.equal(o.rest, 0); assert(st.idle < 5)
    o = run(st, music, 0.1); assert.equal(st.idle, 0)
    o = run(st, calm, 4.9); assert.equal(o.rest, 0)
    // Long drop (>= 5 s) lies down, smoothly.
    o = run(st, calm, 0.1); assert(st.idle >= 5 - 1e-6)
    o = run(st, calm, 0.2); assert(o.rest > 0 && o.rest < 1)
    o = run(st, calm, 0.6); assert.equal(o.rest, 1); assert(o.walk < 0.01)
    // Activity after lying stands again without delay.
    o = b.step(st, music, 0.1); assert(o.rest < 1)
    // Hover while active: stand still, calm tail, head follows pointer.
    st = b.create(); run(st, music, 2)
    o = run(st, Object.assign({ hover: true, x: 1, y: -1 }, music), 2)
    assert.equal(o.rest, 0); assert(o.walk < 0.01); assert(o.x > 0.9 && o.y < -0.9)
    let tailMax = 0; for (let n = 0; n < 100; n++) tailMax = Math.max(tailMax, Math.abs(b.step(st, Object.assign({ hover: true }, music), 0.03).tail))
    assert(tailMax > 0.5 && tailMax <= 2.3)
    // CPU activity uses the same threshold and the same timers.
    st = b.create(); o = run(st, { cpu: 0.5, visible: true }, 3); assert.equal(o.rest, 0); assert(o.walk > 0.9)
    o = run(st, { cpu: 0, visible: true }, 2); assert.equal(o.rest, 0)      // smoothed CPU still decays, grace period holds
    o = run(st, { cpu: 0, visible: true }, 8); assert.equal(o.rest, 1)
    // A load hovering around the threshold must not flicker the fox.
    st = b.create(); run(st, { cpu: 0.5, visible: true }, 2); let lay = 0, prev = 0
    for (let n = 0; n < 600; n++) { o = b.step(st, { cpu: n % 20 < 10 ? 0.5 : 0, visible: true }, 0.1); if (o.rest > 0) lay++ }
    assert.equal(lay, 0)
    // Reduced motion and hidden island are always the static lying pose; marker survives.
    st = b.create(); run(st, music, 2)
    for (const off of [{ reducedMotion: true }, { visible: false }]) {
        o = b.step(st, Object.assign({ unread: true }, music, off), 0.1)
        assert.equal(o.rest, 1); assert.equal(o.walk, 0); assert.equal(o.stride, 0); assert.equal(o.tail, 0); assert(o.marker)
    }
    o = b.step(st, music, 0.1); assert(o.rest < 1)
}
console.log('ISLAND_FOX_ACTIVITY_PASS')
// Expanded island: the head follows the cursor anywhere; collapsed it does not.
{
    const calm = { cpu: 0, visible: true }, music = { playing: true, audioAvailable: true, energy: 0.3, visible: true }
    const run = (st, input, t) => { let o; for (let n = 0; n < Math.round(t / 0.05); n++) o = b.step(st, input, 0.05); return o }
    // Normalisation: direction kept, magnitude clamped to the unit square.
    let v = b.lookVector(30, 0); assert(v.x > 0.4 && v.x < 0.6 && v.y === 0)
    v = b.lookVector(5000, -2500); assert.equal(v.x, 1); assert(Math.abs(v.y + 0.5) < 1e-9)
    v = b.lookVector(0, 0); assert.equal(v.x, 0); assert.equal(v.y, 0)
    // Expanded, cursor far from the fox (not hovering it): head turns, even lying.
    let st = b.create(), o = run(st, calm, 1)
    assert.equal(o.rest, 1); assert.equal(o.x, 0)
    o = run(st, Object.assign({ look: true, lookX: -400, lookY: 300 }, calm), 2)
    assert.equal(o.rest, 1, 'lying fox keeps lying'); assert(o.x < -0.95 && Math.abs(o.y - 0.75) < 0.05, 'far cursor is clamped, direction kept')
    assert(o.x >= -1 && o.y <= 1)
    // Collapsed (look false): same cursor offset does nothing.
    st = b.create(); o = run(st, Object.assign({ look: false, lookX: -400, lookY: 300 }, calm), 2)
    assert.equal(o.x, 0); assert.equal(o.y, 0)
    // Walking continues (look does not stand the fox or stop its stride).
    st = b.create(); run(st, music, 2)
    o = run(st, Object.assign({ look: true, lookX: 200, lookY: -10 }, music), 2)
    assert.equal(o.rest, 0); assert(o.walk > 0.9); assert(o.x > 0.95)
    // Hover over the fox still wins and still stops the walk.
    o = run(st, Object.assign({ hover: true, x: -1, y: 0, look: true, lookX: 200, lookY: 0 }, music), 2)
    assert(o.walk < 0.01); assert(o.x < -0.95)
    // Cursor lost: the head returns smoothly, with no jump between ticks.
    st = b.create(); run(st, Object.assign({ look: true, lookX: 300, lookY: 0 }, calm), 2)
    let last = b.step(st, calm, 0.033).x, maxJump = 0, mono = true
    assert(last > 0.7 && last < 1)
    for (let n = 0; n < 120; n++) { const x = b.step(st, calm, 0.033).x; maxJump = Math.max(maxJump, Math.abs(x - last)); if (x > last + 1e-12) mono = false; last = x }
    assert(mono && maxJump < 0.25 && last < 0.01, 'smooth return to neutral')
    // A fast sweep of the cursor does not twitch: per-tick head step stays bounded.
    st = b.create(); run(st, calm, 1); last = 0; maxJump = 0
    for (let n = 0; n < 60; n++) { const x = b.step(st, Object.assign({ look: true, lookX: n % 2 ? 300 : -300, lookY: 0 }, calm), 0.016).x; maxJump = Math.max(maxJump, Math.abs(x - last)); last = x }
    assert(maxJump < 0.2, 'zig-zag cursor is smoothed')
    // Reduced motion and hidden island stay static even with a cursor.
    for (const off of [{ reducedMotion: true }, { visible: false }]) {
        st = b.create(); o = run(st, Object.assign({ look: true, lookX: 300, lookY: 300, unread: true }, calm, off), 1)
        assert.equal(o.x, 0); assert.equal(o.y, 0); assert.equal(o.rest, 1); assert(o.marker)
    }
}
console.log('ISLAND_FOX_LOOK_PASS')
// Pixel sprite: deterministic 52x30 frames; every pose channel reaches the pixels.
{
    const sprite = moduleAt('surfaces/island/FoxSprite.js')
    const base = { breath: 0.65, tail: 0, head: 0, x: 0, y: 0, marker: false, rest: 1, walk: 0, stride: 0 }
    const draw = o => sprite.render(Object.assign({}, base, o))
    const diff = (a, b, test = () => true) => { let n = 0; for (let i = 0; i < a.length; i++) if (a[i] !== b[i] && test(i % 52, Math.floor(i / 52))) n++; return n }
    const ink = f => f.filter(v => v).length
    const lying = draw({}), standing = draw({ rest: 0 })
    assert.equal(lying.length, 52 * 30); assert(lying.every(v => v >= 0 && v <= 7))
    assert.deepEqual(draw({}), lying)                                             // deterministic
    assert(ink(lying) > 300 && ink(standing) > 300)
    assert(diff(lying, standing) > 200, 'lying and standing differ')
    // The lying fox is lower than the standing one; both reach the floor row.
    const top = f => f.findIndex(v => v) / 52 | 0
    assert(top(lying) > top(standing), 'lying is lower')
    for (const f of [lying, standing]) assert(f.slice(29 * 52).some(v => v), 'touches the floor')
    // Continuous transition: halfway frames differ from both ends.
    const half = draw({ rest: 0.5 })
    assert(diff(half, lying) > 20 && diff(half, standing) > 20)
    // Steps: stride phases move the legs only when walking, and diagonal pairs alternate.
    const w0 = draw({ rest: 0, walk: 1, stride: 0 }), w1 = draw({ rest: 0, walk: 1, stride: Math.PI }), w2 = draw({ rest: 0, walk: 1, stride: Math.PI / 2 })
    assert(diff(w0, w1, (x, y) => y >= 21) > 15 && diff(w0, w2, (x, y) => y >= 21) > 10, 'legs step')
    assert.equal(diff(draw({ rest: 0, walk: 0, stride: 0 }), draw({ rest: 0, walk: 0, stride: 2 })), 0)
    assert.equal(diff(draw({ rest: 1, walk: 1, stride: 0 }), draw({ rest: 1, walk: 1, stride: 2 })), 0, 'lying fox does not step')
    // One tail: it waves with the tail channel and leaves the head and legs alone.
    const t1 = draw({ rest: 0, tail: 4 }), t2 = draw({ rest: 0, tail: -4 })
    assert(diff(t1, t2) > 10 && diff(t1, t2, x => x >= 20) === 0, 'tail channel moves only the tail')
    // The head follows the pointer; the lying fox too.
    assert(diff(draw({ rest: 0, x: 1, y: -1 }), standing) > 8)
    assert(diff(draw({ x: 1, y: -1 }), lying) > 8)
    assert(diff(draw({ rest: 0, head: 1 }), standing) > 8)
    // Breathing is a small change of the lying back only.
    assert(diff(draw({ breath: 1.3 }), draw({ breath: 0 })) > 0)
    // The unread marker corner (top right 5x5) stays free in every pose.
    for (const o of [{}, { rest: 0 }, { rest: 0, x: 1, y: -1, head: 1 }, { rest: 0, walk: 1, stride: 1, head: 1, x: 1 }, { x: 1, y: -1, head: 1 }])
        assert.equal(diff(draw(o), new Array(52 * 30).fill(0), (x, y) => x >= 47 && y < 5), 0, 'marker corner is free')
    // Static pose for reduced motion equals the plain lying frame (marker is separate).
    assert.deepEqual(draw({ rest: 1, walk: 0, stride: 0, tail: 0, head: 0, x: 0, y: 0, marker: true }), lying)
}
// No painted cell may be cut off by the 52x30 grid, nor touch the left edge (the tail
// has to keep a free column), in any pose at the extreme tail values.
{
    const sprite = moduleAt('surfaces/island/FoxSprite.js')
    const spriteApi = sprite
    let checked = 0
    for (const rest of [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1])
        for (const walk of [0, 1]) for (const tail of [-6, 0, 6]) for (const stride of [0, 1.6, 3.1, 4.7])
            for (const [x, y] of [[0, 0], [1, 1], [-1, -1], [1, -1], [-1, 1]]) {
                const m = spriteApi.measure({ rest, walk, tail, stride, breath: 1.3, x, y, head: 0.5 })
                const where = JSON.stringify({ rest, walk, tail, stride, x, y, m })
                assert(m.minX >= 1, 'left edge stays free: ' + where)
                assert(m.maxX <= spriteApi.W - 1 && m.minY >= 0 && m.maxY <= spriteApi.H - 1, 'nothing cut by the grid: ' + where)
                checked++
            }
    assert(checked > 1000)
}
console.log('ISLAND_FOX_BOUNDS_PASS')
console.log('ISLAND_FOX_SPRITE_PASS')
