const fs = require('fs'), os = require('os'), path = require('path'), vm = require('vm'), assert = require('assert')

function load(file) {
    const src = fs.readFileSync(file, 'utf8').replace(/^\uFEFF?/, '').replace(/^\.pragma library\r?\n/, '').replace(/^\.import .*$/gm, '')
    const context = {}
    vm.createContext(context)
    vm.runInContext(src, context, { filename: file })
    return context
}

const policy = load('services/island/NotificationPolicy.js')
const center = {}
vm.createContext(center)
center.Banner = load('services/island/NotificationBanner.js')
center.Read = load('services/island/NotificationRead.js')
center.Store = load('services/island/NotificationStore.js')
center.Policy = policy
center.List = load('services/island/NotificationList.js')
vm.runInContext(
    fs.readFileSync('services/island/NotificationCenter.js', 'utf8').replace(/^\.pragma library\r?\n/, '').replace(/^\.import .*$/gm, ''),
    center,
    { filename: 'services/island/NotificationCenter.js' }
)

const DAY = 24 * 60 * 60 * 1000
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'nayori-notifications-'))
function writeStore(text) {
    const file = path.join(dir, 'notifications.json')
    const temp = file + '.tmp'
    fs.writeFileSync(temp, text)
    fs.renameSync(temp, file)
    return fs.readFileSync(file, 'utf8')
}
function age(text, id, time) {
    const data = JSON.parse(text)
    const walk = node => {
        if (Array.isArray(node)) node.forEach(walk)
        else if (node && typeof node === 'object') {
            if (node.id === id) {
                node.time = time
                if (node.arrivedAt != null) node.arrivedAt = time
            }
            Object.keys(node).forEach(key => walk(node[key]))
        }
    }
    walk(data)
    return JSON.stringify(data)
}
function item(id, appName, extra) {
    return Object.assign({ id: id, appName: appName, summary: 'Заголовок ' + id, body: 'Текст ' + id, actions: [] }, extra)
}
function byId(list, id) { return (list || []).find(record => record.id === id) }
function open(session, key, now) { center.view(session, key, true, now) }
function leave(session, key, now) { center.view(session, key, false, now) }

const logs = []
const originals = { log: console.log, warn: console.warn, error: console.error }
function spy() {
    logs.length = 0
    ;['log', 'warn', 'error'].forEach(name => { console[name] = function () { logs.push(Array.prototype.join.call(arguments, ' ')) } })
}
function unspy() { Object.assign(console, originals) }
function quietLog(fn) {
    spy()
    try { return fn() } finally { unspy() }
}

// Самое новое занимает свёрнутый остров, следующее перезапускает 30 с.
{
    const session = center.create()
    quietLog(() => center.ingest(session, item(1, 'Telegram', { summary: 'SECRET_SUMMARY', body: 'SECRET_BODY', replyText: 'SECRET_REPLY' }), 0))
    assert.equal(center.banner(session).currentId, 1)
    assert.equal(center.banner(session).until, 30000)
    center.ingest(session, item(2, 'Почта'), 10000)
    assert.equal(center.banner(session).currentId, 2, 'новое уведомление сменяет прежнее')
    assert.equal(center.banner(session).until, 40000, 'срок 30 с считается заново')
    center.tick(session, 30000)
    assert.equal(center.banner(session).currentId, 2, 'старый срок первого уже не действует')
    center.tick(session, 39999)
    assert.equal(center.banner(session).currentId, 2)
    center.tick(session, 40000)
    assert.equal(center.banner(session).currentId, null)
    center.tick(session, 40001)
    assert.equal(center.banner(session).currentId, null, 'истёкшее не возвращается само')
    assert.equal(byId(center.inbox(session), 1).read, false)
    assert.equal(byId(center.inbox(session), 2).read, false, 'конец баннера не делает запись прочитанной')
    assert(logs.every(line => line.indexOf('SECRET_SUMMARY') < 0 && line.indexOf('SECRET_BODY') < 0 && line.indexOf('SECRET_REPLY') < 0))
}

