pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// One selected MPRIS player and one lookup shared by all island windows.
QtObject {
    id: root
    property bool testMode: false
    property var testPlayers: []
    property var testCommand: []
    property string cacheDirectory: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/nayori/lyrics"
    readonly property var players: (testMode ? testPlayers : Mpris.players.values).filter(p => !!p.trackTitle)
    property var pinnedPlayer: null
    readonly property var player: {
        if (pinnedPlayer && players.includes(pinnedPlayer)) return pinnedPlayer
        for (const p of players) if (p.isPlaying) return p
        return players.length ? players[0] : null
    }
    function selectPlayer(selected) {
        if (!players.includes(selected)) return
        pinnedPlayer = selected
        syncPosition(true)
    }
    property var consumers: ({})
    property int consumerRevision: 0
    readonly property bool wanted: {
        if (consumerRevision < 0) return false
        return Object.keys(consumers).some(key => consumers[key])
    }
    function consumer(key, shown) {
        if (shown) consumers[key] = true
        else delete consumers[key]
        consumerRevision++
    }
    readonly property var track: ({
        title: player ? player.trackTitle || "" : "",
        artist: player ? player.trackArtist || "" : "",
        album: player ? player.trackAlbum || "" : "",
        duration: player && player.lengthSupported !== false ? Math.max(0, Number(player.length) || 0) : 0,
        trackUrl: player && player.metadata ? String(player.metadata["xesam:url"] || "") : "",
        trackId: player && player.metadata ? String(player.metadata["mpris:trackid"] || "") : ""
    })
    readonly property string trackKey: JSON.stringify(track)
    property bool lyricsEnabled: true
    readonly property var lyrics: root
    property string status: "idle"
    property string source: ""
    property var lines: []
    property string plainText: ""
    property var diagnostics: []
    property bool cached: false
    property real position: 0
    readonly property int currentIndex: {
        if (status !== "synced" || !player || player.positionSupported === false) return -1
        let lo = 0, hi = lines.length
        while (lo < hi) {
            const mid = Math.floor((lo + hi) / 2)
            if (lines[mid].t <= position) lo = mid + 1
            else hi = mid
        }
        return lo - 1
    }
    readonly property string currentLine: currentIndex >= 0 ? lines[currentIndex].text : ""
    readonly property string previousLine: adjacentLine(-1)
    readonly property string nextLine: adjacentLine(1)
    readonly property var currentWords: wordsForLine(currentIndex)
    function adjacentLine(direction) {
        if (status !== "synced") return ""
        for (let i = currentIndex + direction; i >= 0 && i < lines.length; i += direction) {
            if (lines[i].text.trim()) return lines[i].text
        }
        return ""
    }
    function wordsForLine(index) {
        if (status !== "synced" || index < 0 || index >= lines.length || !lines[index].text.trim()) return []
        const line = lines[index]
        // Keep whitespace in the pieces, so joining their text reproduces the line.
        const pieces = line.text.match(/\s*\S+\s*/g) || []
        let end = track.duration > line.t ? track.duration : line.t + 4
        for (let i = index + 1; i < lines.length; i++) {
            // A timed blank is a real end of the sung line, unlike a display neighbour.
            if (lines[i].t > line.t) { end = lines[i].t; break }
        }
        if (Array.isArray(line.w) && line.w.length === pieces.length) {
            const timed = []
            let previous = line.t
            let valid = true
            for (let i = 0; i < pieces.length; i++) {
                const word = line.w[i]
                const at = typeof word === "number" ? word : word && (word.at !== undefined ? word.at : word.t)
                const correctText = !word || typeof word !== "object" || word.text === undefined || (typeof word.text === "string" && word.text.trim() === pieces[i].trim())
                if (typeof at !== "number" || !isFinite(at) || at < previous || at >= end || !correctText) { valid = false; break }
                timed.push({text:pieces[i], at:at})
                previous = at
            }
            if (valid) return timed
        }
        const weights = pieces.map(piece => Math.max(1, (piece.match(/[aeiouyаеёиоуыэюяäöüéèêàáâíîóôúû]/gi) || []).length))
        const total = weights.reduce((sum, weight) => sum + weight, 0)
        let consumed = 0
        return pieces.map((text, i) => {
            const at = line.t + (end - line.t) * consumed / total
            consumed += weights[i]
            return {text:text, at:at}
        })
    }
    property var memory: ({})
    property int generation: 0
    function resetTrack() {
        generation++
        settle.stop(); deadline.stop()
        worker.running = false
        status = "idle"; source = ""; lines = []; plainText = ""; diagnostics = []; cached = false
        syncPosition(false)
        if (wanted && track.title) settle.restart()
    }
    function syncPosition(notify) {
        if (!player) { position = 0; return }
        if (notify && !testMode && player.positionSupported !== false) player.positionChanged()
        position = Math.max(0, Number(player.position) || 0)
    }
    function ensure() {
        if (!wanted || !track.title || worker.running) return
        const entry = memory[trackKey]
        if (entry && Date.now() - entry.at < (entry.data.status === "error" ? 15000 : entry.data.status === "notfound" ? 300000 : 86400000)) {
            apply(entry.data)
            return
        }
        status = "loading"
        worker.jobKey = trackKey
        worker.jobGeneration = generation
        worker.payload = JSON.stringify(track)
        worker.stdinEnabled = true
        worker.command = testMode ? testCommand : ["python3", Quickshell.shellPath("scripts/lyrics-fetch.py"), "--cache-dir", cacheDirectory]
        worker.running = true
        deadline.restart()
    }
    function apply(data) {
        const allowed = ["synced", "plain", "instrumental", "notfound", "error"]
        status = allowed.includes(data.status) ? data.status : "error"
        source = typeof data.source === "string" ? data.source : ""
        lines = Array.isArray(data.lines) ? data.lines.filter(l => typeof l.t === "number" && isFinite(l.t) && l.t >= 0 && typeof l.text === "string").sort((a,b) => a.t-b.t) : []
        plainText = typeof data.plainText === "string" ? data.plainText : ""
        diagnostics = Array.isArray(data.diagnostics) ? data.diagnostics : []
        cached = data.cached === true
        syncPosition(true)
    }
    function accept(text) {
        if (!wanted || worker.jobKey !== trackKey || worker.jobGeneration !== generation) return
        let data
        try { data = JSON.parse(text) } catch (error) { data = {status:"error"} }
        const keys = Object.keys(memory)
        if (keys.length >= 50) delete memory[keys[0]]
        memory[trackKey] = {at:Date.now(),data:data}
        apply(data)
    }
    onTrackKeyChanged: resetTrack()
    onPlayerChanged: syncPosition(false)
    onWantedChanged: {
        if (wanted) { syncPosition(true); settle.restart() }
        else {
            settle.stop(); deadline.stop()
            generation++; worker.running = false
            if (status === "loading") status = "idle"
        }
    }
    property Connections playback: Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() { root.syncPosition(false) }
        function onPlaybackStateChanged() { root.syncPosition(true) }
    }
    property Timer settle: Timer { interval: 350; onTriggered: root.ensure() }
    property Timer positionClock: Timer {
        interval: root.status === "synced" ? 80 : 250
        repeat: true
        running: root.wanted && !!root.player && root.player.isPlaying && root.player.positionSupported !== false
        onTriggered: root.syncPosition(true)
    }
    property Timer retryClock: Timer {
        interval: root.status === "error" ? 15000 : 60000; repeat: true
        running: root.wanted && (root.status === "error" || root.status === "notfound")
        onTriggered: root.ensure()
    }
    property Timer deadline: Timer {
        interval: 68000
        onTriggered: {
            root.generation++
            root.worker.running = false
            root.status = "error"
        }
    }
    property Process worker: Process {
        property string jobKey: ""
        property int jobGeneration: -1
        property string payload: ""
        onStarted: { root.worker.write(payload + "\n"); payload = ""; root.worker.stdinEnabled = false }
        stdout: StdioCollector { onStreamFinished: root.accept(text) }
        onExited: {
            if (jobGeneration !== root.generation || jobKey !== root.trackKey) {
                if (root.wanted && root.status === "idle") root.settle.restart()
                return
            }
            root.deadline.stop()
            if (root.status === "loading") root.accept('{"status":"error"}')
        }
    }
}
