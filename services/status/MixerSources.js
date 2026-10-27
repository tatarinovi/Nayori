.pragma library

// Каталог источников микшера. Ключ — стабильное node.name.
// hidden прячет строку в попапе, запись остаётся в настройках.

function cleanKey(value) {
    const text = value === undefined || value === null ? "" : String(value).trim()
    if (text.length === 0 || text.length > 256 || /[\x00-\x1f]/.test(text))
        return ""
    return text
}

function cleanTitle(value, fallback) {
    const text = value === undefined || value === null ? "" : String(value).trim()
    if (text.length === 0 || text.length > 256 || /[\x00-\x1f]/.test(text))
        return fallback
    return text
}

function normalize(value) {
    const out = []
    const seen = {}
    if (!Array.isArray(value))
        return out
    for (let i = 0; i < value.length && out.length < 200; i++) {
        const item = value[i]
        if (!item || typeof item !== "object")
            continue
        const key = cleanKey(item.key)
        if (key === "" || seen[key])
            continue
        seen[key] = true
        out.push({
            key: key,
            title: cleanTitle(item.title, key),
            hidden: item.hidden === true
        })
    }
    return out
}

function same(left, right) {
    const a = normalize(left)
    const b = normalize(right)
    if (a.length !== b.length)
        return false
    for (let i = 0; i < a.length; i++) {
        if (a[i].key !== b[i].key || a[i].title !== b[i].title || a[i].hidden !== b[i].hidden)
            return false
    }
    return true
}

function merge(current, seen) {
    const list = normalize(current)
    const index = {}
    for (let i = 0; i < list.length; i++)
        index[list[i].key] = i
    const incoming = Array.isArray(seen) ? seen : []
    let changed = false
    for (let i = 0; i < incoming.length && list.length < 200; i++) {
        const item = incoming[i]
        const key = cleanKey(item && item.key)
        if (key === "")
            continue
        const title = cleanTitle(item.title, key)
        const at = index[key]
        if (at === undefined) {
            list.push({ key: key, title: title, hidden: false })
            index[key] = list.length - 1
            changed = true
            continue
        }
        if (list[at].title !== title) {
            list[at] = { key: key, title: title, hidden: list[at].hidden }
            changed = true
        }
    }
    return { list: list, changed: changed }
}

function setHidden(current, key, hidden) {
    const want = cleanKey(key)
    const list = normalize(current)
    const next = []
    for (let i = 0; i < list.length; i++) {
        if (list[i].key === want)
            next.push({ key: list[i].key, title: list[i].title, hidden: hidden === true })
        else
            next.push(list[i])
    }
    return next
}

function isHidden(current, key) {
    const want = cleanKey(key)
    const list = Array.isArray(current) ? current : []
    for (let i = 0; i < list.length; i++) {
        if (list[i] && cleanKey(list[i].key) === want)
            return list[i].hidden === true
    }
    return false
}

function visible(groups, sources) {
    const out = []
    const list = Array.isArray(groups) ? groups : []
    for (let i = 0; i < list.length; i++) {
        const group = list[i]
        if (!group || isHidden(sources, group.key))
            continue
        out.push(group)
    }
    return out
}

function countLabel(count) {
    const n = Math.abs(count) % 100
    const n1 = n % 10
    if (n > 10 && n < 20)
        return count + " источников"
    if (n1 > 1 && n1 < 5)
        return count + " источника"
    if (n1 === 1)
        return count + " источник"
    return count + " источников"
}

function summary(list) {
    const sources = normalize(list)
    let hidden = 0
    for (let i = 0; i < sources.length; i++) {
        if (sources[i].hidden)
            hidden++
    }
    if (sources.length === 0)
        return "Пока пусто"
    if (hidden === 0)
        return countLabel(sources.length)
    return "скрыто " + hidden + " из " + sources.length
}