// При равном времени остаётся больший id.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram'), 50)
    center.ingest(session, item(4, 'Почта'), 50)
    assert.equal(center.banner(session).currentId, 4)
}

// Две секунды на вкладке, ранний уход и уведомление, пришедшее на открытой вкладке.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram'), 0)
    open(session, 'left', 0)
    center.tick(session, 1999)
    assert.equal(byId(center.inbox(session), 1).read, false)
    leave(session, 'left', 1000)
    center.tick(session, 10000)
    assert.equal(byId(center.inbox(session), 1).read, false, 'уход раньше двух секунд ничего не читает')
    assert.equal(center.history(session).length, 0)
    assert.equal(center.inbox(session).length, 1)
}
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram'), 0)
    open(session, 'left', 0)
    center.tick(session, 2000)
    assert.equal(byId(center.inbox(session), 1).read, true)
    center.ingest(session, item(2, 'Telegram'), 5000)
    center.tick(session, 6999)
    assert.equal(byId(center.inbox(session), 2).read, false, 'новое ждёт свои две секунды')
    center.tick(session, 7000)
    assert.equal(byId(center.inbox(session), 2).read, true)
    assert.equal(byId(center.inbox(session), 1).read, true)
    assert.equal(center.inbox(session).length, 2)
    assert.equal(center.history(session).length, 0, 'прочтение не переносит записи в историю')
    center.tick(session, 9000)
    assert.equal(center.inbox(session).length, 2, 'повторный отсчёт не дублирует список')
    assert.equal(center.history(session).length, 0)
}

// Группа из нескольких записей читается вместе, флаг сохраняется.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram Desktop', { desktopEntry: 'org.telegram.desktop' }), 0)
    center.ingest(session, item(2, 'Telegram Desktop', { desktopEntry: 'org.telegram.desktop' }), 100)
    center.ingest(session, item(3, 'Telegram Desktop', { desktopEntry: 'org.telegram.desktop' }), 200)
    open(session, 'left', 1000)
    center.tick(session, 2999)
    assert(center.inbox(session).every(record => !record.read))
    center.tick(session, 3000)
    assert(center.inbox(session).every(record => record.read), 'вся группа прочитана')
    assert.equal(center.inbox(session).length, 3)
    assert.equal(center.history(session).length, 0, 'группа остаётся в списке')
    const text = writeStore(center.serialize(session, 3000))
    const restored = center.create()
    center.load(restored, text, 3000)
    assert(center.inbox(restored).every(record => record.read), 'прочтение переживает перезапуск')
    center.markRead(session, [1, 2, 3])
}

// Одной открытой вкладки из нескольких островов достаточно.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram'), 0)
    leave(session, 'left', 0)
    open(session, 'right', 500)
    center.tick(session, 2499)
    assert.equal(byId(center.inbox(session), 1).read, false)
    center.tick(session, 2500)
    assert.equal(byId(center.inbox(session), 1).read, true, 'правый остров один держит вкладку')
}
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram'), 0)
    open(session, 'left', 0)
    open(session, 'right', 100)
    leave(session, 'left', 500)
    center.tick(session, 2099)
    assert.equal(byId(center.inbox(session), 1).read, false)
    center.tick(session, 2100)
    assert.equal(byId(center.inbox(session), 1).read, true, 'второй остров продолжает отсчёт')
    assert.equal(center.inbox(session).length, 1, 'два острова не дублируют запись')
    assert.equal(center.history(session).length, 0)
    center.tick(session, 4000)
    assert.equal(center.inbox(session).length, 1)
    assert.equal(byId(center.inbox(session), 1).read, true)
}

