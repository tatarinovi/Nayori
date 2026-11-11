const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const c = require('../services/visualizer/VisualizerConfig.js');
const math = require('../surfaces/visualizer/vendor/lib/spectrum.js');
const aura = require('../surfaces/visualizer/vendor/lib/aura.js');
const params = {};
vm.runInNewContext(fs.readFileSync('services/visualizer/VisualizerParameters.js', 'utf8'), params);
assert.equal(c.choices.style.length, 13);
const config = c.normalize({future: 'kept', items: [{id:'same', style:'curtain', output:'DP-1', future:42}, {id:'same',style:'aura',auraEdges:[]}, null], fps:45});
assert.equal(config.future, 'kept');
assert.equal(config.items[0].future, 42);
assert.notEqual(config.items[0].id, config.items[1].id);
assert.deepEqual(config.items[1].auraEdges, []);
assert.equal(c.normalize({items:'broken',fps:NaN}).items.length, 0);
const bad = c.normalizeItem({w:NaN,h:Infinity,x:-900,y:900,gain:Infinity,style:'bad',color:'red',auraEdges:['left','left','bad']});
assert.equal(bad.style,'bars'); assert.equal(bad.color,'');
assert.deepEqual(bad.auraEdges,['left']);
assert(bad.x + bad.w >= .05 && bad.y <= .95);
const many = c.normalize({items:Array.from({length:40}, (_,i)=>({id:String(i)}))});
assert.equal(many.items.length,40);
for (const style of c.choices.style) {
    const item = c.normalizeItem({style});
    for (const tab of ['Shape','Motion','Field']) {
        for (const p of params.forTab(tab,item)) {
            assert(p.key in item, `${style}/${tab}/${p.key}`);
            if (p.type === 'choice') assert(c.choices[p.key]);
            if (p.type === 'number') assert(c.ranges[p.key]);
        }
    }
}
assert.equal(params.forTab('Field',c.normalizeItem({style:'aura'})).length,33);
assert(!params.forTab('Shape',c.normalizeItem({style:'curtain'})).some(p=>p.key==='segments'));
const folded = math.resample([0,.2,.6,1],128);
assert.equal(folded.length,128);
assert(folded.every(v=>Number.isFinite(v)&&v>=0&&v<=1));
assert(math.ease(0,1,.03,.05,.2)>0);
assert(aura.sectors(folded).every(Number.isFinite));
console.log('VISUALIZER_UNIT_PASS');
