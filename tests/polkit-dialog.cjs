const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const vm = require('node:vm')

const logic = {}
vm.createContext(logic)
vm.runInContext(fs.readFileSync(path.join(__dirname, '../services/system/PolkitDialog.js'), 'utf8'), logic)

function user(id, name, display, group) {
    return { id: id, name: name, displayName: display || name, isGroup: !!group }
}

function keysOf(value, out) {
    if (!value || typeof value !== 'object') return
    Object.keys(value).forEach(function(key) {
        out.push(key)
        keysOf(value[key], out)
    })
}

const state = logic.create()
assert.equal(logic.begin(state, { cookie: '', message: 'пустой' }).ok, false)

const first = logic.begin(state, {
    cookie: 'a',
    message: 'Установить обновление',
    actionId: 'org.example.install',
    identities: [user(10, 'katamy', 'Катя,,,,'), user(0, 'root', 'Root')],
    selectedId: 10,
    responseRequired: true,
    prompt: 'Password:'
})
assert.equal(first.queued, false)
assert.equal(state.active.cookie, 'a')
assert.equal(state.active.identities[0].displayName, 'Катя,,,,')
assert.equal(logic.identityTitle(state.active.identities[0]), 'Катя (katamy)')
assert.equal(logic.identityTitle(user(1, 'wheel', 'wheel', true)), 'wheel, группа')
assert.equal(logic.promptHint('Password:'), '')
assert.equal(logic.promptHint('Код второго фактора'), 'Код второго фактора')
assert.equal(logic.canSubmit(state, 'a', state.active.generation), true)

const generationA = state.active.generation
const second = logic.begin(state, { cookie: 'b', message: 'Подключить сеть', identities: [user(10, 'katamy')], responseRequired: true })
const third = logic.begin(state, { cookie: 'c', message: 'Изменить время', identities: [user(10, 'katamy')], responseRequired: true })
assert.equal(second.queued, true)
assert.equal(third.queued, true)
assert.equal(state.active.cookie, 'a')
assert.equal(state.active.message, 'Установить обновление')
assert.equal(state.queue.map(item => item.cookie).join(","), "b,c")

assert.equal(logic.fail(state, 'b', 'чужая ошибка'), false)
assert.equal(state.active.errorText, '')
assert.equal(logic.settle(state, 'b', 'cancelled'), 'queued')
assert.equal(state.queue.map(item => item.cookie).join(","), "c")
assert.equal(state.active.cookie, 'a')
assert.equal(logic.canSubmit(state, 'a', generationA), true)

assert.equal(logic.selectIdentity(state, 'c', 10), false)
assert.equal(logic.selectIdentity(state, 'a', 0), true)
assert.notEqual(state.active.generation, generationA)
assert.equal(state.active.responseRequired, false)
assert.equal(logic.canSubmit(state, 'a', generationA), false)
const afterIdentity = state.active.generation
assert.equal(logic.prompt(state, 'a', { prompt: 'Password:', responseRequired: true, responseVisible: false }), true)
assert.equal(logic.canSubmit(state, 'a', afterIdentity), true)

assert.equal(logic.fail(state, 'a', ''), true)
assert.equal(state.active.phase, 'failed')
assert.equal(state.active.failed, true)
assert.equal(logic.canSubmit(state, 'a', afterIdentity), false)
const afterFail = state.active.generation
assert.equal(logic.prompt(state, 'a', { prompt: 'Password:', responseRequired: true, responseVisible: false }), true)
assert.equal(state.active.errorText, '')
assert.equal(logic.canSubmit(state, 'a', afterFail), true)
assert.equal(logic.canSubmit(state, 'a', afterIdentity), false)
assert.equal(logic.note(state, 'c', 'не сюда', true), false)
assert.equal(logic.note(state, 'a', 'Пароль не подошёл', true), true)
assert.equal(state.queue[0].errorText || '', '')

assert.equal(logic.settle(state, 'a', 'cancelled'), 'active')
assert.equal(logic.shown(state), null)
assert.equal(logic.canSubmit(state, 'a', afterFail), false)
assert.equal(logic.advance(state), true)
assert.equal(state.active.cookie, 'c')
assert.equal(state.active.message, 'Изменить время')
assert.equal(state.queue.length, 0)
assert.notEqual(state.active.generation, afterFail)

const replaced = logic.create()
logic.begin(replaced, { cookie: 'a', message: 'первый', identities: [user(1, 'one')], responseRequired: true })
logic.begin(replaced, { cookie: 'b', message: 'второй', identities: [user(2, 'two')], responseRequired: true })
const oldGeneration = replaced.active.generation
logic.follow(replaced, { cookie: 'c', message: 'текущий', identities: [user(3, 'three')], responseRequired: true })
assert.equal(replaced.active.cookie, 'c')
assert.equal(replaced.active.message, 'текущий')
assert.equal(replaced.queue.map(item => item.cookie).join(","), "b")
assert.equal(logic.canSubmit(replaced, 'a', oldGeneration), false)
assert.equal(logic.canSubmit(replaced, 'c', replaced.active.generation), true)

const same = logic.create()
const kept = logic.begin(same, { cookie: 'a', message: 'первый', identities: [user(1, 'one')], responseRequired: true })
logic.begin(same, { cookie: 'a', message: 'первый', prompt: 'ещё', responseRequired: true })
assert.equal(same.active.generation, kept.generation)
assert.equal(logic.settle(same, 'missing', 'left'), 'missing')
assert.equal(logic.invalidateInput(same), true)
assert.equal(logic.canSubmit(same, 'a', kept.generation), false)

const names = []
keysOf(state, names)
keysOf(replaced, names)
keysOf(same, names)
assert.equal(names.some(key => /^(password|secret|passwd|token)$/i.test(key)), false)

console.log('POLKIT_DIALOG_TESTS_PASS')
