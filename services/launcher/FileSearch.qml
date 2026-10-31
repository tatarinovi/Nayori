pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import "SearchModel.js" as SearchModel

// Обход файлов и разбор команды вне потока интерфейса. Старый ответ не затирает новый.
QtObject {
    id: root

    property string query: ""
    property int generation: 0
    property var files: []
    property bool truncated: false
    property string status: "idle"
    property string errorMessage: ""
    property bool commandOk: false
    property var commandArgv: []
    property string commandCode: ""
    property bool restartQueued: false
    property int jobGeneration: -1
    property string payload: ""

    signal commandReady()

    readonly property bool commandPending: root.status === "loading"
        && SearchModel.isCommandQuery(root.query)
        && SearchModel.commandBody(root.query).length > 0
    readonly property string scriptPath: root.localPath(Qt.resolvedUrl("search_worker.py"))

    function localPath(url) {
        const text = String(url === undefined || url === null ? "" : url)
        const prefix = "file://"
        if (text.indexOf(prefix) !== 0)
            return text
        return decodeURIComponent(text.slice(prefix.length))
    }

    function wanted() {
        const text = String(root.query || "")
        if (SearchModel.normalize(text).length === 0)
            return false
        if (SearchModel.isCommandQuery(text))
            return SearchModel.commandBody(text).length > 0
        return SearchModel.fileNeedle(text).length >= 2
    }

    function clearAnswer() {
        root.files = []
        root.truncated = false
        root.commandOk = false
        root.commandArgv = []
        root.commandCode = ""
        root.errorMessage = ""
    }

    function start() {
        if (!root.wanted()) {
            root.restartQueued = false
            if (root.worker.running)
                root.worker.running = false
            root.clearAnswer()
            root.status = "idle"
            return
        }
        if (root.worker.running) {
            root.restartQueued = true
            root.worker.running = false
            return
        }
        root.restartQueued = false
        const token = root.generation
        root.jobGeneration = token
        root.status = "loading"
        root.payload = JSON.stringify({
            generation: token,
            query: root.query
        })
        root.worker.command = ["python3", "-u", root.scriptPath]
        root.worker.stdinEnabled = true
        root.worker.running = true
    }

    function accept(line) {
        let payload = null
        try {
            payload = JSON.parse(line)
        } catch (error) {
            return
        }
        if (!SearchModel.resultIsCurrent(root.generation, payload))
            return
        if (payload.error) {
            root.clearAnswer()
            root.status = "error"
            root.errorMessage = SearchModel.copy("error")
            return
        }
        root.files = payload.files && payload.files.length ? payload.files : []
        root.truncated = payload.truncated === true
        root.errorMessage = ""
        const command = payload.command
        if (command) {
            root.commandOk = command.ok === true
            root.commandArgv = command.argv && command.argv.length ? command.argv : []
            root.commandCode = command.code ? String(command.code) : ""
        } else {
            root.commandOk = false
            root.commandArgv = []
            root.commandCode = ""
        }
        root.status = "ready"
        if (root.commandOk && root.commandArgv.length > 0)
            root.commandReady()
    }

    onQueryChanged: {
        root.generation += 1
        root.clearAnswer()
        root.status = "idle"
        root.debounce.interval = SearchModel.isCommandQuery(root.query) ? 40 : 160
        root.debounce.restart()
    }

    property Timer debounce: Timer {
        interval: 160
        onTriggered: root.start()
    }

    property Process worker: Process {
        id: worker

        stdout: SplitParser {
            onRead: data => root.accept(data)
        }
        stderr: SplitParser {
            onRead: data => {
                if (data)
                    console.warn("Nayori launcher search: " + data)
            }
        }
        onStarted: {
            worker.write(root.payload + "\n")
            worker.stdinEnabled = false
        }
        onExited: function(code) {
            if (root.restartQueued) {
                root.restartQueued = false
                Qt.callLater(root.start)
                return
            }
            if (root.jobGeneration !== root.generation)
                return
            if (root.status === "loading") {
                root.clearAnswer()
                root.status = "error"
                root.errorMessage = SearchModel.copy("error")
            }
        }
    }
}
