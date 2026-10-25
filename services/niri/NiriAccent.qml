pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Подставляет уже посчитанный tokens.color.accent в акцентные цвета niri.
// Пишет файл только когда строка цвета изменилась. Сначала копия рядом с файлом.
QtObject {
    id: root

    property color accent: "#C0AFD1"
    property bool enabled: true
    property bool settled: false
    property string error: ""
    property string _synced: ""
    property bool _needsReload: false
    property bool _again: false

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("niri_accent.py").toString()).replace(/^file:\/\//, "")
    }

    function configPath() {
        const configured = String(Quickshell.env("NIRI_CONFIG") || "").trim()
        if (configured !== "")
            return configured
        const base = String(Quickshell.env("XDG_CONFIG_HOME") || "").trim()
            || (String(Quickshell.env("HOME") || "") + "/.config")
        return base + "/niri/config.kdl"
    }

    // Qt отдаёт непрозрачный цвет как #AARRGGBB.
    function accentHex(value) {
        let text = String(value === undefined || value === null ? "" : value).trim()
        if (text.charAt(0) === "#")
            text = text.slice(1)
        if (text.length === 3)
            text = text.charAt(0) + text.charAt(0) + text.charAt(1) + text.charAt(1) + text.charAt(2) + text.charAt(2)
        else if (text.length === 8)
            text = text.slice(2)
        return /^[0-9A-Fa-f]{6}$/.test(text) ? "#" + text.toUpperCase() : ""
    }

    function fail(message) {
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

    function sync() {
        if (!root.enabled || !root.settled)
            return
        const hex = root.accentHex(root.accent)
        if (hex === "") {
            root.fail("Не удалось прочитать цвет акцента niri")
            return
        }
        if (hex === root._synced && root.error === "")
            return
        if (root.worker.running) {
            root._again = true
            return
        }
        root._again = false
        root.worker.command = ["python3", root.scriptPath(), "--apply", "--integration", "on", "--config", root.configPath(), "--accent", hex]
        root.worker.running = true
    }

    function finish(code) {
        if (!root.enabled) {
            root._needsReload = false
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
            root.fail((payload && payload.error) || "Не удалось записать цвет акцента niri")
        } else {
            root._synced = payload.accent || root.accentHex(root.accent)
            root.error = ""
            if (payload.changed)
                root.requestReload()
        }
        if (root._again) {
            root._again = false
            root.schedule()
        }
    }

    // LoadConfigFile с path null. Справка niri: «Reload the config file».
    // Не передаём путь: другой путь подменил бы файл конфигурации.
    function requestReload() {
        if (!root.enabled)
            return
        root._needsReload = true
        root.reload()
    }

    function reload() {
        if (!root.enabled || !root._needsReload)
            return
        try {
            if (!Niri.reloadConfig()) {
                root.fail("Цвет акцента записан, но niri не перечитал конфигурацию")
                return
            }
            root._needsReload = false
            if (root.error !== "")
                root.error = ""
        } catch (failure) {
            root.fail("Цвет акцента записан, но niri не перечитал конфигурацию")
        }
    }

    onAccentChanged: root.schedule()
    onSettledChanged: root.schedule()
    onEnabledChanged: {
        if (!root.enabled) {
            debounce.stop()
            root._again = false
            root._needsReload = false
            if (root.error !== "")
                root.error = ""
            return
        }
        root.schedule()
    }
    Component.onCompleted: root.schedule()

    property Timer debounceTimer: Timer {
        id: debounce
        interval: 250
        onTriggered: root.sync()
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

    // QtObject has no default property, so this cannot be a bare child.
    property Connections niriAvailable: Connections {
        target: Niri
        function onAvailableChanged() {
            if (Niri.available)
                root.reload()
        }
    }
}
