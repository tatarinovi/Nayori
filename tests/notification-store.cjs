const fs = require('fs'), os = require('os'), path = require('path'), vm = require('vm'), assert = require('assert')

function loadModule(file) {
    const source = fs.readFileSync(file, 'utf8').replace(/^\.pragma library\n/, '')
    const context = {}
    vm.runInNewContext(source, context)
    return context
}

const store = loadModule('services/island/NotificationStore.js')
const AGE = 7776000000
assert.equal(store.MAX_AGE_MS, AGE)
assert.equal(store.maxAge(), AGE)

const now = 10_000_000_000_000
function note(id, extra) {
    return Object.assign({
        id: id, appName: 'Почта', summary: 'Письмо ' + id, body: 'Текст ' + id,
        time: now - id * 1000, read: false, desktopEntry: '', actions: []
    }, extra)
}

// --- Порядок и группы ---
{
    const list = [{ id: 1, time: 5 }, { id: 3, time: 5 }, { id: 2, time: 9 }, { id: 4, time: 5 }]
    assert.deepEqual(store.newestFirst(list).map(r => r.id), [2, 4, 3, 1])
    assert.equal(list[0].id, 1, 'сортировка не портит исходный список')
    const state = store.create()
    store.insertInbox(state, note(1, { appName: 'Почта', summary: 'Старое', time: 100 }), 100)
    store.insertInbox(state, note(2, { appName: 'Часы', summary: 'Будильник', time: 200 }), 200)
    store.insertInbox(state, note(3, { appName: 'Почта', summary: 'Новое', time: 300 }), 300)
    assert.deepEqual(state.inbox.map(r => r.id), [3, 2, 1], 'новые уведомления в начале')
    store.insertInbox(state, note(1, { appName: 'Почта', summary: 'Обновлённое', time: 100 }), 400)
    assert.deepEqual(state.inbox.map(r => r.id), [3, 2, 1], 'обновление не прыгает наверх')
    assert.equal(state.inbox.find(r => r.id === 1).summary, 'Обновлённое')
    store.clearInbox(state, 500)
    const groups = store.searchHistory(state, '')
    assert.deepEqual(groups.map(g => g.appName), ['Почта', 'Часы'])
    assert.deepEqual(groups[0].items.map(r => r.id), [3, 1])
    assert.equal(groups[0].items[0].summary, 'Новое')
    assert.equal(groups[1].items[0].id, 2)
}

// --- Закрытие, очистка, закрытие приложением ---
{
    const state = store.create()
    store.insertInbox(state, note(1, { appName: 'Telegram', desktopEntry: 'org.telegram.desktop', time: 10, read: true }), 10)
    store.insertInbox(state, note(2, { appName: 'Telegram', desktopEntry: 'org.telegram.desktop', time: 20 }), 20)
    store.insertInbox(state, note(3, { appName: 'niri', desktopEntry: 'niri', time: 30, read: false }), 30)
    assert.equal(state.inbox[0].sourceKey, 'entry:niri')
    store.closeToHistory(state, [2], now, 'user')
    assert.deepEqual(state.inbox.map(r => r.id), [3, 1])
    assert.equal(state.history.length, 1)
    assert.equal(state.history[0].id, 2)
    assert.equal(state.history[0].closedBy, 'user')
    assert.equal(state.history[0].read, false)
    assert.equal(state.history[0].live, false)
    store.closeToHistory(state, [1, 2], now, 'user')
    assert.deepEqual(state.inbox.map(r => r.id), [3])
    assert.deepEqual(state.history.map(r => r.id).sort(), [1, 2])
    assert.equal(state.history.find(r => r.id === 1).closedBy, 'user')
    assert.equal(state.history.find(r => r.id === 1).read, true, 'прочитанность сохраняется')
    store.closeToHistory(state, [3], now, 'app')
    assert.deepEqual(state.inbox, [])
    const closed = state.history.find(r => r.id === 3)
    assert.ok(closed, 'приложение не стирает запись')
    assert.equal(closed.closedBy, 'app')
    assert.equal(closed.read, false, 'закрытие не делает запись прочитанной')
    assert.equal(closed.body, 'Текст 3')
    store.insertInbox(state, note(4, { appName: 'Почта', summary: 'Ещё', body: 'Остаётся', time: 40 }), 40)
    store.clearInbox(state, now)
    assert.deepEqual(state.inbox, [])
    assert.ok(state.history.some(r => r.id === 4 && r.closedBy === 'user' && r.body === 'Остаётся'))
    assert.ok(state.history.some(r => r.id === 3 && r.closedBy === 'app'), 'очистка входящих не удаляет уже закрытое приложением')
    store.insertInbox(state, note(5, { summary: 'Живое', time: 50 }), 50)
    store.closeToHistory(state, [5], now, 'timeout')
    const timed = state.history.find(r => r.id === 5)
    assert.ok(timed)
    assert.equal(timed.closedBy, '')
    assert.equal(timed.read, false, 'таймер баннера не отмечает прочитанным')
}

