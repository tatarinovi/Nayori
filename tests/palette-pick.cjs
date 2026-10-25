const fs = require('fs'), vm = require('vm'), assert = require('assert')
function moduleAt(file) {
    const context = {}
    vm.createContext(context)
    vm.runInContext(fs.readFileSync(file, 'utf8'), context)
    return context
}
const pick = moduleAt('services/palette/PalettePick.js')
const fallback = '#C0AFD1'

function colorsOf(result) { return result.candidates.map(function(item) { return item.color }) }

const empty = pick.rank([])
assert.equal(empty.accent, fallback)
assert.equal(empty.fallbackUsed, true)
assert.deepEqual(empty.candidates, [{ color: fallback, share: 1 }])
assert.equal(pick.rank(null).fallbackUsed, true)
assert.equal(pick.rank([{ color: 'nope', share: 1 }, { color: '#12', share: 1 }]).fallbackUsed, true)

const mono = pick.rank([
    { color: '#000000', share: 0.5 },
    { color: '#FFFFFF', share: 0.3 },
    { color: '#777777', share: 0.2 }
])
assert.equal(mono.accent, fallback)
assert.equal(mono.fallbackUsed, true)
assert.deepEqual(colorsOf(mono), [fallback])

for (const solid of ['#000000', '#121217', '#FFFFFF', '#F4F4F6', '#808080', '#8A8A8E'])
    assert.equal(pick.rank([{ color: solid, share: 1 }]).fallbackUsed, true, solid)

const field = pick.rank([
    { color: '#121217', share: 0.75 },
    { color: '#C4A8E0', share: 0.25 }
])
assert.equal(field.accent, '#C4A8E0')
assert.equal(field.fallbackUsed, false)
assert.deepEqual(colorsOf(field), ['#C4A8E0'])
assert.equal(field.candidates[0].share, 0.25)

for (const solid of ['#FF0000', '#00FF00', '#0000FF']) {
    const one = pick.rank([{ color: solid, share: 1 }])
    assert.equal(one.accent, solid)
    assert.equal(one.fallbackUsed, false)
}

const competing = [
    { color: '#101014', share: 0.40 },
    { color: '#FFFFFF', share: 0.05 },
    { color: '#8A8A8E', share: 0.05 },
    { color: '#FF0000', share: 0.20 },
    { color: '#C4A8E0', share: 0.15 },
    { color: '#5C8A86', share: 0.10 },
    { color: '#00FF00', share: 0.05 }
]
const ranked = pick.rank(competing)
assert.deepEqual(colorsOf(ranked), ['#C4A8E0', '#5C8A86', '#FF0000', '#00FF00'])
assert.equal(ranked.fallbackUsed, false)
assert.deepEqual(colorsOf(pick.rank(competing.slice().reverse())), colorsOf(ranked))
const again = pick.rank(competing)
assert.deepEqual(again, ranked)

const dominantNeon = pick.rank([{ color: '#FF0000', share: 0.95 }, { color: '#C4A8E0', share: 0.05 }])
assert.equal(dominantNeon.accent, '#FF0000')
const taste = pick.rank([{ color: '#FF0000', share: 0.50 }, { color: '#C4A8E0', share: 0.20 }])
assert.equal(taste.accent, '#C4A8E0')
assert.equal(taste.candidates[0].share, 0.2)
assert.equal(taste.candidates[1].color, '#FF0000')
assert.equal(taste.candidates[1].share, 0.5)

const meanTrap = pick.rank([{ color: '#FF0000', share: 1 }, { color: '#0000FF', share: 1 }])
assert.equal(meanTrap.accent, '#FF0000')
assert.notEqual(meanTrap.accent, '#800080')

const merged = pick.rank([
    { color: '#ff0000', share: 0.2 },
    { color: '#FF0000', share: 0.2 },
    { color: '#C4A8E0', share: 0.2 }
])
assert.equal(merged.accent, '#C4A8E0')
assert.equal(merged.candidates.length, 2)
assert.equal(merged.candidates[1].share, 0.4)

const buckets = []
for (let i = 0; i < 20; i++) buckets.push({ color: '#FF0000', share: 0 })
buckets.push({ color: '#C4A8E0', share: 0 })
const counted = pick.rank(buckets)
assert.equal(counted.accent, '#FF0000')
assert.equal(counted.candidates[0].share, 0.952381)
assert.equal(counted.candidates[1].share, 0.047619)

const hidden = pick.rank([
    { color: '#FF0000', share: 0.9, alpha: 0 },
    { color: '#00FF0000', share: 0.9 },
    { color: '#C4A8E0', share: 0.1, alpha: 1 }
])
assert.equal(hidden.accent, '#C4A8E0')
assert.deepEqual(colorsOf(hidden), ['#C4A8E0'])

assert.equal(pick.rank([{ color: '#FF0000', share: 1, alpha: 0.4 }]).accent, '#FF0000')
assert.equal(pick.rank([{ color: '#0000FF', share: 1, alpha: 255 }]).accent, '#0000FF')
assert.equal(pick.rank([{ color: '#FF0000FF', share: 1 }]).accent, '#0000FF')
assert.equal(pick.rank([{ color: '#000000FF', share: 1 }]).fallbackUsed, true)

const original = { color: '#C4A8E0', share: 0.3, alpha: 1 }
pick.rank([original, { color: '#000000', share: 0.7 }])
assert.equal(original.share, 0.3)
assert.equal(original.color, '#C4A8E0')

