const fs = require('fs'), vm = require('vm'), assert = require('assert')
const context = {}
vm.createContext(context)
vm.runInContext(fs.readFileSync('services/ui/StartRouting.js', 'utf8').replace(/^\.pragma.*$/m, ''), context)
const target = context.target
const screens = ['DP-1', 'DP-2']
// Закрыто: меню открывается на мониторе, который niri считает активным.
assert.equal(target('', screens, 'DP-2'), 'DP-2')
assert.equal(target('', screens, 'DP-1'), 'DP-1')
// Открыто на DP-1, а активным стал DP-2: тап закрывает меню на DP-1, а не открывает второе.
assert.equal(target('DP-1', screens, 'DP-2'), 'DP-1')
assert.equal(target('DP-2', screens, 'DP-1'), 'DP-2')
// Устаревшая запись про исчезнувший монитор не должна глушить тап.
assert.equal(target('DP-9', screens, 'DP-2'), 'DP-2')
// niri недоступен или назвал неизвестный выход: первый монитор.
assert.equal(target('', screens, ''), 'DP-1')
assert.equal(target('', screens, 'HDMI-A-1'), 'DP-1')
assert.equal(target('', [], 'DP-1'), '')
assert.equal(target('', undefined, 'DP-1'), '')
console.log('START_ROUTING_PASS')
