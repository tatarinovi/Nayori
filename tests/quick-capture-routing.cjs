const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

// Execute the real IPC opening logic without starting a desktop shell.
const shell = fs.readFileSync(path.join(__dirname, '../surfaces/ShellSession.qml'), 'utf8')
const start = shell.indexOf('    function openQuickCapture() {')
const end = shell.indexOf('    function finishQuickCaptureLocation(', start)
assert(start >= 0 && end > start)
for (const [enabled, vault] of [[false, ''], [true, ''], [false, '/vault'], [true, '/vault']]) {
    let focused = 0
    let located = 0
    const root = {
        quickCaptureOpened: false,
        locatingQuickCapture: false,
        quickCaptureFocusRequested() { focused++ },
        openSettings() { assert.fail('inbox.open must not redirect to settings') }
    }
    const lockService = { locked: false }
    const context = {
        root, lockService, startup: { present: false },
        captureStore: { editing: false },
        quickCaptureStore: { text: '' },
        settingsStore: { values: { quickCaptureEnabled: enabled, quickCaptureVault: vault, quickCaptureContext: 'Personal' } },
        quickCaptureFeedback: { stop() {} },
        quickCaptureLocation: { restart() { located++ } }
    }
    vm.createContext(context)
    vm.runInContext(shell.slice(start, end), context)
    context.openQuickCapture()
    assert.equal(root.locatingQuickCapture, true)
    assert.equal(located, 1)
    root.quickCaptureOpened = true
    context.openQuickCapture()
    assert.equal(focused, 1)
    assert.equal(located, 1, 'repeat focuses existing capture')
    context.startup.present = true
    context.openQuickCapture()
    assert.equal(focused, 1, 'startup prevents opening over the splash')
    context.startup.present = false
    lockService.locked = true
    context.openQuickCapture()
    assert.equal(focused, 1, 'lock prevents opening or focusing')
}
console.log('QUICK_CAPTURE_ROUTING_PASS')
