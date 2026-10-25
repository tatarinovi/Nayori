pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Writes nayori-overview.kdl and includes it from config.kdl. If that rule is
// not loaded yet, asks niri to reload the current config once. ruleLive
// becomes true only after that reload's ConfigLoaded, or when niri started
// after the include was already on disk.
QtObject {
    id: root

    property bool ruleLive: false
    property string error: ""
    property real reloadAt: 0
    property int seenReloads: -1
    property bool again: false
    property bool askedReload: false

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("niri_overview.py").toString()).replace(/^file:\/\//, "")
    }

    function configPath() {
        const configured = String(Quickshell.env("NIRI_CONFIG") || "").trim()
        if (configured !== "")
            return configured
        const base = String(Quickshell.env("XDG_CONFIG_HOME") || "").trim()
            || (String(Quickshell.env("HOME") || "") + "/.config")
        return base + "/niri/config.kdl"
    }

    function schedule() {
        debounce.restart()
    }

    function sync() {
        if (worker.running) {
            root.again = true
            return
        }
        root.again = false
        const args = ["python3", root.scriptPath(), "--apply", "--config", root.configPath()]
        const socket = Niri.socketPath()
        if (socket !== "")
            args.push("--socket", socket)
        if (root.reloadAt > 0)
            args.push("--reload-at", String(root.reloadAt))
        worker.command = args
        worker.running = true
    }

    function finish(code) {
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
            root.ruleLive = false
            root.error = (payload && payload.error) || "Не удалось записать фон обзора niri"
            console.warn(root.error)
        } else {
            root.ruleLive = payload.ruleLive === true
            root.error = ""
            // One reload of the current file. The layer stays unmapped until
            // the following ConfigLoaded makes ruleLive true.
            if (!root.ruleLive && payload.included === true && !root.askedReload) {
                if (Niri.reloadConfig())
                    root.askedReload = true
            }
        }
        if (root.again) {
            root.again = false
            root.schedule()
        }
    }

    function noteReload() {
        if (root.seenReloads < 0) {
            root.seenReloads = Niri.configReloads
            return
        }
        if (Niri.configReloads === root.seenReloads)
            return
        root.seenReloads = Niri.configReloads
        if (!Niri.configFailed)
            root.reloadAt = Date.now() / 1000
        root.schedule()
    }

    Component.onCompleted: {
        root.seenReloads = Niri.configReloads
        root.schedule()
    }

    property Timer debounceTimer: Timer {
        id: debounce
        interval: 250
        repeat: false
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
        onExited: function (code) { root.finish(code) }
    }

    property Connections reloads: Connections {
        target: Niri
        function onConfigReloadsChanged() { root.noteReload() }
        function onAvailableChanged() {
            if (Niri.available && !root.ruleLive && !root.askedReload)
                root.schedule()
        }
    }
}
