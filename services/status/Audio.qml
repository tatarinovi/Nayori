import QtQuick
import Quickshell
import Quickshell.Services.Pipewire as QsPw
import "../niri"
import "MixerSources.js" as MixerSources

// Клиент уже запущенного PipeWire. Свой демон не поднимается.
// Mute и уровень читаются с узла и обновляются его сигналами.
QtObject {
    id: root

    readonly property var sink: QsPw.Pipewire.defaultAudioSink
    // sink.ready в этой сборке Quickshell остаётся false у уже звучащего узла.
    // Достаточно живого PipeWire и аудиоинтерфейса узла.
    readonly property bool available: QsPw.Pipewire.ready
            && sink !== null
            && sink.audio !== null
    readonly property bool muted: available && sink.audio.muted
    readonly property real level: available ? sink.audio.volume : 0
    readonly property string label: {
        if (!available)
            return ""
        if (muted)
            return "mute"
        var pct = Math.round(level * 100)
        if (!isFinite(pct))
            return ""
        return pct + "%"
    }

    // Потоки воспроизведения. Запись (AudioInStream) сюда не входит.
    // Имя узла постоянно, поэтому группировка не пересобирается, когда
    // приходят properties. Несколько потоков одного приложения — одна строка.
    property var playbackNodes: []
    property var mixerSources: []
    readonly property var applications: groupApplications(playbackNodes)
    readonly property var visibleApplications: MixerSources.visible(applications, mixerSources)
    readonly property var trackedObjects: {
        const list = []
        if (sink)
            list.push(sink)
        const streams = playbackNodes
        for (let i = 0; i < streams.length; i++) {
            if (streams[i] && streams[i] !== sink)
                list.push(streams[i])
        }
        return list
    }

    property QsPw.PwObjectTracker tracker: QsPw.PwObjectTracker {
        objects: root.trackedObjects
    }

    // Смена набора desktop-файлов должна пересчитать уже открытые строки.
    property int desktopEpoch: 0
    property Connections desktopWatcher: Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.desktopEpoch++ }
    }

    function isPlayback(node): bool {
        if (!node || !node.isStream || node.audio === null)
            return false
        const kind = QsPw.PwNodeType.AudioOutStream
        return (node.type & kind) === kind
    }

    function sameNodes(current, next): bool {
        if (!current || current.length !== next.length)
            return false
        for (let i = 0; i < next.length; i++) {
            if (current[i] !== next[i])
                return false
        }
        return true
    }

    function refreshStreams() {
        const out = []
        const model = QsPw.Pipewire.nodes
        const values = model && model.values ? model.values : []
        for (let i = 0; i < values.length; i++) {
            const node = values[i]
            if (isPlayback(node))
                out.push(node)
        }
        out.sort(function(a, b) {
            const left = String(a.name || a.description || "")
            const right = String(b.name || b.description || "")
            return left.localeCompare(right)
        })
        if (!sameNodes(playbackNodes, out))
            playbackNodes = out
    }

    function scheduleStreams() {
        Qt.callLater(function() { root.refreshStreams() })
    }

    function groupApplications(nodes) {
        const order = []
        const byKey = {}
        if (!nodes)
            return order
        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i]
            if (!node)
                continue
            const key = String(node.name || node.description || "Application")
            let group = byKey[key]
            if (!group) {
                group = { key: key, title: key, nodes: [] }
                byKey[key] = group
                order.push(group)
            }
            group.nodes.push(node)
        }
        return order
    }

    function baseName(path): string {
        const text = String(path || "").trim()
        const slash = Math.max(text.lastIndexOf("/"), text.lastIndexOf("\\"))
        return slash >= 0 ? text.slice(slash + 1) : text
    }

    function entryFor(appId) {
        if (typeof DesktopEntries === "undefined" || !DesktopEntries)
            return null
        const id = String(appId || "").trim()
        if (id.length === 0)
            return null
        const bare = id.endsWith(".desktop") ? id.slice(0, id.length - 8) : id
        try {
            let entry = DesktopEntries.byId(bare)
            if (!entry && bare !== id)
                entry = DesktopEntries.byId(id)
            if (!entry)
                entry = DesktopEntries.heuristicLookup(bare)
            if (!entry || entry.noDisplay === true)
                return null
            const name = entry.name === undefined || entry.name === null ? "" : String(entry.name).trim()
            return name.length > 0 ? entry : null
        } catch (error) {
            return null
        }
    }

    // Окно niri с тем же pid, что у потока. app id ведёт в desktop-файл.
    function windowAppId(pid): string {
        const windows = Niri.windows
        const want = Number(pid)
        if (!windows || !isFinite(want) || want <= 0)
            return ""
        for (let i = 0; i < windows.length; i++) {
            const window = windows[i]
            if (!window || Number(window.pid) !== want)
                continue
            const appId = String(window.appId || "").trim()
            if (appId !== "")
                return appId
        }
        return ""
    }

    function streamTitle(nodes, fallback): string {
        if (nodes && nodes.length) {
            const props = nodes[0].properties || {}
            const app = props["application.name"]
            if (app)
                return String(app)
            const node = nodes[0]
            if (node.description)
                return String(node.description)
            if (node.name)
                return String(node.name)
        }
        return fallback || "Application"
    }

    function applicationEntry(nodes) {
        // Чтение держит привязку: имя и значок обновятся, когда дойдут desktop-файлы.
        if (root.desktopEpoch < 0)
            return null
        const props = nodes && nodes.length && nodes[0] ? (nodes[0].properties || {}) : {}
        const candidates = [
            root.windowAppId(props["application.process.id"]),
            props["application.name"],
            root.baseName(props["application.process.binary"])
        ]
        const seen = {}
        for (let i = 0; i < candidates.length; i++) {
            const key = String(candidates[i] || "").trim()
            if (key === "" || seen[key])
                continue
            seen[key] = true
            const entry = root.entryFor(key)
            if (entry)
                return entry
        }
        return null
    }

    function applicationTitle(nodes, fallback): string {
        const entry = root.applicationEntry(nodes)
        if (entry)
            return String(entry.name).trim()
        return root.streamTitle(nodes, fallback)
    }

    function applicationIcon(nodes): string {
        const entry = root.applicationEntry(nodes)
        if (!entry || entry.icon === undefined || entry.icon === null)
            return ""
        return String(entry.icon).trim()
    }

    function applicationDetail(nodes): string {
        if (!nodes || !nodes.length)
            return ""
        if (nodes.length > 1)
            return nodes.length + " streams"
        const props = nodes[0].properties || {}
        const media = String(props["media.name"] || "").trim()
        if (media === "" || /^(playback|audio stream( #\d+)?)$/i.test(media))
            return ""
        return media
    }

    function nodesLevel(nodes): real {
        let sum = 0
        let count = 0
        for (let i = 0; nodes && i < nodes.length; i++) {
            const nodeAudio = nodes[i] && nodes[i].audio
            if (!nodeAudio)
                continue
            sum += nodeAudio.volume
            count++
        }
        return count ? sum / count : 0
    }

    function nodesMuted(nodes): bool {
        let seen = false
        for (let i = 0; nodes && i < nodes.length; i++) {
            const nodeAudio = nodes[i] && nodes[i].audio
            if (!nodeAudio)
                continue
            seen = true
            if (!nodeAudio.muted)
                return false
        }
        return seen
    }

    function nodesLabel(nodes): string {
        if (!nodes || !nodes.length)
            return ""
        if (nodesMuted(nodes))
            return "mute"
        const pct = Math.round(nodesLevel(nodes) * 100)
        if (!isFinite(pct))
            return ""
        return pct + "%"
    }

    function setNodesVolume(nodes, value) {
        if (!nodes || !isFinite(value))
            return
        const level = Math.max(0, Math.min(1, value))
        for (let i = 0; i < nodes.length; i++) {
            const nodeAudio = nodes[i] && nodes[i].audio
            if (nodeAudio)
                nodeAudio.volume = level
        }
    }

    function setNodesMuted(nodes, muted) {
        if (!nodes)
            return
        for (let i = 0; i < nodes.length; i++) {
            const nodeAudio = nodes[i] && nodes[i].audio
            if (nodeAudio)
                nodeAudio.muted = !!muted
        }
    }

    property Instantiator streamCensus: Instantiator {
        model: QsPw.Pipewire.nodes
        delegate: QtObject {
            required property var modelData
            Component.onCompleted: root.scheduleStreams()
            Component.onDestruction: root.scheduleStreams()
        }
    }

    Component.onCompleted: scheduleStreams()

    function setVolume(value) {
        if (available && isFinite(value))
            sink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMuted() {
        if (!available || sink === null || sink.audio === null)
            return
        sink.audio.muted = !sink.audio.muted
    }
}