// --- Поиск ---
{
    const state = store.create()
    store.insertInbox(state, note(1, { appName: 'Почта', desktopEntry: 'org.unique.mail', summary: 'Письмо', body: 'Альфа', time: 10 }), 10)
    store.insertInbox(state, note(2, { appName: 'Почта', desktopEntry: 'org.unique.mail', summary: 'Второе', body: 'Бета', time: 30 }), 30)
    store.insertInbox(state, note(3, { appName: 'Часы', summary: 'Будильник', body: 'Подъём', time: 20 }), 20)
    store.clearInbox(state, 40)
    assert.equal(store.searchHistory(state, 'unique').length, 0, 'ключ desktop-entry сам по себе не ищется')
    const mail = store.searchHistory(state, 'ПОЧТА')
    assert.equal(mail.length, 1)
    assert.deepEqual(mail[0].items.map(r => r.id), [2, 1])
    const one = store.searchHistory(state, 'альфа')
    assert.equal(one.length, 1)
    assert.deepEqual(one[0].items.map(r => r.id), [1])
    assert.equal(store.searchHistory(state, '  будил ')[0].appName, 'Часы')
    assert.deepEqual(store.searchHistory(state, 'нет такого'), [])
}

// --- Удаление истории ---
{
    const state = store.create()
    store.insertInbox(state, note(1, { appName: 'Telegram', desktopEntry: 'org.telegram.desktop', time: 10 }), 10)
    store.insertInbox(state, note(2, { appName: 'Telegram', desktopEntry: 'org.telegram.desktop', time: 20 }), 20)
    store.insertInbox(state, note(3, { appName: 'niri', desktopEntry: 'niri', time: 30 }), 30)
    store.insertInbox(state, note(4, { appName: 'Почта', summary: 'Во входящих', time: 40 }), 40)
    store.closeToHistory(state, [1, 2, 3], now, 'user')
    assert.deepEqual(state.inbox.map(r => r.id), [4])
    const key = state.history.find(r => r.id === 1).sourceKey
    assert.equal(key, 'entry:org.telegram.desktop')
    store.deleteHistory(state, [2])
    assert.deepEqual(state.history.map(r => r.id).sort(), [1, 3])
    assert.deepEqual(state.inbox.map(r => r.id), [4])
    store.deleteHistoryGroup(state, key)
    assert.deepEqual(state.history.map(r => r.id), [3])
    store.clearHistory(state)
    assert.deepEqual(state.history, [])
    assert.equal(state.inbox[0].summary, 'Во входящих')
}

// --- 90 дней ---
{
    const state = store.create()
    const edge = now - AGE
    store.insertInbox(state, note(1, { time: edge, summary: 'Граница' }), now)
    store.insertInbox(state, note(2, { time: edge - 1, summary: 'Старое' }), now)
    store.closeToHistory(state, [1, 2], now, 'user')
    store.insertInbox(state, note(3, { time: edge, summary: 'Ещё граница' }), now)
    store.insertInbox(state, note(4, { time: edge - 1, summary: 'Старое входящее' }), now)
    store.purge(state, now, AGE)
    assert.deepEqual(state.history.map(r => r.id), [1])
    assert.deepEqual(state.inbox.map(r => r.id), [3])
    store.purge(state, NaN, AGE)
    assert.equal(state.inbox.length, 1, 'битые часы ничего не выкидывают')
}

