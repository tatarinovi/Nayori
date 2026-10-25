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
