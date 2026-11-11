const fs = require('fs'), vm = require('vm'), assert = require('assert')
const policy = {}
vm.createContext(policy)
vm.runInContext(fs.readFileSync('services/canvas/DesktopBlur.js', 'utf8'), policy)
const workspaces = [
    {id: 1, output: 'DP-1', active: true},
    {id: 2, output: 'DP-1', active: false},
    {id: 3, output: 'DP-2', active: true}
]
const has = (windows, output = 'DP-1', spaces = workspaces) => policy.occupied(spaces, windows, output)
assert.equal(has([]), false)
assert.equal(has([{workspaceId: 1}]), true)
assert.equal(has([{workspaceId: 2}]), false)
assert.equal(has([{workspaceId: 1}], 'DP-2'), false)
assert.equal(has([{workspaceId: 3}], 'DP-2'), true)
assert.equal(has([{workspaceId: 3}], 'DP-1'), false)
// Workspace/output association is authoritative during window output refresh.
assert.equal(has([{workspaceId: 1, output: 'stale-output', focused: false}]), true)
assert.equal(has([{workspaceId: 1}], 'disconnected'), null)
assert.equal(has([], 'DP-1', []), null)
const switched = workspaces.map(w => ({...w, active: w.output === 'DP-1' ? w.id === 2 : w.active}))
assert.equal(has([{workspaceId: 1}], 'DP-1', switched), false)
assert.equal(has([{workspaceId: 2}], 'DP-1', switched), true)
// App IDs may legitimately be empty; shell layer surfaces never enter this model.
assert.equal(has([{workspaceId: 1, appId: ''}]), true)
console.log('DESKTOP_BLUR_POLICY_PASS')
