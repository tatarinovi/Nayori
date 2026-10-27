pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    required property var settings
    required property var notifications
    property bool enabled: true
    property bool ready: false
    property bool recorderAvailable: false
    property bool screenshotAvailable: false
    property string state: "idle"
    property string mode: "shot"
    property string output: ""
    property string source: ""
    property int logicalWidth: 0
    property int logicalHeight: 0
    property var area: ({x: 0, y: 0, w: 0, h: 0})
    property var marks: []
    property var redoMarks: []
    property string tool: "arrow"
    property string ink: "#CAA7AA"
    property int lineSize: 3
    property var options: ({})
    property string error: ""
    property bool paused: false
    property int elapsed: 0
    property int countdown: 0
    property double recordSince: 0
    property double accumulated: 0
    property int localNotificationId: -1000
    readonly property bool editing: state === "select" || state === "edit" || state === "setup" || state === "countdown" || state === "saving"
    readonly property bool recording: state === "recording" || state === "stopping"
    readonly property bool controlsVisible: recording || state === "starting" || state === "countdown"
    readonly property string timeText: state === "countdown" ? String(countdown)
        : Math.floor(elapsed / 60).toString().padStart(2, "0") + ":" + (elapsed % 60).toString().padStart(2, "0")

    function send(action, values) {
        if (!ready || !worker.running) { root.error = "Служба захвата недоступна"; return false }
        worker.write(JSON.stringify(Object.assign({action: action}, values || {})) + "\n")
        return true
    }
    function defaults() {
        const result = {}
        const values = settings.values
        Object.keys(values).filter(key => key.indexOf("capture") === 0).forEach(key => result[key] = values[key])
        return result
    }
    function begin(kind, name) {
        if (kind === "video" && recording) { stop(); return }
        if (state !== "idle") return
        if (!ready || !screenshotAvailable) { notify("Захват недоступен", "Для захвата нужны grim, Python Pillow и wl-clipboard."); return }
        if (kind === "video" && !recorderAvailable) { notify("Запись недоступна", "Установите gpu-screen-recorder версии 6 или новее."); return }
        options = defaults()
        ink = options.captureColor || "#CAA7AA"
        mode = kind === "video" ? "video" : "shot"
        output = name
        source = ""
        area = {x: 0, y: 0, w: 0, h: 0}
        marks = []; redoMarks = []; tool = "arrow"; error = ""
        paused = false; elapsed = 0; accumulated = 0
        state = "preparing"
        prepareDelay.restart()
    }
    function select(rect) {
        if (state !== "select" && state !== "edit" && state !== "setup") return
        const x = Math.max(0, Math.min(logicalWidth - 2, Math.round(rect.x)))
        const y = Math.max(0, Math.min(logicalHeight - 2, Math.round(rect.y)))
        area = {x: x, y: y, w: Math.max(2, Math.min(logicalWidth - x, Math.round(rect.w))), h: Math.max(2, Math.min(logicalHeight - y, Math.round(rect.h)))}
    }
    function next() {
        if (area.w < 2 || area.h < 2) return
        if (state === "select") state = mode === "shot" ? "edit" : "setup"
    }
    function wholeScreen() { select({x: 0, y: 0, w: logicalWidth, h: logicalHeight}) }
    function addMark(mark) {
        if (state !== "edit") return
        marks = marks.concat([Object.assign({}, mark, {color: ink, size: lineSize})])
        redoMarks = []
    }
    function undo() { if (marks.length) { redoMarks = redoMarks.concat([marks[marks.length - 1]]); marks = marks.slice(0, -1) } }
    function redo() { if (redoMarks.length) { marks = marks.concat([redoMarks[redoMarks.length - 1]]); redoMarks = redoMarks.slice(0, -1) } }
    function reselect() { if (state === "edit" || state === "setup") { marks = []; redoMarks = []; state = "select" } }
    function changeOption(key, value) { options = Object.assign({}, options, {[key]: value}) }
    function save(copy) {
        if (state !== "edit") return
        error = ""
        if (send("export", {rect: area, marks: marks, options: options, copy: copy})) state = "saving"
    }
    function start() {
        if (state !== "setup") return
        countdown = Number(options.captureCountdown) || 0
        state = "countdown"
        if (countdown > 0) countdownTimer.restart()
        else launchRecording()
    }
    function launchRecording() { countdownTimer.stop(); state = "starting"; startDelay.restart() }
    function cancel() {
        if (recording || state === "starting" || state === "saving") return
        if (state === "countdown") { countdownTimer.stop(); state = "setup"; return }
        prepareDelay.stop()
        send("cancel")
        state = "idle"; source = ""; marks = []; redoMarks = []
    }
    function pause() { if (state === "recording") send("pause") }
    function stop() { if (state === "recording") { state = "stopping"; send("stop") } }
    function notify(summary, body) {
        // Reuse the shell's notification queue even when its D-Bus host is disabled.
        notifications.receive({id: localNotificationId--, appName: "Захват экрана", appIcon: "camera-photo", summary: summary, body: body, urgency: 1, actions: []})
    }
    function consume(line) {
        try {
            const value = JSON.parse(line)
            if (value.event === "ready") {
                ready = true; screenshotAvailable = value.screenshot; recorderAvailable = value.recorder
            } else if (value.event === "prepared") {
                if (state !== "preparing") return
                source = value.source; logicalWidth = value.width; logicalHeight = value.height
                state = "select"
            } else if (value.event === "recording") {
                if (state !== "starting") return
                state = "recording"; recordSince = Date.now(); accumulated = 0; elapsed = 0; paused = false
            } else if (value.event === "paused") {
                if (value.paused) accumulated += Date.now() - recordSince
                else recordSince = Date.now()
                paused = value.paused
            } else if (value.event === "saved") {
                if (value.copyError) console.warn("Capture clipboard:", value.copyError)
                state = "idle"; source = ""; marks = []; redoMarks = []
                const summary = value.kind === "video" ? (value.copied ? "Запись сохранена и скопирована" : "Запись сохранена")
                    : value.copied ? "Скриншот сохранён и скопирован" : "Скриншот сохранён"
                notify(summary, value.warning ? value.warning + "\n" + value.path : value.path)
            } else if (value.event === "error") {
                error = value.message || "Захват не завершён"
                if (state === "saving") state = "edit"
                else if (value.action === "pause") { /* Keep the running recording and stop control. */ }
                else { state = "idle"; source = "" }
                notify("Не удалось завершить захват", error + (value.path ? "\n" + value.path : ""))
                if (value.details) console.warn("Capture recorder:", value.details)
            }
        } catch (failure) { console.warn("Capture: invalid worker response", failure) }
    }
    Process {
        id: worker
        command: ["python3", "-u", Qt.resolvedUrl("capture_worker.py").toString().replace("file://", "")]
        running: root.enabled
        stdinEnabled: true
        stdout: SplitParser { onRead: data => root.consume(data) }
        onExited: {
            root.ready = false
            if (root.state !== "idle") root.notify("Захват остановлен", "Служба захвата завершилась. Проверьте папку записи.")
            root.state = "idle"
            if (root.enabled) retry.restart()
        }
    }
    Timer { id: retry; interval: 3000; onTriggered: if (root.enabled && !worker.running) worker.running = true }
    Timer { id: prepareDelay; interval: 0; onTriggered: if (!root.send("prepare", {output: root.output})) root.state = "idle" }
    Timer { id: startDelay; interval: 180; onTriggered: if (!root.send("start", {rect: root.area, options: root.options})) root.state = "idle" }
    Timer {
        id: countdownTimer
        interval: 1000; repeat: true
        onTriggered: { root.countdown--; if (root.countdown <= 0) root.launchRecording() }
    }
    Timer {
        interval: 200; running: root.recording; repeat: true
        onTriggered: root.elapsed = Math.floor((root.accumulated + (root.paused ? 0 : Date.now() - root.recordSince)) / 1000)
    }
}
