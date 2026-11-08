pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property bool ready: false
    property bool enabled: false
    property color first: "#C0AFD1"
    property color second: "#CAA7AA"
    property int width: 3
    property string error: ""
    property bool pending: false
    property string last: ""
    function hex(value) {
        let s = String(value)
        if (/^#[0-9a-fA-F]{8}$/.test(s)) s = "#" + s.slice(3)
        return s
    }
    function configPath() {
        return String(Quickshell.env("NIRI_CONFIG") || "").trim()
            || (String(Quickshell.env("XDG_CONFIG_HOME") || "").trim()
                || String(Quickshell.env("HOME") || "") + "/.config") + "/niri/config.kdl"
    }
    function schedule() { if (ready) timer.restart() }
    function sync() {
        if (!ready) return
        if (worker.running) { pending = true; return }
        const key = JSON.stringify([enabled, hex(first), hex(second), width])
        if (key === last) return
        pending = false
        worker.command = ["python3", decodeURIComponent(Qt.resolvedUrl("niri_border.py").toString()).replace(/^file:\/\//, ""),
            "--config", configPath(), "--enabled", enabled ? "on" : "off",
            "--first", hex(first), "--second", hex(second), "--width", String(width)]
        worker.runningKey = key
        worker.running = true
    }
    onReadyChanged: schedule()
    onEnabledChanged: schedule()
    onFirstChanged: schedule()
    onSecondChanged: schedule()
    onWidthChanged: schedule()
    property Timer debounce: Timer { id: timer; interval: 400; onTriggered: root.sync() }
    property Process process: Process {
        id: worker
        property string runningKey: ""
        stdout: StdioCollector { id: output; waitForEnd: true }
        onExited: function(code) {
            let result = null
            try { result = JSON.parse(output.text) } catch (e) {}
            if (code === 0 && result && result.ok) {
                root.last = worker.runningKey
                root.error = ""
                if (result.changed && !Niri.reloadConfig()) root.error = "Не удалось перечитать конфигурацию Niri"
            } else root.error = result && result.error ? result.error : "Не удалось применить рамку Niri"
            if (root.pending) root.schedule()
        }
    }
}
