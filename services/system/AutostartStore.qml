pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool ready: false
    property bool busy: false
    property string error: ""
    property var entries: []
    property var warnings: []

    function scriptPath() {
        return decodeURIComponent(Qt.resolvedUrl("autostart_tool.py").toString()).replace(/^file:\/\//, "")
    }

    function refresh() {
        if (busy)
            return
        run(["list"])
    }

    function setEnabled(fileName, enabled): bool {
        if (busy) {
            error = "Уже выполняется другое действие с автозапуском"
            return false
        }
        return run([enabled ? "enable" : "disable", fileName])
    }

    function remove(fileName): bool {
        if (busy) {
            error = "Уже выполняется другое действие с автозапуском"
            return false
        }
        return run(["remove", fileName])
    }

    function add(name, command): bool {
        if (busy) {
            error = "Уже выполняется другое действие с автозапуском"
            return false
        }
        return run(["add", name, command])
    }

    function run(args): bool {
        error = ""
        busy = true
        const command = ["python3", scriptPath()].concat(args)
        worker.command = command
        worker.running = true
        return true
    }

    property Process worker: Process {
        id: worker
        stdout: StdioCollector {
            id: workerOut
            waitForEnd: true
        }
        stderr: StdioCollector {
            id: workerErr
            waitForEnd: true
        }
        onExited: function(code) {
            const text = (workerOut.text || "").trim()
            let payload = null
            try {
                payload = text ? JSON.parse(text) : null
            } catch (parseError) {
                payload = null
            }
            if (!payload || payload.ok !== true) {
                root.error = payload && payload.error ? payload.error : ((workerErr.text || "").trim() || "Не удалось выполнить действие с автозапуском")
                root.busy = false
                root.ready = true
                return
            }
            if (payload.entries) {
                root.entries = payload.entries
                root.warnings = payload.warnings || []
                root.error = ""
                root.busy = false
                root.ready = true
                return
            }
            root.busy = false
            Qt.callLater(root.refresh)
        }
    }

    Component.onCompleted: refresh()
}
