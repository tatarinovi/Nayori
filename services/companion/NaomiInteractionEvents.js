// Pure detectors. The controller owns the queue, cooldowns and permission to speak.
// MPRIS reports playback, so these events mean play/resume and pause/stop/close,
// rather than opening or closing an application window.
function create() {
    return {
        musicKnown: false, musicPlaying: false, musicSources: {},
        hoverInside: false, hoverSeconds: 0, hoverFired: false,
        pointerX: null, pointerY: null
    }
}

function isYandexMusic(player) {
    if (!player) return false
    const identity = String(player.identity || "").toLowerCase()
    const desktop = String(player.desktopEntry || "").toLowerCase()
    const service = String(player.dbusName || "").toLowerCase()
    // Match both the official client and Linux clients such as cucumber-sp's.
    const name = /yandex[\s._-]*music|яндекс[\s._-]*музык/
    if (name.test(identity) || name.test(desktop) || name.test(service)) return true
    // Browsers identify themselves, not their site. Only the actual track URL
    // distinguishes Yandex Music from other media playing in the same browser.
    const url = String(player.trackUrl || "").toLowerCase()
    return /^https?:\/\/music\.yandex\.(ru|com|by|kz|uz|com\.tr)(?:[\/:?#]|$)/.test(url)
}

function music(s, players) {
    const sources = {}
    let playing = false
    for (const p of (Array.isArray(players) ? players : [])) {
        if (!p) continue
        const key = String(p.dbusName || p.desktopEntry || p.identity || "")
        // A browser may briefly clear its track metadata between tracks. Keep
        // its known source for that gap, but discard it on a different URL or
        // removal of the player. Track changes must not look like stop/start.
        const known = isYandexMusic(p) || (!!key && !!s.musicSources[key] && !p.trackUrl)
        if (key && known) sources[key] = true
        if (known && p.isPlaying === true) playing = true
    }
    s.musicSources = sources
    const changed = s.musicKnown && playing !== s.musicPlaying
    s.musicKnown = true
    s.musicPlaying = playing
    return changed ? (playing ? "musicStart" : "musicStop") : ""
}

function move(s, x, y) {
    if (!isFinite(x) || !isFinite(y)) return
    if (s.pointerX !== x || s.pointerY !== y) s.hoverSeconds = 0
    s.pointerX = x
    s.pointerY = y
}

// One event per visit: moving after a reaction does not arm another one.
// Disabled/hidden companions start a fresh visit when enabled again.
function hover(s, dt, env) {
    const inside = !!(env && env.enabled && env.inside)
    if (!inside) {
        s.hoverInside = false
        s.hoverSeconds = 0
        s.hoverFired = false
        s.pointerX = null
        s.pointerY = null
        return false
    }
    if (!s.hoverInside) {
        s.hoverInside = true
        s.hoverSeconds = 0
        return false
    }
    if (s.hoverFired) return false
    s.hoverSeconds += Math.max(0, Number(dt) || 0)
    if (s.hoverSeconds <= 5) return false
    s.hoverFired = true
    return true
}
