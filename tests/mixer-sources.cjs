const fs = require('fs'), vm = require('vm'), assert = require('assert')
const context = {}
vm.createContext(context)
vm.runInContext(fs.readFileSync('services/status/MixerSources.js', 'utf8').replace(/^\.pragma.*$/m, ''), context)

const zen = { key: 'Zen', title: 'Zen', hidden: false }
const merged = context.merge([], [zen, { key: 'speech-dispatcher-dummy', title: 'speech-dispatcher-dummy' }])
assert.equal(merged.changed, true)
assert.equal(merged.list.length, 2)
assert.equal(merged.list[0].hidden, false)

const renamed = context.merge(merged.list, [{ key: 'Zen', title: 'Zen Browser' }])
assert.equal(renamed.changed, true)
assert.equal(renamed.list[0].title, 'Zen Browser')
assert.equal(renamed.list[0].hidden, false)

const again = context.merge(renamed.list, [{ key: 'Zen', title: 'Zen Browser' }])
assert.equal(again.changed, false)

const hidden = context.setHidden(renamed.list, 'speech-dispatcher-dummy', true)
assert.equal(context.isHidden(hidden, 'speech-dispatcher-dummy'), true)
assert.equal(context.isHidden(hidden, 'Zen'), false)
assert.equal(context.same(hidden, context.setHidden(hidden, 'speech-dispatcher-dummy', true)), true)

const shown = context.visible([
    { key: 'Zen' },
    { key: 'speech-dispatcher-dummy' }
], hidden)
assert.equal(shown.length, 1)
assert.equal(shown[0].key, 'Zen')

assert.equal(context.summary([]), 'Пока пусто')
assert.equal(context.summary(renamed.list), '2 источника')
assert.equal(context.summary(hidden), 'скрыто 1 из 2')
assert.equal(context.summary([{ key: 'a', title: 'a' }]), '1 источник')
assert.equal(context.summary([
    { key: 'a' }, { key: 'b' }, { key: 'c' }, { key: 'd' }, { key: 'e' }
]), '5 источников')

const dirty = context.normalize([
    { key: 'ok', title: 'Ok', hidden: 1 },
    { key: 'ok', title: 'Second' },
    { key: '  ', title: 'blank' },
    null,
    { key: 'x'.repeat(300), title: 'long' }
])
assert.equal(dirty.length, 1)
assert.equal(dirty[0].hidden, false)

console.log('MIXER_SOURCES_PASS')