// --- Файл: битый, пустой, без картинки, без действий, не live ---
{
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nayori-notifications-'))
    const secret = 'секретное-тело-уведомления'
    const shot = '/tmp/nayori-shot-secret.png'
    try {
        assert.ok(dir.indexOf(os.tmpdir()) === 0)
        assert.equal(store.statePath({ XDG_STATE_HOME: '/tmp/xdg' }), '/tmp/xdg/nayori/notifications.json')
        assert.equal(store.statePath({ XDG_STATE_HOME: '/tmp/xdg/' }), '/tmp/xdg/nayori/notifications.json')
        assert.equal(store.statePath({ HOME: '/home/me' }), '/home/me/.local/state/nayori/notifications.json')
        assert.equal(store.statePath({ XDG_STATE_HOME: '', HOME: '/home/me' }), '/home/me/.local/state/nayori/notifications.json')

        const file = path.join(dir, 'nayori', 'notifications.json')
        assert.equal(store.loadFromFile(fs, path.join(dir, 'missing.json'), now).ok, false)
        assert.doesNotThrow(() => store.loadFromFile(fs, path.join(dir, 'missing.json'), now))

        fs.mkdirSync(path.join(dir, 'not-a-file'))
        assert.doesNotThrow(() => store.loadFromFile(fs, path.join(dir, 'not-a-file'), now))
        assert.equal(store.loadFromFile(fs, path.join(dir, 'not-a-file'), now).ok, false)

        const empty = path.join(dir, 'empty.json')
        fs.writeFileSync(empty, '')
        assert.equal(store.load(fs.readFileSync(empty, 'utf8')).ok, false)
        fs.writeFileSync(empty, '   \n')
        const blank = store.loadFromFile(fs, empty, now)
        assert.equal(blank.ok, false)
        assert.deepEqual(blank.inbox, [])
        assert.deepEqual(blank.history, [])

        const partial = path.join(dir, 'partial.json')
        fs.writeFileSync(partial, '{"version":1,"inbox":[{"id":1,"body":"' + secret + '"')
        let partialState
        assert.doesNotThrow(() => { partialState = store.loadFromFile(fs, partial, now) })
        assert.equal(partialState.ok, false)
        assert.equal(partialState.inbox.length, 0)

        const corrupt = path.join(dir, 'corrupt.json')
        fs.writeFileSync(corrupt, '{')
        assert.equal(store.loadFromFile(fs, corrupt, now).ok, false)
        assert.equal(store.load('null').ok, false)
        assert.equal(store.load('[]').ok, false)
        assert.equal(store.load('42').ok, false)

        const state = store.create()
        store.insertInbox(state, note(1, {
            appName: 'Почта', summary: 'Тема', body: secret, time: now - 1000, read: true,
            appIcon: 'mail-unread', actions: [{ id: 'open', text: 'Открыть' }],
            image: shot, invoke: function() { return shot }
        }), now)
        assert.equal(state.inbox[0].appIconName, 'mail-unread')
        assert.ok(!('actions' in state.inbox[0]))
        assert.ok(!('image' in state.inbox[0]))
        assert.equal(state.inbox[0].live, true, 'живая запись в памяти ещё не с диска')
        store.insertInbox(state, note(2, { appIcon: shot, summary: 'Снимок', body: 'Без пути', time: now - 500 }), now)
        assert.equal(state.inbox.find(r => r.id === 2).appIconName, '')
        store.closeToHistory(state, [2], now, 'app')
        assert.equal(store.saveToFile(fs, file, state, now), true)
        assert.ok(file.indexOf(dir) === 0)
        const names = fs.readdirSync(path.dirname(file))
        assert.ok(!names.some(name => name.indexOf('.tmp') >= 0), 'временный файл не остаётся')
        const raw = fs.readFileSync(file, 'utf8')
        assert.equal(raw.indexOf(shot), -1)
        assert.equal(raw.indexOf('Открыть'), -1)
        assert.equal(raw.indexOf('invoke'), -1)
        assert.ok(raw.indexOf(secret) >= 0)
        const parsed = JSON.parse(raw)
        assert.deepEqual(Object.keys(parsed.inbox[0]).sort(), store.FIELDS.slice().sort())
        assert.equal(parsed.history[0].closedBy, 'app')
        const again = store.load(raw)
        assert.equal(again.ok, true)
        assert.equal(again.inbox[0].live, false)
        assert.equal(again.inbox[0].loadedFromDisk, true)
        assert.equal(again.inbox[0].read, true)
        assert.equal(again.inbox[0].body, secret)
        assert.ok(!('image' in again.inbox[0]))
        assert.ok(!('actions' in again.inbox[0]))
        assert.equal(again.history[0].live, false)
        assert.equal(again.history[0].loadedFromDisk, true)
        assert.equal(again.history[0].closedBy, 'app')

        const noImage = JSON.stringify({
            version: 1,
            inbox: [{ id: 8, appName: 'Почта', summary: 'Без картинки', body: 'Текст', time: now, read: false, sourceKey: 'name:Почта', desktopEntry: '', appIconName: 'mail', closedBy: '' }],
            history: []
        })
        const missingImage = store.load(noImage)
        assert.equal(missingImage.ok, true)
        assert.equal(missingImage.inbox.length, 1)
        assert.ok(!('image' in missingImage.inbox[0]))
        assert.equal(missingImage.inbox[0].appIconName, 'mail')
        assert.equal(missingImage.inbox[0].live, false)

        const forced = store.load(JSON.stringify({
            version: 1,
            inbox: [{ id: 9, appName: 'Почта', summary: 'Живое', body: 'Нет', time: now, read: false, live: true, image: shot, actions: [{ id: 'a', text: 'Да' }], closedBy: '' }],
            history: []
        }))
        assert.equal(forced.inbox[0].live, false, 'повторная загрузка не оживляет запись')
        assert.equal(forced.inbox[0].loadedFromDisk, true)
        assert.ok(!('actions' in forced.inbox[0]))
        assert.ok(!('image' in forced.inbox[0]))

        const aged = path.join(dir, 'aged.json')
        fs.writeFileSync(aged, JSON.stringify({
            version: 1,
            inbox: [
                { id: 1, appName: 'Почта', summary: 'Старое', body: secret, time: now - AGE - 5, read: false, closedBy: '' },
                { id: 2, appName: 'Почта', summary: 'Свежее', body: 'Остаётся', time: now - 1000, read: true, closedBy: '' }
            ],
            history: [{ id: 3, appName: 'Часы', summary: 'Давно', body: 'Нет', time: now - AGE - 1, read: false, closedBy: 'user' }]
        }))
        const purged = store.loadFromFile(fs, aged, now)
        assert.equal(purged.ok, true)
        assert.deepEqual(purged.inbox.map(r => r.id), [2])
        assert.deepEqual(purged.history, [])
        assert.equal(purged.inbox[0].read, true)
        assert.equal(purged.inbox[0].live, false)

        const before = fs.readFileSync(file, 'utf8')
        const fake = {
            mkdirSync: fs.mkdirSync.bind(fs),
            openSync: fs.openSync.bind(fs),
            writeSync: fs.writeSync.bind(fs),
            fsyncSync: fs.fsyncSync.bind(fs),
            closeSync: fs.closeSync.bind(fs),
            unlinkSync: fs.unlinkSync.bind(fs),
            renameSync: function() { throw new Error('rename') }
        }
        const next = store.create()
        next.inbox = [note(7, { summary: 'Не записать', body: secret, time: now })]
        assert.equal(store.saveToFile(fake, file, next, now), false)
        assert.equal(fs.readFileSync(file, 'utf8'), before, 'неудачная запись не затирает файл')
        assert.ok(!fs.readdirSync(path.dirname(file)).some(name => name.indexOf('.tmp') >= 0))

        const future = path.join(dir, 'future.json')
        fs.writeFileSync(future, JSON.stringify({ version: 2, inbox: [{ id: 1, body: secret }], history: [] }))
        const held = store.loadFromFile(fs, future, now)
        assert.equal(held.ok, false)
        assert.equal(held.preserve, true)
        assert.deepEqual(held.inbox, [])
        assert.equal(store.saveToFile(fs, future, held, now), false)
        assert.equal(fs.readFileSync(future, 'utf8').indexOf('"version":2') >= 0, true)

        const replaced = store.create()
        replaced.inbox = [note(6, { summary: 'После порчи', body: 'Норма', time: now })]
        assert.equal(store.saveToFile(fs, corrupt, replaced, now), true)
        assert.equal(store.loadFromFile(fs, corrupt, now).inbox[0].summary, 'После порчи')
    } finally {
        fs.rmSync(dir, { recursive: true, force: true })
    }
}

console.log('notification-store: ok')
