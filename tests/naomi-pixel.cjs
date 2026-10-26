const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const art = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'surfaces/companion/NaomiPixelArt.js'), 'utf8')
    .replace('.pragma library', ''), art);
const approved = JSON.parse(fs.readFileSync(path.join(root, 'assets/naomi/proposals/hoodie-v3/sprite.json'), 'utf8'));
const expected = Array(140 * 200).fill('transparent');
for (const [x, y, length, color] of approved.runs)
    for (let i = 0; i < length; i++) expected[y * 140 + x + i] = approved.palette[color];
const rest = Array.from(art.raster({}));
assert.deepEqual(rest.map(i => art.originalPalette[i]), expected,
    'neutral pose must preserve every pixel of the approved face and silhouette');
const blink = Array.from(art.raster({blink: true}));
const eyeArea = new Set(Array.from(art.closedEyes, p => p[1] * 140 + p[0]));
let changes = 0;
for (let i = 0; i < rest.length; i++) if (rest[i] !== blink[i]) {
    changes++;
    assert(eyeArea.has(i), 'blink may only modify the eye patches');
}
assert(changes > 10, 'blink closes both eyes');
for (const [x, y] of [[60,56],[60,57],[61,57],[65,60],[66,60],[67,59],[68,59],[69,58],[67,60]])
    assert.equal(blink[y * 140 + x], rest[y * 140 + x], 'approved nose/smile survives blinking');
const idle = Array.from(art.raster({rise: 1, tail: 2, fringe: -1, ribbon: 1, look: 1}));
assert.notDeepEqual(idle, rest, 'independent idle channels change the pose');
assert.deepEqual(idle.slice(165 * 140), rest.slice(165 * 140), 'feet remain anchored');
const warm = art.paletteFor({r:0.85,g:0.5,b:0.6},{r:0.5,g:0.3,b:0.4});
const cool = art.paletteFor({r:0.4,g:0.8,b:0.65},{r:0.25,g:0.5,b:0.4});
let clothing = 0, accents = 0;
for (let i = 1; i < art.originalPalette.length; i++) {
    if (art.colorRoles[i] === 'fixed') {
        assert.equal(warm[i], art.originalPalette[i], 'fixed skin/hair preserved');
        assert.equal(cool[i], art.originalPalette[i], 'fixed skin/hair preserved');
    } else {
        assert.notEqual(warm[i], cool[i], 'semantic colour responds to wallpaper palette');
        if (art.colorRoles[i] === 'clothing') clothing++;
        if (art.colorRoles[i] === 'accent') accents++;
    }
}
assert(clothing > 5 && accents > 5, 'separate shaded clothing and accent ramps');
for (const [x, y, length, color] of art.render({rise: 1, tail: -2, fringe: 1, ribbon: -1}))
    assert(x >= 0 && x + length <= 140 && y >= 0 && y < 200 && color > 0 && color < art.originalPalette.length);
console.log('NAOMI_PIXEL_DATA_PASS approved-pixels face blink palette anchored-feet');
