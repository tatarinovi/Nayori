import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var records: []
    property bool ready: false
    property string error: ""
    property bool copying: false
    property bool reading: false
    signal contentReady(var content)
    function readCurrent() {
        if (root.reading) return false
        root.reading = root.send("read-current", "")
        return root.reading
    }
    property bool pasteRequested: false
    property bool pasteReady: false
    property bool enabled: true
    signal copied(string identity)

    function send(action, identity) {
        if (!worker.running) {
            root.error = "Служба буфера обмена не запущена"
            return false
        }
        root.error = ""
        worker.write(JSON.stringify({action: action, id: identity || ""}) + "\n")
        return true
    }
    function copyContent(mime, text) {
        if (root.copying) return
        root.cancelPaste()
        if (!worker.running) { root.error = "Служба буфера обмена не запущена"; return }
        root.error = ""
        root.copying = true
        worker.write(JSON.stringify({action: "copy-content", mime: mime, text: text}) + "\n")
    }
    function copy(identity, pasteAfter) {
        if (root.copying) return
        root.pasteRequested = pasteAfter === true
        root.pasteReady = false
        root.copying = root.send("copy", identity)
    }
    function finishClose() {
        if (!root.pasteReady) return
        root.pasteReady = false
        // The transparent frame has been committed and the layer removed.
        // Let the compositor deliver focus before creating a virtual keyboard.
        root.pasteDelay.restart()
    }
    function cancelPaste() {
        root.pasteRequested = false
        root.pasteReady = false
        root.pasteDelay.stop()
    }
    function pin(identity) { root.send("pin", identity) }
    function remove(identity) { root.send("remove", identity) }
    function clear() { root.send("clear", "") }
    function refresh() { root.send("list", "") }

    property Process worker: Process {
        command: ["python3", "-u", Qt.resolvedUrl("clipboard_store.py").toString().replace("file://", "")]
        running: root.enabled
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    if (message.event === "history") {
                        root.records = message.records
                        root.ready = message.ready
                        root.error = message.error || ""
                    } else if (message.event === "content") {
                        root.reading = false
                        root.contentReady(message.content)
                    } else if (message.event === "copied") {
                        root.copying = false
                        root.pasteReady = root.pasteRequested
                        root.pasteRequested = false
                        root.copied(message.id)
                    } else if (message.event === "paste-unavailable") {
                        console.warn("Clipboard:", message.error)
                    } else if (message.event === "error") {
                        root.reading = false
                        root.copying = false
                        root.cancelPaste()
                        root.error = message.error
                    }
                } catch (failure) { console.warn("Clipboard: invalid worker response") }
            }
        }
        onExited: (code, status) => {
            root.ready = false
            root.reading = false
            root.copying = false
            root.cancelPaste()
            if (root.enabled) {
                if (!root.error) root.error = "Служба буфера обмена остановилась"
                root.retry.restart()
            }
        }
    }
    property Timer pasteDelay: Timer {
        interval: 40
        onTriggered: root.send("paste", "")
    }
    property Timer retry: Timer {
        interval: 3000
        onTriggered: if (root.enabled && !root.worker.running) root.worker.running = true
    }
}