// Одно, группа и все уходят в историю. Закрытие приложением запись не выбрасывает.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram Desktop', { desktopEntry: 'org.telegram.desktop', summary: 'Первое' }), 1000)
    center.ingest(session, item(2, 'Telegram Desktop', { desktopEntry: 'org.telegram.desktop', summary: 'Второе' }), 1010)
    center.ingest(session, item(3, 'Почта', { summary: 'Письмо' }), 1020)
    center.ingest(session, item(4, 'niri', { summary: 'Система' }), 1030)
    const telegram = byId(center.inbox(session), 1).sourceKey
    center.closeUser(session, [1], 1040)
    assert.equal(byId(center.inbox(session), 1), undefined)
    assert.equal(byId(center.history(session), 1).closedBy, 'user')
    center.closeGroup(session, telegram, 1050)
    assert.equal(byId(center.inbox(session), 2), undefined)
    assert.equal(byId(center.history(session), 2).closedBy, 'user')
    assert.equal(byId(center.inbox(session), 3).summary, 'Письмо')
    center.clearAll(session, 1060)
    assert.equal(center.inbox(session).length, 0)
    assert.equal(byId(center.history(session), 3).closedBy, 'user')
    assert.equal(byId(center.history(session), 4).closedBy, 'user')
    const again = center.create()
    center.ingest(again, item(8, 'Почта', { summary: 'От приложения', body: 'Осталось' }), 70)
    center.closeApp(again, 8, 80)
    assert.equal(center.inbox(again).length, 0)
    assert.equal(byId(center.history(again), 8).closedBy, 'app')
    assert.equal(byId(center.history(again), 8).summary, 'От приложения')
    const found = center.searchHistory(again, 'приложен')
    assert.equal(found.length, 1)
    assert.equal(found[0].items[0].id, 8)

    const groups = center.historyGroups(session, '')
    assert.deepEqual(groups.map(group => group.appName), ['niri', 'Почта', 'Telegram Desktop'])
    assert(groups.every(group => group.items.every((record, index) => index === 0 || group.items[index - 1].time >= record.time)))
    const mail = center.searchHistory(session, 'ПИСЬМО')
    assert.equal(mail.length, 1)
    assert.equal(mail[0].items[0].id, 3)
    center.deleteHistory(session, [4])
    assert.equal(byId(center.history(session), 4), undefined)
    center.deleteHistoryGroup(session, telegram)
    assert.equal(byId(center.history(session), 1), undefined)
    assert.equal(byId(center.history(session), 2), undefined)
    assert.equal(byId(center.history(session), 3).id, 3)
    center.clearHistory(session)
    assert.equal(center.history(session).length, 0)
}

// Перезапуск сохраняет записи и не ставит старые в свёрнутый остров.
{
    const session = center.create()
    center.ingest(session, item(1, 'Telegram', { image: '/tmp/nayori-shot.png', actions: [{ id: 'open', text: 'Открыть снимок' }], hasReply: true }), 1000)
    assert.equal(center.banner(session).currentId, 1)
    assert.equal(center.offeredImage(byId(center.inbox(session), 1)), '/tmp/nayori-shot.png')
    assert.equal(center.offeredActions(byId(center.inbox(session), 1)).length, 1)
    const text = writeStore(center.serialize(session, 1000))
    assert(text.indexOf('/tmp/nayori-shot.png') < 0)
    assert(text.indexOf('Открыть снимок') < 0)
    assert(text.indexOf('"actions"') < 0)
    const restored = center.create()
    center.load(restored, fs.readFileSync(path.join(dir, 'notifications.json'), 'utf8'), 1000)
    assert.equal(center.banner(restored).currentId, null, 'запись с диска не занимает баннер')
    assert.equal(center.inbox(restored).length, 1)
    assert.equal(center.offeredImage(byId(center.inbox(restored), 1)), '')
    assert.deepEqual(center.offeredActions(byId(center.inbox(restored), 1)), [])
    assert.equal(byId(center.inbox(restored), 1).hasReply, false)
    center.ingest(restored, item(2, 'Почта'), 2000)
    assert.equal(center.banner(restored).currentId, 2)
    const planted = JSON.parse(text)
    const plant = node => {
        if (Array.isArray(node)) node.forEach(plant)
        else if (node && typeof node === 'object') {
            if (node.id === 1) {
                node.image = '/tmp/nayori-old.png'
                node.actions = [{ id: 'reply', text: 'Старый ответ' }]
                node.hasReply = true
            }
            Object.keys(node).forEach(key => plant(node[key]))
        }
    }
    plant(planted)
    const stale = center.create()
    center.load(stale, JSON.stringify(planted), 1000)
    assert.equal(center.offeredImage(byId(center.inbox(stale), 1) || byId(center.history(stale), 1)), '')
    assert.deepEqual(center.offeredActions(byId(center.inbox(stale), 1) || byId(center.history(stale), 1)), [])
}

