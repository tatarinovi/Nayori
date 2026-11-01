pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// Read the same output records as the display settings, without modifying niri.
QtObject {
    id: root
    property var outputs: []
    property bool busy: false
    property bool reloadPending: false
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("niri_config_apply.py").toString()).replace(/^file:\/\//, "")

    function reload() {
        if (!worker.running || busy) {
            reloadPending = true
            return
        }
        busy = true
        worker.write('{"action":"read"}\n')
    }
    property Process reader: Process {
        id: worker
        command: ["python3", "-u", root.script, "--serve"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                let data = null
                try { data = JSON.parse(line) } catch (error) { data = null }
                root.outputs = data && data.ok && Array.isArray(data.outputs) ? data.outputs : []
                root.busy = false
                if (root.reloadPending) {
                    root.reloadPending = false
                    root.reload()
                }
            }
        }
        stderr: StdioCollector {}
        onStarted: { root.reloadPending = false; root.reload() }
        onExited: { root.busy = false; root.outputs = [] }
    }
}
