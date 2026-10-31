pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// Writes a niri config through niri_config_apply.py.
// live is a separate request and is never sent on its own at startup.
QtObject {
    id: root

    property bool watchOutputs: false
    property bool ready: false
    property bool busy: false
    property string error: ""
    property string notice: ""
    property string configPath: ""
    property bool readerMismatch: false
    property bool validateAvailable: false
    property var outputs: []
    property var liveOutputs: []
    property string modesError: ""
    property var mouse: ({})
    property var touchpad: ({})
    property var keyboard: ({})
    property var warnings: []
    property string pendingId: ""
    property double deadlineMs: 0
    property double nowMs: 0
    property int confirmSeconds: 15
    property int revision: 0
    property bool reloadSession: false
    property bool expiring: false
    readonly property bool pending: pendingId !== ""
    readonly property int secondsLeft: !pending || deadlineMs <= 0 ? 0
        : Math.max(0, Math.ceil((deadlineMs - nowMs) / 1000))
    signal settled()

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("niri_config_apply.py").toString()).replace(/^file:\/\//, "")
    }

    function send(message) {
        if (!root.worker.running) {
            root.error = "Служба записи niri не запущена"
            root.busy = false
            return
        }
        root.busy = true
        worker.write(JSON.stringify(message) + "\n")
    }

    function reload() {
        root.send({action: "read"})
    }

    function applyChanges(changes) {
        root.error = ""
        root.notice = ""
        root.reloadSession = true
        root.send({action: "apply", changes: changes})
    }

    function confirm() {
        root.error = ""
        root.send({action: "confirm", pendingId: root.pendingId})
    }

    function rollback() {
        root.error = ""
        root.reloadSession = true
        root.send({action: "rollback", pendingId: root.pendingId})
    }

    function expire() {
        if (root.expiring || !root.pending)
            return
        root.expiring = true
        root.reloadSession = true
        root.send({action: "expire", now: Date.now() / 1000})
    }

    function takePending(message) {
        const pending = message.pending
        root.pendingId = pending && pending.id ? pending.id : ""
        root.deadlineMs = pending && pending.deadlineMs ? pending.deadlineMs : 0
        if (root.pendingId !== "")
            root.nowMs = Date.now()
    }

    function receive(data) {
        root.busy = false
        let message = null
        try {
            message = JSON.parse(data)
        } catch (failure) {
            root.error = "Служба записи niri ответила не текстом JSON"
            return
        }
        if (message.action === "read") {
            root.ready = true
            root.error = message.ok ? "" : (message.error || "Не удалось прочитать конфигурацию niri")
            root.configPath = message.config || ""
            root.readerMismatch = message.readerMismatch === true
            root.validateAvailable = message.validateAvailable === true
            root.outputs = message.outputs || []
            root.mouse = message.mouse || {}
            root.touchpad = message.touchpad || {}
            root.keyboard = message.keyboard || {}
            root.warnings = message.warnings || []
            root.confirmSeconds = message.confirmSeconds || 15
            root.takePending(message)
            root.revision++
            root.settled()
            if (root.watchOutputs)
                root.send({action: "outputs"})
            return
        }
        if (message.action === "outputs") {
            root.liveOutputs = message.outputs || []
            root.modesError = message.ok ? "" : (message.error || "Список режимов недоступен")
            root.revision++
            return
        }
        if (message.action === "apply") {
            root.takePending(message)
            if (!message.ok) {
                root.reloadSession = false
                root.error = message.error || "Не удалось записать конфигурацию"
                root.settled()
                return
            }
            root.notice = message.changed
                ? (message.pending ? "Настройки записаны. Проверьте картинку" : "Настройки записаны")
                : "В файле уже эти значения"
            const live = root.reloadSession && message.changed
            root.reloadSession = false
            root.settled()
            if (live)
                root.send({action: "live"})
            else
                root.reload()
            return
        }
        if (message.action === "confirm") {
            root.takePending(message)
            if (!message.ok)
                root.error = message.error || "Не удалось оставить изменение"
            else
                root.notice = "Изменение экрана оставлено"
            root.settled()
            root.reload()
            return
        }
        if (message.action === "rollback" || message.action === "expire") {
            root.expiring = false
            root.takePending(message)
            if (!message.ok) {
                root.reloadSession = false
                root.error = message.error || "Не удалось вернуть прежние настройки"
                root.settled()
                return
            }
            if (message.rolledBack)
                root.notice = "Настройки экрана возвращены"
            const live = root.reloadSession && message.rolledBack
            root.reloadSession = false
            root.settled()
            if (live)
                root.send({action: "live"})
            else
                root.reload()
            return
        }
        if (message.action === "live") {
            if (!message.ok)
                root.error = message.error || "niri не перечитал конфигурацию"
            root.reload()
        }
    }

    property Process worker: Process {
        command: ["python3", "-u", root.scriptPath(), "--serve"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => root.receive(data)
        }
        stderr: StdioCollector {
            id: workerErr
        }
        onStarted: root.reload()
        onExited: function(code) {
            root.busy = false
            root.ready = true
            if (root.error === "")
                root.error = (workerErr.text || "").trim() || "Служба записи niri остановилась"
        }
    }

    property Timer clock: Timer {
        interval: 250
        repeat: true
        running: root.pending
        onTriggered: {
            root.nowMs = Date.now()
            if (root.deadlineMs > 0 && root.nowMs >= root.deadlineMs)
                root.expire()
        }
    }
}