// 90 дней снимаются при загрузке. Более свежая запись остаётся.
{
    const session = center.create()
    const now = 2_000_000_000_000
    center.ingest(session, item(1, 'Старое'), now)
    center.ingest(session, item(2, 'Свежее'), now)
    const stale = age(center.serialize(session, now), 1, now - 91 * DAY)
    const kept = age(stale, 2, now - 89 * DAY)
    const restored = center.create()
    center.load(restored, kept, now)
    assert.equal(byId(center.inbox(restored), 1), undefined)
    assert.equal(byId(center.history(restored), 1), undefined)
    assert.ok(byId(center.inbox(restored), 2) || byId(center.history(restored), 2))
    assert.equal(center.banner(restored).currentId, null)
}

// Порча файла даёт пустое состояние и не бросает исключение.
{
    const session = center.create()
    assert.doesNotThrow(() => center.load(session, '{', 10))
    assert.deepEqual(center.inbox(session), [])
    assert.deepEqual(center.history(session), [])
    assert.equal(center.banner(session).currentId, null)
    writeStore('not-json')
    const fromFile = center.create()
    assert.doesNotThrow(() => center.load(fromFile, fs.readFileSync(path.join(dir, 'notifications.json'), 'utf8'), 10))
    assert.equal(center.inbox(fromFile).length, 0)
    assert.equal(center.history(fromFile).length, 0)
}

// «Не беспокоить», только развёрнутый остров и выключенный источник не попадают в баннер.
{
    const session = center.create()
    center.configure(session, { dnd: true }, 0)
    center.ingest(session, item(1, 'Telegram', { desktopEntry: 'org.telegram.desktop', summary: 'Тихое' }), 0)
    assert.equal(center.inbox(session).length, 1)
    assert.equal(center.banner(session).currentId, null)
    center.configure(session, { dnd: false }, 1000)
    center.tick(session, 1000)
    assert.equal(center.banner(session).currentId, null, 'тихое не появляется после режима')
    center.configure(session, { dnd: false }, 2000)
    center.ingest(session, item(2, 'Telegram', { desktopEntry: 'org.telegram.desktop', summary: 'Обычное' }), 2000)
    assert.equal(center.banner(session).currentId, 2)
    const expanded = policy.setMode(session.sources, 'entry:org.telegram.desktop', 'expanded').list
    center.configure(session, { sources: expanded }, 2001)
    assert.equal(center.banner(session).currentId, null)
    assert.equal(center.inbox(session).length, 2)
    const off = policy.setMode(session.sources, 'entry:org.telegram.desktop', 'off').list
    center.configure(session, { sources: off }, 2002)
    center.ingest(session, item(3, 'Telegram', { desktopEntry: 'org.telegram.desktop', summary: 'Скрыто' }), 2003)
    assert.equal(byId(center.inbox(session), 3), undefined)
    center.configure(session, { enabled: false, sources: policy.setMode(session.sources, 'entry:org.telegram.desktop', 'normal').list }, 2004)
    center.ingest(session, item(4, 'Почта', { summary: 'Нет' }), 2005)
    assert.equal(byId(center.inbox(session), 4), undefined)
    assert.equal(center.banner(session).currentId, 2, 'уже принятое обычное уведомление остаётся в баннере')
}

assert.equal(center.storePath({ XDG_STATE_HOME: '/tmp/state', HOME: '/home/user' }), '/tmp/state/nayori/notifications.json')
assert.equal(center.storePath({ HOME: '/home/user' }), '/home/user/.local/state/nayori/notifications.json')

fs.rmSync(dir, { recursive: true, force: true })
console.log('NOTIFICATION_CENTER_PASS')
