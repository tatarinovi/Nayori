// Long-session scheduling, text contracts, and reminders without a compositor.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict')
function mod(file) { const c = {}; vm.runInNewContext(fs.readFileSync(`services/companion/${file}.js`, 'utf8').replace(/^\.pragma library\n/, ''), c); return c }
const L = mod('NaomiLines').lines, D = mod('NaomiDialogue'), E = mod('NaomiSystemEvents'), R = mod('NaomiReminders'), S = mod('NaomiSession'), cfg = mod('NaomiSystemData').data
const texts = []
function collect(value, path = '') {
    if (typeof value === 'string') {
        assert(value.trim() === value && value.length > 0 && value.length <= 100, path)
        const tokens = value.match(/\{[^}]*\}/g) || []
        const expected = path.startsWith('system.battery') || path.startsWith('systemVariants.battery') ? ['{percent}'] : path.startsWith('system.night') || path.startsWith('systemVariants.night') ? ['{time}'] : []
        assert.deepEqual(tokens, expected, path)
        texts.push(value)
    } else {
        assert(value && Object.keys(value).length > 0, path)
        for (const [k,v] of Object.entries(value)) collect(v, path ? `${path}.${k}` : k)
    }
}
for (const [k,v] of Object.entries(L)) if (k !== 'nightTimes') collect(v,k)
assert.equal(new Set(texts).size, texts.length, 'no duplicate lines across categories')
assert.equal(texts.length, 228)
for (const pool of Object.values(L.greeting)) assert(pool.length >= 5)
assert(L.idle.length >= 35 && L.idle.length <= 45)
for (const k of ['petStart','petAgain','petLong','petEnd']) assert(L[k].length >= 8)
assert.deepEqual(Object.keys(L.system).sort(), Object.keys(cfg.kinds).sort(), 'all events handled')

// 12-hour continuous activity: every rolling hour has at most 2 idle messages.
for (const random of [() => 0.5, () => 0.999, () => 0]) {
    const s = D.create(L,random), times = []
    for (let t=0;t<12*3600;t++) if (D.tick(s,1,random,{active:true,hour:14})) times.push(s.time)
    for (const at of times) assert(times.filter(t => t > at-3600 && t <= at).length <= 2)
    if (random() === 0) assert.equal(times.length,0,'silent attempts can remain silent')
}
const s = D.create(L,() => 0.5)
s.time = 7199; s.last.greeting = 0
assert.equal(D.react(s,'greeting',()=>0.5,{hour:14}),null)
s.time = 7200; assert(D.react(s,'greeting',()=>0.5,{hour:14}))
assert(S.canGreet(10000)); S.greeted(10000); assert(!S.canGreet(10000+7199999)); assert(S.canGreet(10000+7200000))

// A busy cloud or game suppresses optional events; critical battery still gets through.
const env = {active:true, enabled:true, cloud:'busy', quiet:true, optionalQuiet:true, hour:14, cpu:0}
let e = E.create(cfg,L); E.offer(e,'terminal',{}); assert.equal(E.tick(e,1,env),null)
E.battery(e,{present:true,percent:5,charging:false})
let due = E.tick(e,1,env); assert(due && due.kind === 'battery' && due.priority === 4)
e = E.create(cfg,L); e.time = 100; e.pointerInside = true; E.offer(e,'hoverStill',{})
due = E.tick(e,1,{...env,cloud:'free',optionalQuiet:false,petting:false}); assert(due && due.kind==='hoverStill')
e = E.create(cfg,L); e.time=100; e.pointerInside=false; E.offer(e,'hoverStill',{}); assert.equal(E.tick(e,1,{hour:14}),null)

// Reminder stages, active-time intervals, dismiss/queue gaps and no inferred completion.
let r = R.create(L)
assert.equal(r.next.water,3600); assert.equal(r.next.eyes,1200); assert.equal(r.next.move,3600)
assert.equal(R.tick(r,1199,{cloud:'free'}),''); assert(R.tick(r,1,{cloud:'free'})); assert.equal(r.kind,'eyes')
R.later(r); R.tick(r,45,{cloud:'free'}); R.request(r,'water',{cloud:'free'}); assert.equal(r.kind,'water')
assert(R.okay(r,()=>0)); assert.equal(r.phase,'ack'); R.tick(r,10,{cloud:'free'})
R.request(r,'eyes',{cloud:'busy'}); assert.equal(r.queue[0],'eyes')
assert.equal(R.tick(r,44,{cloud:'free'}),''); assert(R.tick(r,1,{cloud:'free'})); R.okay(r,()=>0)
assert.equal(r.remain,120); R.tick(r,60,{cloud:'free'}); assert.equal(r.phase,'count')
R.tick(r,60,{cloud:'free'}); assert.equal(r.phase,'ack'); assert(L.remind.eyes.done.includes(r.line))
r=R.create(L); R.request(r,'move',{cloud:'free'}); R.okay(r,()=>0); assert.equal(r.remain,180)
R.tick(r,90,{cloud:'free'}); assert.equal(r.phase,'count'); R.tick(r,90,{cloud:'free'}); assert.equal(r.phase,'ack')
console.log('NAOMI_PERSONALITY_PASS: 228 lines, 12h simulations, priorities, reminder lifecycle')

// Playback after a recent system line survives the ordinary 3-minute gap.
e = E.create(cfg,L); e.time = 100; e.lastAny = 95; e.musicPlaying = true
E.offer(e,'musicStart',{})
assert.equal(E.tick(e,1,{hour:14,cloud:'busy',interactionCloud:'free'}),null, '15-second interaction gap')
e.time = 110
due = E.tick(e,1,{hour:14,cloud:'busy',interactionCloud:'free'})
assert(due && due.kind === 'musicStart', 'music uses the interaction slot, not the 180-second system gap')
e.musicPlaying = false; E.offer(e,'musicStop',{})
for(let i=0;i<20;i++) due = E.tick(e,1,{hour:14,cloud:'busy',interactionCloud:'busy'})
assert.equal(due,null,'active cloud is never interrupted by music')
due = E.tick(e,1,{hour:14,cloud:'busy',interactionCloud:'free'})
assert(due && due.kind === 'musicStop','stop survives until the cloud clears')
