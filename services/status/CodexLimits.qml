import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property bool enabled: false
    property var data: ({ status: "loading" })
    property real now: Date.now() / 1000
    readonly property var windows: data.windows || []
    readonly property bool busy: scanner.running
    function stale(window) { return !!window.reset && now >= window.reset }
    function label(window) {
        if (window.minutes === 300) return "5 часов"
        if (window.minutes === 10080) return "Неделя"
        return window.minutes ? window.minutes + " мин" : "Лимит"
    }
    function refresh() { if (!enabled) return; now = Date.now() / 1000; if (!scanner.running) scanner.running = true }
    onEnabledChanged: if (!enabled) data = { status: "loading" }
    property Timer timer: Timer { interval: 300000; repeat: true; running: root.enabled; triggeredOnStart: true; onTriggered: root.refresh() }
    property Process scanner: Process {
        command: ["python3", Quickshell.shellDir + "/services/status/codex_limits.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.enabled) return
                try { root.data = JSON.parse(text) } catch (e) { root.data = { status: "error" } }
            }
        }
        onExited: code => { if (root.enabled && code !== 0) root.data = { status: "error" } }
    }
}
