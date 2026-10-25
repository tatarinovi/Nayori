pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Пишет уже посчитанные токены Nayori в тему Strata.
// Файл тот же по составу, что angelos.toml: цвета, путь и выбор темы в настройках.
// Повтор с тем же текстом файл не трогает. Каталога Strata или самой программы может не быть.
QtObject {
    id: root

    property bool enabled: true
    property bool settled: false
    property color background: "#121217"
    property color surface: "#4F4F57"
    property color surfaceAlt: "#443D4E"
    property color text: "#F0E9DB"
    property color textMuted: "#D5CEC4"
    property color accent: "#C0AFD1"
    property color accentSoft: "#80758C"
    property color secondary: "#CAA7AA"
    property string error: ""
    property string notice: ""
    property string _synced: ""
    property bool _again: false

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("strata_theme.py").toString()).replace(/^file:\/\//, "")
    }

    function configDir() {
        const base = String(Quickshell.env("XDG_CONFIG_HOME") || "").trim()
            || (String(Quickshell.env("HOME") || "") + "/.config")
        return base + "/strata"
    }

    function hex(value) {
        let text = String(value === undefined || value === null ? "" : value).trim()
        if (text.charAt(0) === "#")
            text = text.slice(1)
        if (text.length === 3)
            text = text.charAt(0) + text.charAt(0) + text.charAt(1) + text.charAt(1) + text.charAt(2) + text.charAt(2)
        else if (text.length === 8)
            text = text.slice(2)
        return /^[0-9A-Fa-f]{6}$/.test(text) ? "#" + text.toUpperCase() : ""
    }

    function payload() {
        const colors = {
            "background": root.hex(root.background),
            "surface": root.hex(root.surface),
            "surfaceAlt": root.hex(root.surfaceAlt),
            "text": root.hex(root.text),
            "textMuted": root.hex(root.textMuted),
            "accent": root.hex(root.accent),
            "accentSoft": root.hex(root.accentSoft),
            "secondary": root.hex(root.secondary)
        }
        for (const key of Object.keys(colors)) {
            if (!colors[key])
                return ""
        }
        return JSON.stringify(colors)
    }

    readonly property string payloadText: root.payload()

    function fail(message) {
        root.notice = ""
        if (root.error === message)
            return
        root.error = message
        console.warn(message)
    }

    function schedule() {
        if (!root.enabled || !root.settled) {
            debounce.stop()
            return
        }
        debounce.restart()
    }

    function sync(force) {
        if (!root.enabled || !root.settled)
            return
        const text = root.payload()
        if (text === "") {
            root.fail("Не удалось прочитать цвета темы Strata")
            return
        }
        if (!force && text === root._synced && root.error === "")
            return
        if (root.worker.running) {
            root._again = true
            return
        }
        root._again = false
        root.worker.command = ["python3", root.scriptPath(), "build", "--json", text, "--config-dir", root.configDir()]
        root.worker.running = true
    }

    function finish(code) {
        if (!root.enabled) {
            root._again = false
            return
        }
        const lines = String(workerOut.text || "").split("\n").filter(function (line) { return line.trim() !== "" })
        const last = lines.length ? lines[lines.length - 1] : ""
        let payload = null
        try {
            payload = last ? JSON.parse(last) : null
        } catch (parseError) {
            payload = null
        }
        if (!payload || payload.ok !== true || code !== 0) {
            const detail = String(workerErr.text || "").trim()
            if (detail !== "")
                console.warn(detail)
            root.fail((payload && payload.error) || "Не удалось записать тему Strata")
        } else {
            root._synced = root.payload()
            root.error = ""
            root.notice = payload.notice || ""
        }
        if (root._again) {
            root._again = false
            root.schedule()
        }
    }

    onPayloadTextChanged: root.schedule()
    onSettledChanged: root.schedule()
    onEnabledChanged: {
        if (!root.enabled) {
            debounce.stop()
            root._again = false
            root.error = ""
            root.notice = ""
            return
        }
        root.sync(true)
    }
    Component.onCompleted: root.schedule()

    property Timer debounceTimer: Timer {
        id: debounce
        interval: 250
        onTriggered: root.sync(false)
    }

    property Process worker: Process {
        stdout: StdioCollector {
            id: workerOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: workerErr
            waitForEnd: true
        }
        onExited: function(code) { root.finish(code) }
    }
}
