const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const code = fs.readFileSync(path.join(__dirname, '../services/keybinds/KeyCapture.js'), 'utf8').replace(/^\.pragma.*$/m, '');
const constants = new Proxy({}, {get(target, name) {
    if (!(name in target)) target[name] = 1000 + Object.keys(target).length;
    return target[name];
}});
// Real ranges used by the recorder; the remaining key enums only need uniqueness.
Object.assign(constants, {Key_A: 65, Key_Z: 90, Key_0: 48, Key_9: 57, Key_F1: 200, Key_F35: 234,
    MetaModifier: 1 << 24, ControlModifier: 1 << 25, AltModifier: 1 << 26, ShiftModifier: 1 << 27,
    KeypadModifier: 1 << 28, GroupSwitchModifier: 1 << 29});
const context = vm.createContext({Qt: constants});
vm.runInContext(code, context);
const capture = (key, modifiers = 0, text = '') => context.chord({key, modifiers, text});
assert.equal(capture(65, constants.MetaModifier | constants.ControlModifier).keys, 'Super+Ctrl+A');
assert.equal(capture(constants.Key_Left, constants.AltModifier | constants.ShiftModifier).keys, 'Alt+Shift+Left');
assert.equal(capture(53, constants.KeypadModifier).keys, 'KP_5');
assert.equal(capture(constants.Key_Enter, constants.KeypadModifier).keys, 'KP_Enter');
assert.equal(capture(constants.Key_F1 + 14, constants.ControlModifier).keys, 'Ctrl+F15');
assert.equal(capture(constants.Key_Shift, constants.ShiftModifier).keys, '');
assert.equal(capture(0x044f, constants.MetaModifier, 'я').keys, 'Super+U044f');
assert.equal(capture(constants.Key_VolumeUp).keys, 'XF86AudioRaiseVolume');
assert.equal(capture(0, 0, '').keys, '');
console.log('PASS keybind recorder: modifiers, keypad, function, Unicode and media keys');
