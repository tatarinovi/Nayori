const fs = require('node:fs')
const vm = require('node:vm')
const assert = require('node:assert/strict')
function moduleAt(file, bindings = {}) {
    vm.runInNewContext(fs.readFileSync(file, 'utf8').replace(/^\.(?:pragma|import).*$/gm, ''), bindings)
    return bindings
}
const imported = moduleAt('surfaces/desktop/ImportedWidgets.js')
const layout = moduleAt('surfaces/desktop/WidgetLayout.js', {ImportedWidgets: imported})
const data = moduleAt('surfaces/desktop/ImportedWidgetData.js')
const plain = value => JSON.parse(JSON.stringify(value))
assert.equal(layout.catalog('', 'Nayori').length, 6)
for (const category of ['ii widgets', 'Shima widgets', 'Python widgets']) {
    assert.ok(layout.catalog('', category).length > 0)
}
const ids = imported.entries.map(row => row.type)
assert.equal(new Set(ids).size, ids.length)
for (const type of ['ii_calendar_agenda', 'ii_calendar_next_event', 'ii_calendar_upcoming_3days',
    'ii_resource_fill_cards', 'ii_pc_battery_bars', 'ii_pc_battery_cable',
    'python_MusicFaceLyricsSimple', 'shima_dayProgress']) assert.ok(ids.includes(type), type)
assert.match(fs.readFileSync('surfaces/desktop/vendor/widgets/python/qmldir', 'utf8'), /^singleton WaveTick 1\.0 WaveTick\.qml$/m)
const manifest = JSON.parse(fs.readFileSync('surfaces/desktop/vendor/widgets/manifest.json'))
for (const rows of Object.values(manifest.inventory)) {
    for (const row of rows) {
        assert.equal(ids.includes(row.type), row.status === 'ported', row.type)
        if (row.status !== 'ported') assert.ok(row.reason, row.type)
    }
}
for (const entry of imported.entries) {
    assert.equal(imported.options(entry.type, {}).dynamicColors, true)
    assert.equal(imported.options(entry.type, {dynamicColors: false}).dynamicColors, false)
    assert.equal(imported.options(entry.type, {dynamicColors: true}).dynamicColors, true)
    assert.ok(fs.existsSync('surfaces/desktop/vendor/widgets/' + entry.source), entry.type)
    let items = layout.add([], {id: 'first', type: entry.type}, 1920, 1080)
    items = layout.add(items, {id: 'second', type: entry.type}, 1920, 1080)
    const changed = layout.changeItem(items, 'first', 'options', {dynamicColors: true, unknownFutureKey: {value: 9}})
    assert.equal(changed[0].options.unknownFutureKey.value, 9)
    assert.equal(changed[1].options.unknownFutureKey, undefined)
    assert.equal(layout.sameLayout({snap: true, items}, {snap: true, items: changed}), false)
    const monitors = layout.normalize({'DP-1': {snap: true, items: changed}, 'HDMI-1': {snap: false, items}})
    const restored = layout.normalize(JSON.parse(JSON.stringify(monitors)))
    assert.deepEqual(plain(restored), plain(monitors))
    assert.equal(restored['HDMI-1'].items[0].options.dynamicColors, undefined)
    const moved = layout.move(changed, 'first', 9000, 9000, false)
    const clamped = layout.clamp(moved, 800, 600)
    assert.ok(clamped[0].x + layout.sizeOf(clamped[0]).width <= Math.max(800, layout.sizeOf(clamped[0]).width))
    assert.equal(clamped[0].options.unknownFutureKey.value, 9)
}
const hostile = JSON.parse('{"__proto__":{"polluted":true},"safe":{"constructor":1,"number":9},"array":[1,2]}')
const clean = layout.instanceOptions(hostile)
assert.equal(Object.hasOwn(clean, '__proto__'), false)
assert.equal(Object.hasOwn(clean.safe, 'constructor'), false)
assert.equal(clean.safe.number, 9)
assert.deepEqual(plain(layout.instanceOptions({large: 'x'.repeat(100000)})), {large: 'x'.repeat(32768)})
assert.deepEqual(plain(layout.instanceOptions({invalid: Infinity})), {invalid: null})
assert.equal(data.degrees(null, 'metric'), '')
assert.equal(data.degrees(0, 'imperial'), '32')
assert.equal(data.degrees('-10', 'metric'), '-10')
const empty = data.weather(null, '', 'metric', '#aabbcc', new Date(2026, 10, 11, 12))
assert.equal(empty.current_temp, '')
assert.equal(empty.forecast.length, 0)
const sample = data.weather({current_condition: [{temp_C: '-5', FeelsLikeC: '-8', weatherCode: '113'}], weather: [{date: '2026-11-11', maxtempC: '0', mintempC: '-6', hourly: [{time: '1200', tempC: '-2', weatherCode: '113'}]}]}, 'Moscow', 'imperial', '#aabbcc', new Date(2026, 10, 11, 12))
assert.equal(sample.current_temp, '23')
assert.equal(sample.forecast[0].hourly[0].temp, '28')
assert.equal(sample.forecast[0].hourly[0].time, '12:00')
console.log('IMPORTED_WIDGETS_UNIT_PASS')
const selected = imported.selected('python_ClockFaceDigital', {variant: 'python_ClockFaceAnalog'})
assert.equal(selected.type, 'python_ClockFaceAnalog')
assert.equal(imported.selected('python_ClockFaceDigital', {variant: 'ii_quote'}).type, 'python_ClockFaceDigital')
const analogBox = layout.sizeOf({type: 'python_ClockFaceDigital', options: {variant: 'python_ClockFaceAnalog'}, width: 300, height: 100})
assert.equal(analogBox.width, analogBox.height)
// Entire Shima/Python inventory is implemented; execution is verified by CI.
assert.equal(imported.entries.filter(row => row.category === 'Shima widgets').length, 25)
assert.equal(imported.entries.filter(row => row.category === 'Python widgets').length, 32)
for (const group of ['shima', 'python']) assert.ok(manifest.inventory[group].every(row => row.status === 'ported'))
for (const type of ['shima_todo','shima_timers','shima_notes','shima_worldClock','shima_newsTicker',
    'shima_imageConverter','shima_visualizer','shima_organicEdge',
    'python_UserFace','python_NotesFace','python_MusicFaceLyrics','python_GithubFace']) assert.ok(ids.includes(type), type)
