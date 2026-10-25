import QtQuick
import Quickshell
import Quickshell.Io
import "PalettePick.js" as PalettePick

QtObject {
    id: root
    // Not a singleton. The shell constructs one and binds source to a file URL.
    // ColorQuantizer fits the image in a 64×64 box (long edge 64 when larger)
    // and returns 8 median-cut buckets. It has no weights and skips only
    // alpha 0; partial transparency is quantized as opaque. sourceMtime is
    // one stat(1) second value. The same contentId is not quantized again.
    // One quantize feeds the accent and the dark neutrals. background,
    // surface, and surfaceAlt are readonly. neutralFallbackUsed keeps the
    // authored graphite (#121217, #4F4F57, #443D4E) when the read fails or
    // the image has no usable neutral. fallbackUsed is only the accent.
    property url source

    property color _accent: "#C0AFD1"
    property var _candidates: [{ color: "#C0AFD1", share: 1 }]
    property color _background: "#121217"
    property color _surface: "#4F4F57"
    property color _surfaceAlt: "#443D4E"
    property string _sourcePath: ""
    property string _sourceMtime: ""
    property string _contentId: ""
    property string _error: ""
    property bool _fallbackUsed: true
    property bool _neutralFallbackUsed: true
    property bool _ready: false
    readonly property color accent: _accent
    readonly property var candidates: _candidates
    readonly property color background: _background
    readonly property color surface: _surface
    readonly property color surfaceAlt: _surfaceAlt
    readonly property string sourcePath: _sourcePath
    readonly property string sourceMtime: _sourceMtime
    readonly property string contentId: _contentId
    readonly property string error: _error
    readonly property bool fallbackUsed: _fallbackUsed
    readonly property bool neutralFallbackUsed: _neutralFallbackUsed
    readonly property bool ready: _ready

    property int generation: 0
    property int statGeneration: -1
    property bool statExited: false
    property bool statCollected: false
    property int statCode: -1
    property string statText: ""
    property string statPath: ""
    property int quantTicket: -1
    property string quantPath: ""
    property string quantMtime: ""
    property string quantBytes: ""

    function reload() { root.schedule() }
    function schedule() {
        root.generation++
        root.quantTicket = -1
        root.dispatch(root.generation)
    }
    function filePath(value) {
        let text = String(value === undefined || value === null ? "" : value)
        if (text === "" || text === "undefined" || text.indexOf("file://") !== 0) return ""
        const hash = text.indexOf("#")
        if (hash >= 0) text = text.slice(0, hash)
        const query = text.indexOf("?")
        if (query >= 0) text = text.slice(0, query)
        text = text.slice("file://".length)
        try { text = decodeURIComponent(text) } catch (failure) { return "" }
        return text.charAt(0) === "/" ? text : ""
    }
    function extension(path) {
        const slash = path.lastIndexOf("/")
        const name = slash >= 0 ? path.slice(slash + 1) : path
        const dot = name.lastIndexOf(".")
        if (dot <= 0) return ""
        return name.slice(dot + 1).toLowerCase()
    }
    function accepted(ext) {
        return ext === "png" || ext === "jpg" || ext === "jpeg" || ext === "webp"
    }
    function dispatch(ticket) {
        if (ticket !== root.generation) return
        const path = root.filePath(root.source)
        if (path === "") {
            const text = String(root.source === undefined || root.source === null ? "" : root.source)
            const message = text === "" || text === "undefined" ? "Источник обоев не задан." : "Нужен локальный файл обоев."
            root.apply(ticket, "", "", "", message, PalettePick.rank([]))
            return
        }
        if (!root.accepted(root.extension(path))) {
            root.apply(ticket, path, "", "", "Формат изображения не поддерживается.", PalettePick.rank([]))
            return
        }
        if (root.statGeneration >= 0) return
        root.statGeneration = ticket
        root.statPath = path
        root.statExited = false
        root.statCollected = false
        root.statCode = -1
        root.statText = ""
        probe.command = ["stat", "-c", "%Y %s", "--", path]
        probe.running = true
    }
    function finishStat() {
        if (!root.statExited || !root.statCollected || root.statGeneration < 0) return
        const ticket = root.statGeneration
        const path = root.statPath
        const code = root.statCode
        const text = root.statText
        root.statGeneration = -1
        if (ticket !== root.generation) {
            root.dispatch(root.generation)
            return
        }
        if (code !== 0) {
            root.apply(ticket, path, "", "", "Файл обоев не найден.", PalettePick.rank([]))
            return
        }
        const lines = String(text || "").trim().split("\n")
        const parts = lines[lines.length - 1].trim().split(/\s+/)
        if (parts.length !== 2 || !/^\d+$/.test(parts[0]) || !/^\d+$/.test(parts[1])) {
            root.apply(ticket, path, "", "", "Не удалось прочитать файл обоев.", PalettePick.rank([]))
            return
        }
        const id = path + ":" + parts[0] + ":" + parts[1]
        if (id === root._contentId && root._ready) return
        root.quantTicket = ticket
        root.quantPath = path
        root.quantMtime = parts[0]
        root.quantBytes = parts[1]
        let address = String(root.source || "")
        const hash = address.indexOf("#")
        if (hash >= 0) address = address.slice(0, hash)
        const query = address.indexOf("?")
        if (query >= 0) address = address.slice(0, query)
        sampler.source = address + "?nayoriAccent=" + ticket
    }
    function channel(value) {
        const number = Number(value)
        const byte = number > 1 ? Math.round(number) : Math.round((isFinite(number) ? number : 0) * 255)
        const clamped = Math.max(0, Math.min(255, byte))
        const hex = clamped.toString(16).toUpperCase()
        return hex.length === 1 ? "0" + hex : hex
    }
    function samples() {
        const colors = sampler.colors
        const out = []
        if (!colors) return out
        for (let i = 0; i < colors.length; i++) {
            const value = colors[i]
            if (value && typeof value.r === "number" && typeof value.g === "number" && typeof value.b === "number") {
                const alpha = typeof value.a === "number" ? value.a : 1
                out.push({ color: "#" + root.channel(value.r) + root.channel(value.g) + root.channel(value.b), share: 0, alpha: alpha })
            } else {
                out.push({ color: String(value), share: 0 })
            }
        }
        return out
    }
    function consumeColors() {
        const ticket = root.quantTicket
        if (ticket < 0 || ticket !== root.generation) return
        if (String(sampler.source).indexOf("nayoriAccent=" + ticket) < 0) return
        const path = root.quantPath
        const mtime = root.quantMtime
        const bytes = root.quantBytes
        root.quantTicket = -1
        let ranked
        let message = ""
        const found = root.samples()
        try {
            ranked = PalettePick.rank(found)
        } catch (failure) {
            ranked = PalettePick.rank([])
            message = "Не удалось прочитать цвета обоев."
        }
        if (!found.length) message = "Не удалось прочитать цвета обоев."
        root.apply(ticket, path, mtime, bytes, message, message === "" ? ranked : PalettePick.rank([]))
    }
    function apply(ticket, path, mtime, bytes, message, ranked) {
        if (ticket !== root.generation) return
        root._sourcePath = path
        root._sourceMtime = mtime
        root._contentId = path !== "" && mtime !== "" && bytes !== "" ? path + ":" + mtime + ":" + bytes : ""
        const failed = message !== ""
        root._error = message
        root._accent = ranked.accent
        root._candidates = ranked.candidates
        root._fallbackUsed = !!ranked.fallbackUsed || failed
        root._background = failed ? "#121217" : ranked.background
        root._surface = failed ? "#4F4F57" : ranked.surface
        root._surfaceAlt = failed ? "#443D4E" : ranked.surfaceAlt
        root._neutralFallbackUsed = failed || !!ranked.neutralFallbackUsed
        root._ready = true
    }
    onSourceChanged: root.schedule()
    Component.onCompleted: root.schedule()

    property ColorQuantizer sampler: ColorQuantizer {
        depth: 3
        rescaleSize: 64
        onColorsChanged: root.consumeColors()
    }
    property Process probe: Process {
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.statText = text
                root.statCollected = true
                root.finishStat()
            }
        }
        onExited: function(code) {
            root.statCode = code
            root.statExited = true
            root.finishStat()
        }
    }
}
