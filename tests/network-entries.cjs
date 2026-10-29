const assert = require('node:assert/strict')
const fs = require('node:fs')
const vm = require('node:vm')
const context = vm.createContext({})
vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../islands/status/NetworkEntries.js'), 'utf8').replace(/^\.pragma.*$/m, ''), context)
const a = {name: 'Alpha', signalStrength: 0.8}
const b = {name: 'Beta', signalStrength: 0.2}
const c = {name: 'Gamma', signalStrength: 0.8}
const empty = {name: '', signalStrength: 1}
const devices = {values: [
    {type: 1, networks: {values: [b, a, empty]}},
    {type: 2, networks: {values: [{name: 'Ethernet', signalStrength: 1}]}},
    {type: 1, networks: {values: [c]}}
]}
assert.deepEqual(Array.from(context.ranked(devices, 1), x => x.name), ['Alpha', 'Gamma', 'Beta'])
assert.deepEqual(devices.values[0].networks.values, [b, a, empty], 'sorting must not mutate the live model')
b.signalStrength = 0.99
assert.equal(context.ranked(devices, 1)[0], b, 'signal changes reorder live entries')
assert.equal(context.ranked(null, 1).length, 0)
assert.equal(context.ranked([], 1).length, 0)
const many = Array.from({length: 8}, (_, i) => ({name: `network-${i}`, signalStrength: i / 10}))
const ranked = context.ranked([{type: 1, networks: many}], 1)
assert.deepEqual(Array.from(ranked.slice(0, 3), x => x.name), ['network-7', 'network-6', 'network-5'])
assert.equal(ranked.slice(3).length, 5)
console.log('NETWORK_ENTRIES_PASS')