const customBox = layout.sizeOf({type:'shima_visualizer', options:{contentWidth:240,contentHeight:120,widgetScale:150}})
assert.equal(customBox.width, 360)
assert.equal(customBox.height, 180)
const taskOptions = {tasks:[{id:'one',content:'A',done:false}],timerState:{focus:{running:true,startedAt:123456}},future:{key:7}}
const stored = layout.normalize(JSON.parse(JSON.stringify({'DP-1':{snap:true,items:[{id:'one',type:'shima_todo',x:24,y:48,options:taskOptions}]}})))
assert.deepEqual(plain(stored['DP-1'].items[0].options), taskOptions)
// Every vendored source and modification must match its provenance record.
const crypto = require('node:crypto')
for (const record of [...manifest.files, ...manifest.hostAdapters]) {
    const content = fs.readFileSync('surfaces/desktop/vendor/widgets/' + record.path)
    assert.equal(crypto.createHash('sha256').update(content).digest('hex'), record.adaptedSha256, record.path)
}
for (const name of ['cpp','hpp']) {
    const record = manifest.files.find(row => row.path === 'native/cavaspectrum.' + name)
    assert.ok(record && record.source.endsWith('cavaspectrum.' + name))
    assert.equal(record.adaptedSha256, record.sha256, 'original C++ painter remains unchanged')
}
console.log('IMPORTED_WIDGETS_ADAPTERS_UNIT_PASS')
