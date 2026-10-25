pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// One cached blur per wallpaper identity (path, mtime, size). The sharp
// desktop image is never the source of this item. A finished process whose
// generation is older than the latest request is ignored.
QtObject {
    id: root

    property var manager: null
    property bool active: false
    property var shown: ({})
    property int generation: 0
    property int inflight: -1
    property bool pending: false
    property string desiredKey: ""

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("overview_blur.py").toString()).replace(/^file:\/\//, "")
    }

    function cacheDirectory() {
        const base = String(Quickshell.env("XDG_CACHE_HOME") || "").trim()
            || (String(Quickshell.env("HOME") || "") + "/.cache")
        return base + "/nayori/overview"
    }

    function collect() {
        const jobs = []
        if (!root.manager || !root.manager.ready)
            return jobs
        const screens = Quickshell.screens
        for (let i = 0; i < screens.length; ++i) {
            const screen = screens[i]
            if (!screen || !screen.name)
                continue
            const wallpaper = root.manager.wallpaper(String(screen.name))
            jobs.push({
                output: String(screen.name),
                source: String(wallpaper.source)
            })
        }
        return jobs
    }

    function schedule(fromPulse) {
        if (!root.active || !root.manager || !root.manager.ready) {
            coalesce.stop()
            return
        }
        coalesce.fromPulse = fromPulse === true
        coalesce.restart()
    }

    function refresh() {
        const fromPulse = coalesce.fromPulse
        const jobs = root.collect()
        const key = JSON.stringify(jobs)
        const changed = key !== root.desiredKey
        if (!changed && !fromPulse)
            return
        if (changed) {
            root.desiredKey = key
            root.generation += 1
        }
        if (worker.running) {
            if (changed)
                root.pending = true
            return
        }
        root.launch(jobs)
    }

    function launch(jobs) {
        root.pending = false
        root.inflight = root.generation
        const request = JSON.stringify({
            generation: root.generation,
            cacheDir: root.cacheDirectory(),
            jobs: jobs
        })
        worker.command = ["python3", root.scriptPath(), "--request", request]
        worker.running = true
    }

    function applyPayload(payload) {
        const outputs = payload.outputs || {}
        const next = Object.assign({}, root.shown)
        const names = Object.keys(outputs)
        for (let i = 0; i < names.length; ++i) {
            const name = names[i]
            const item = outputs[name]
            if (!item || item.ok !== true || !item.pointer)
                continue
            const prior = next[name]
            if (prior && prior.path === item.pointer)
                continue
            next[name] = {
                path: String(item.pointer),
                previous: prior && prior.path && prior.path !== item.pointer ? prior.path : (prior && prior.previous ? prior.previous : "")
            }
        }
        root.shown = next
    }

    function revert(output, path) {
        const slot = root.shown[output]
        if (!slot || slot.path !== path)
            return
        const next = Object.assign({}, root.shown)
        if (slot.previous)
            next[output] = { path: slot.previous, previous: "" }
        else
            delete next[output]
        root.shown = next
    }

    function finish(code) {
        const launched = root.inflight
        root.inflight = -1
        const lines = String(workerOut.text || "").split("\n").filter(function (line) { return line.trim() !== "" })
        const last = lines.length ? lines[lines.length - 1] : ""
        let payload = null
        try {
            payload = last ? JSON.parse(last) : null
        } catch (parseError) {
            payload = null
        }
        if (payload && payload.generation === launched && launched === root.generation && code === 0)
            root.applyPayload(payload)
        if (root.pending && root.active && root.manager && root.manager.ready)
            root.launch(root.collect())
    }

    onActiveChanged: root.schedule(false)
    Component.onCompleted: root.schedule(false)

    property Connections managerChanges: Connections {
        target: root.manager
        function onStateChanged() { root.schedule(false) }
        function onReadyChanged() { root.schedule(false) }
    }

    property Timer coalesceTimer: Timer {
        id: coalesce
        property bool fromPulse: false
        interval: 50
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer pulseTimer: Timer {
        interval: 2000
        repeat: true
        running: root.active && root.manager && root.manager.ready
        onTriggered: root.schedule(true)
    }

    property Process worker: Process {
        stdout: StdioCollector {
            id: workerOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            waitForEnd: true
        }
        onExited: function (code) { root.finish(code) }
    }
}