const ink = '#F0E9DB'
function hueDistance(a, b) {
    const delta = Math.abs(a - b)
    return Math.min(delta, 360 - delta)
}
function assertDerived(result, label) {
    assert.equal(result.neutralFallbackUsed, false, label + ' derived')
    assert.ok(pick.contrast(result.background, ink) >= 4.5, label + ' background contrast ' + pick.contrast(result.background, ink))
    assert.ok(pick.contrast(result.surfaceAlt, ink) >= 4.5, label + ' surfaceAlt contrast ' + pick.contrast(result.surfaceAlt, ink))
    assert.ok(pick.contrast(result.surface, ink) >= 4.5, label + ' surface contrast ' + pick.contrast(result.surface, ink))
    const background = pick.measure(result.background)
    const surfaceAlt = pick.measure(result.surfaceAlt)
    const surface = pick.measure(result.surface)
    assert.ok(background.L <= 0.30, label + ' background lightness ' + background.L)
    assert.ok(background.C <= 0.04, label + ' background chroma ' + background.C)
    assert.ok(surfaceAlt.C <= 0.05, label + ' surfaceAlt chroma ' + surfaceAlt.C)
    assert.ok(surfaceAlt.L > background.L + 0.05, label + ' surfaceAlt above background')
    assert.ok(surface.L + 0.02 >= surfaceAlt.L, label + ' surface stays with the pair')
    assert.notEqual(result.background, result.accent, label + ' background is not the accent')
    assert.notEqual(result.surfaceAlt, result.accent, label + ' surfaceAlt is not the accent')
}
function assertAuthored(result, label) {
    assert.equal(result.neutralFallbackUsed, true, label + ' fallback')
    assert.equal(result.background, '#121217', label + ' background')
    assert.equal(result.surface, '#4F4F57', label + ' surface')
    assert.equal(result.surfaceAlt, '#443D4E', label + ' surfaceAlt')
}

assertAuthored(empty, 'empty')
assertAuthored(pick.rank(null), 'null')
assertAuthored(pick.rank([{ color: 'nope', share: 1 }, { color: '#12', share: 1 }]), 'invalid')

const lavenderDark = pick.rank([
    { color: '#121217', share: 0.75 },
    { color: '#C4A8E0', share: 0.25 }
])
assert.equal(lavenderDark.accent, '#C4A8E0')
assert.equal(lavenderDark.background, '#121217')
assert.notEqual(lavenderDark.surfaceAlt, '#C4A8E0')
assert.notEqual(lavenderDark.surfaceAlt, '#443D4E')
assertDerived(lavenderDark, 'lavender dark')
const lavenderAlt = pick.measure(lavenderDark.surfaceAlt)
assert.ok(hueDistance(lavenderAlt.H, 285) < 12, 'surfaceAlt stays with the graphite hue ' + lavenderAlt.H)

const mostlyBlack = pick.rank([
    { color: '#000000', share: 0.9 },
    { color: '#111111', share: 0.08 },
    { color: '#C4A8E0', share: 0.02 }
])
assert.equal(mostlyBlack.accent, '#C4A8E0')
assert.equal(mostlyBlack.background, '#000000')
assert.equal(mostlyBlack.fallbackUsed, false)
assertDerived(mostlyBlack, 'mostly black')

const solidBlack = pick.rank([{ color: '#000000', share: 1 }])
assert.equal(solidBlack.fallbackUsed, true)
assert.equal(solidBlack.background, '#000000')
assertDerived(solidBlack, 'black')

assertAuthored(pick.rank([{ color: '#FFFFFF', share: 1 }]), 'white')
assertAuthored(pick.rank([{ color: '#F4F4F6', share: 1 }]), 'near white')

const gray = pick.rank([{ color: '#808080', share: 1 }])
assert.equal(gray.fallbackUsed, true)
assert.notEqual(gray.background, '#808080')
assert.notEqual(gray.background, '#121217')
assertDerived(gray, 'gray')
assert.ok(pick.measure(gray.background).C < 0.008, 'gray stays achromatic')

for (const vivid of [
    ['#FF0000', 29],
    ['#00FF00', 142],
    ['#0000FF', 264]
]) {
    const one = pick.rank([{ color: vivid[0], share: 1 }])
    assert.equal(one.accent, vivid[0])
    assert.notEqual(one.background, vivid[0])
    assertDerived(one, vivid[0])
    const background = pick.measure(one.background)
    assert.ok(background.C > 0.004 && background.C <= 0.02, vivid[0] + ' hint chroma ' + background.C)
    assert.ok(hueDistance(background.H, vivid[1]) < 15, vivid[0] + ' hue ' + background.H)
}

assert.equal(ranked.background, '#101014')
assert.notEqual(ranked.background, '#C4A8E0')
assert.notEqual(ranked.background, '#FF0000')
assertDerived(ranked, 'competing')

const vividMix = pick.rank([{ color: '#FF0000', share: 0.50 }, { color: '#C4A8E0', share: 0.20 }])
assert.equal(vividMix.accent, '#C4A8E0')
assert.notEqual(vividMix.background, '#C4A8E0')
assert.notEqual(vividMix.background, '#FF0000')
assertDerived(vividMix, 'vivid mix')
const mixHue = pick.measure(vividMix.background).H
assert.ok(hueDistance(mixHue, 29) < hueDistance(mixHue, 307), 'dominant red hint, not the lavender accent ' + mixHue)

console.log('PALETTE_PICK_PASS')
