// Очередь диалога подтверждения. Пароль сюда не входит: его держит только поле ввода.
//
// Одновременно на экране один запрос. Остальные ждут в queue и не подменяют поле.
// follow() показывает запрос, который служба сделала текущим, и забывает прежний экран,
// не стирая чужие записи в очереди. settle() закрывает один cookie, не трогая соседние.

function create() {
    return { active: null, queue: [], serial: 0 }
}

function identityTitle(identity) {
    if (!identity) return "Пользователь"
    const raw = String(identity.displayName || identity.name || "")
    const full = raw.split(",")[0].replace(/\s+/g, " ").trim()
    const login = String(identity.name || "").trim()
    const title = full || login || "Пользователь"
    if (identity.isGroup) return title + ", группа"
    if (login && full && login !== full) return full + " (" + login + ")"
    return title
}

function promptHint(prompt) {
    const text = String(prompt || "").trim().replace(/:$/, "")
    if (!text) return ""
    const generic = ["password", "пароль", "passphrase"]
    if (generic.indexOf(text.toLowerCase()) >= 0) return ""
    return text
}

function copyIdentity(identity) {
    const name = String(identity && identity.name || "").trim()
    const displayName = String(identity && (identity.displayName || identity.name) || "")
    const id = identity && identity.id !== undefined && identity.id !== null ? identity.id : name
    return { id: id, name: name, displayName: displayName, isGroup: !!(identity && identity.isGroup) }
}

function requestFrom(input, generation) {
    const identities = (input.identities || []).map(copyIdentity).filter(function(item) {
        return item.name || item.displayName || String(item.id) !== ""
    })
    let selected = 0
    if (input.selectedId !== undefined && input.selectedId !== null) {
        const index = identities.findIndex(function(item) { return String(item.id) === String(input.selectedId) })
        if (index >= 0) selected = index
    }
    return {
        cookie: String(input.cookie || ""),
        message: String(input.message || ""),
        actionId: String(input.actionId || ""),
        iconName: String(input.iconName || ""),
        identities: identities,
        selected: selected,
        prompt: String(input.prompt || ""),
        responseRequired: !!input.responseRequired,
        responseVisible: !!input.responseVisible,
        failed: false,
        errorText: "",
        infoText: "",
        phase: "active",
        generation: generation
    }
}

function queuedIndex(state, cookie) {
    return state.queue.findIndex(function(item) { return item.cookie === cookie })
}

function busy(request) {
    return !!request && (request.phase === "active" || request.phase === "failed")
}

function begin(state, input) {
    const cookie = String(input && input.cookie || "")
    if (!cookie) return { ok: false, reason: "cookie" }
    if (state.active && state.active.cookie === cookie && busy(state.active)) {
        const selected = state.active.identities[state.active.selected]
        const fresh = requestFrom(Object.assign({}, input, {
            selectedId: input.selectedId !== undefined ? input.selectedId : (selected ? selected.id : undefined)
        }), state.active.generation)
        fresh.failed = state.active.failed
        fresh.errorText = state.active.errorText
        fresh.infoText = state.active.infoText
        fresh.phase = state.active.phase
        state.active = fresh
        return { ok: true, queued: false, generation: fresh.generation }
    }
    const existing = queuedIndex(state, cookie)
    if (existing >= 0) {
        const generation = state.queue[existing].generation
        state.queue[existing] = requestFrom(input, generation)
        return { ok: true, queued: true, generation: generation }
    }
    state.serial += 1
    const created = requestFrom(input, state.serial)
    if (busy(state.active)) {
        state.queue.push(created)
        return { ok: true, queued: true, generation: created.generation }
    }
    state.active = created
    return { ok: true, queued: false, generation: created.generation }
}

function follow(state, input) {
    const cookie = String(input && input.cookie || "")
    if (!cookie) return { ok: false, reason: "cookie" }
    if (state.active && state.active.cookie !== cookie) {
        state.active.phase = "left"
        state.active.responseRequired = false
        state.active = null
    }
    const existing = queuedIndex(state, cookie)
    if (existing >= 0) state.queue.splice(existing, 1)
    return begin(state, input)
}

function settle(state, cookie, phase) {
    const index = queuedIndex(state, cookie)
    if (index >= 0) {
        state.queue.splice(index, 1)
        return "queued"
    }
    if (!state.active || state.active.cookie !== cookie) return "missing"
    if (!busy(state.active)) return "already"
    state.active.phase = phase
    state.active.responseRequired = false
    state.serial += 1
    state.active.generation = state.serial
    return "active"
}

function advance(state) {
    if (busy(state.active)) return false
    state.active = null
    const next = state.queue.shift()
    if (!next) return true
    state.serial += 1
    next.generation = state.serial
    next.phase = "active"
    next.failed = false
    state.active = next
    return true
}

function fail(state, cookie, message) {
    if (!state.active || state.active.cookie !== cookie || !busy(state.active)) return false
    state.active.failed = true
    state.active.phase = "failed"
    if (message) state.active.errorText = String(message)
    state.active.responseRequired = false
    state.serial += 1
    state.active.generation = state.serial
    return true
}

function prompt(state, cookie, fields) {
    if (!state.active || state.active.cookie !== cookie || !busy(state.active)) return false
    const next = fields || {}
    if (next.prompt !== undefined) state.active.prompt = String(next.prompt || "")
    if (next.responseRequired !== undefined) state.active.responseRequired = !!next.responseRequired
    if (next.responseVisible !== undefined) state.active.responseVisible = !!next.responseVisible
    return true
}

function note(state, cookie, message, isError) {
    if (!state.active || state.active.cookie !== cookie || !busy(state.active)) return false
    const text = String(message || "")
    if (isError) state.active.errorText = text
    else state.active.infoText = text
    return true
}

function selectIdentity(state, cookie, id) {
    if (!state.active || state.active.cookie !== cookie || !busy(state.active)) return false
    const index = state.active.identities.findIndex(function(item) { return String(item.id) === String(id) })
    if (index < 0 || index === state.active.selected) return false
    state.active.selected = index
    state.active.failed = false
    state.active.errorText = ""
    state.active.infoText = ""
    state.active.prompt = ""
    state.active.responseRequired = false
    state.active.responseVisible = false
    state.serial += 1
    state.active.generation = state.serial
    return true
}

function invalidateInput(state) {
    if (!busy(state.active)) return false
    state.serial += 1
    state.active.generation = state.serial
    return true
}

function canSubmit(state, cookie, generation) {
    const active = state.active
    if (!busy(active) || active.cookie !== cookie) return false
    if (active.generation !== generation) return false
    return !!active.responseRequired
}

function shown(state) {
    return busy(state.active) ? state.active : null
}
