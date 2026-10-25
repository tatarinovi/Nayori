function create() { return { records: [], queue: [], current: null, elapsed: 0, pageOpen: false } }
function receive(s, data) {
    let r = s.records.find(function(r) { return r.id === data.id })
    if (r && r.deleted) return
    if (r) {
        Object.assign(r, data)
        if (s.pageOpen) readAll(s)
        return
    }
    r = Object.assign({}, data, { read: s.pageOpen, closed: false, deleted: false, shown: false })
    s.records.unshift(r)
    if (!r.read) s.queue.push(r.id)
}
function eligible(s, id) { return s.records.find(function(r) { return r.id === id && !r.read && !r.closed && !r.deleted && !r.shown }) }
function clean(s) {
    s.queue = s.queue.filter(function(id) { return !!eligible(s, id) })
    if (s.current !== null && !eligible(s, s.current)) { s.current = null; s.elapsed = 0 }
}
function readAll(s) { s.records.forEach(function(r) { if (!r.deleted) r.read = true }); clean(s) }
function page(s, open) { s.pageOpen = open; if (open) readAll(s) }
function close(s, id, deleted) {
    const r = s.records.find(function(r) { return r.id === id })
    if (r) { if (deleted) r.deleted = true; else r.closed = true }
    clean(s)
}
function tick(s, dt, paused) {
    clean(s)
    if (paused || s.pageOpen) return
    let remaining = Math.max(0, dt)
    while (true) {
        if (s.current === null) { s.current = s.queue.shift() ?? null; s.elapsed = 0 }
        if (s.current === null) return
        const used = Math.min(remaining, 5 - s.elapsed)
        s.elapsed += used; remaining -= used
        if (s.elapsed < 5) return
        const r = eligible(s, s.current)
        if (r) r.shown = true
        s.current = null; s.elapsed = 0
        if (remaining <= 0) return
    }
}
