pragma ComponentBehavior: Bound

import QtQuick
import "../../services/island/NotificationBanner.js" as Banner
import "../../services/island/NotificationList.js" as List
import "../../services/island/NotificationPolicy.js" as Policy

// Свёрнутый баннер: самое новое подходящее уведомление на dwellMs.
// Срок считает NotificationBanner.select. Прочтение здесь не ставится.
// Значки справа — другие подходящие источники, без приложения в центре.
QtObject {
    id: root
    property var notifications: null
    property int dwellMs: 30000
    property var shown: null
    property var floorTime: null
    property var floorId: null
    property var current: null
    property var pending: []

    function isNewer(item, time, id) {
        const stamp = Number(item.time)
        const base = Number(time)
        if (!isFinite(stamp)) return false
        if (stamp !== base) return stamp > base
        const left = Number(item.id)
        const right = Number(id)
        if (isFinite(left) && isFinite(right)) return left > right
        return String(item.id) > String(id)
    }

    // Те же условия, что у вызывающего select: политика решает режим,
    // quiet липкий с момента приёма, закрытые в центре не стоят.
    function eligible(record, model) {
        if (!record || record.deleted || record.closed || record.quiet) return false
        if (record.live === false || record.loadedFromDisk === true) return false
        const decision = Policy.admit({
            enabled: model ? model.notificationsEnabled : true,
            dnd: false,
            sources: model ? (model.sourceList || model.sources || []) : [],
            record: record
        })
        return !decision.drop && decision.mode === "normal"
    }

    function itemsOf(records, model) {
        const items = []
        for (let i = 0; i < records.length; i++) {
            const record = records[i]
            if (!record || record.deleted) continue
            items.push({
                id: record.id,
                time: record.time,
                eligible: root.eligible(record, model)
            })
        }
        return items
    }

    function iconsFor(records, items, current) {
        const allowed = Object.create(null)
        for (let i = 0; i < items.length; i++)
            if (items[i].eligible === true) allowed[items[i].id] = true
        const others = []
        for (let i = 0; i < records.length; i++) {
            const record = records[i]
            if (!record || record.id === current.id || !allowed[record.id]) continue
            others.push(record)
        }
        others.sort(function(a, b) { return (Number(a.time) - Number(b.time)) || (Number(a.id) - Number(b.id)) })
        return List.pendingSources(others, current)
    }

    function apply(result, pool) {
        if (result.currentId !== null && result.currentId !== undefined) {
            let time = root.floorTime
            for (let i = 0; i < pool.length; i++) {
                if (pool[i].id === result.currentId) time = pool[i].time
            }
            root.shown = { id: result.currentId, until: result.until }
            root.floorTime = time
            root.floorId = result.currentId
            return
        }
        if (result.until !== null && result.until !== undefined && root.shown) {
            root.shown = { id: root.shown.id, until: result.until }
            return
        }
        root.shown = null
    }

    function refresh() {
        const model = root.notifications
        const records = model && model.records ? model.records : []
        const items = root.itemsOf(records, model)
        const now = Date.now()
        let pool = items
        if (!root.shown && root.floorTime !== null)
            pool = items.filter(function(item) { return root.isNewer(item, root.floorTime, root.floorId) })
        let result = Banner.select({ items: pool, now: now, shown: root.shown, dwellMs: root.dwellMs })
        const dropped = root.shown && (result.currentId === null || result.currentId === undefined)
            && (result.until === null || result.until === undefined)
        if (dropped) {
            const floorTime = root.floorTime
            const floorId = root.floorId
            root.shown = null
            pool = items.filter(function(item) { return root.isNewer(item, floorTime, floorId) })
            result = Banner.select({ items: pool, now: now, shown: null, dwellMs: root.dwellMs })
        }
        root.apply(result, pool)
        let current = null
        if (result.currentId !== null && result.currentId !== undefined) {
            for (let i = 0; i < records.length; i++)
                if (records[i] && records[i].id === result.currentId) current = records[i]
        }
        root.current = current
        root.pending = current ? root.iconsFor(records, items, current) : []
        if (!root.expiry) return
        if (current && Number(result.until) > now) {
            root.expiry.interval = Math.max(1, Math.ceil(Number(result.until) - now))
            root.expiry.restart()
        } else if (root.expiry.running) {
            root.expiry.stop()
        }
    }

    // QtObject не принимает дочерние элементы, таймер живёт свойством.
    property Timer expiry: Timer {
        repeat: false
        onTriggered: root.refresh()
    }

    property bool ready: false
    // Ревизия модели приходит в том же проходе, что и пересчёт records.
    // Чтение в этот момент отдаёт старую копию, поэтому обновление на следующем тике.
    property int watchedRevision: notifications ? notifications.revision : 0
    onNotificationsChanged: if (ready) later.restart()
    onWatchedRevisionChanged: if (ready) later.restart()
    property bool notificationsEnabled: !notifications || notifications.notificationsEnabled !== false
    onNotificationsEnabledChanged: if (ready) later.restart()
    property Timer later: Timer {
        interval: 1
        repeat: false
        onTriggered: root.refresh()
    }
    Component.onCompleted: { ready = true; refresh() }
}
