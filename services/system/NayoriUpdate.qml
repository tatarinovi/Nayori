pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool ready: false
    property bool installed: false
    property bool busy: false
    property bool available: false
    property bool canRollback: false
    property string current: ""
    property string latest: ""
    property string error: ""
    property string message: ""
    property string operation: ""
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../../scripts/nayori-update.py").toString()).replace(/^file:\/\//, "")

    function run(action) {
        if (busy) return
        busy = true
        error = ""
        if (action !== "check") message = ""
        operation = action
        worker.command = ["python3", script, action].concat(action === "apply" ? [latest] : [])
        worker.running = true
    }
    function check() { run("check") }
    function apply() { if (available) run("apply") }
    function rollback() { if (canRollback) run("rollback") }

    property Timer periodic: Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: !root.ready || root.installed
        onTriggered: root.check()
    }
    property Process worker: Process {
        id: worker
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { id: errors; waitForEnd: true }
        onExited: function(code) {
            let result
            try { result = JSON.parse(output.text || "") } catch (e) { result = null }
            root.busy = false
            root.ready = true
            if (!result || !result.ok) {
                if (result && result.installed !== undefined) root.installed = result.installed === true
                if (result && result.rollback !== undefined) root.canRollback = result.rollback === true
                if (result && result.current) root.current = result.current
                root.error = result && result.error ? result.error : ((errors.text || "").trim() || "Не удалось проверить обновления")
                return
            }
            root.installed = result.installed === true
            root.current = result.current || ""
            root.latest = result.latest || ""
            root.available = result.available === true
            root.canRollback = result.rollback === true
            if (result.message) root.message = result.message
        }
    }
    Component.onCompleted: check()
}
