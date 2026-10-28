import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var clipboard: null
    property var items: []
    property bool ready: false
    property bool busy: false
    property string error: ""
    property string status: ""
    property bool enabled: true
    property bool copyPending: false
    property bool pastePending: false
    function paste() {
        if (!clipboard) { error = "Буфер обмена недоступен"; return }
        error = ""
        pastePending = true
        if (!clipboard.readCurrent()) { pastePending = false; error = clipboard.error || "Буфер обмена занят" }
    }
    property Connections clipboardEvents: Connections {
        target: root.clipboard
        function onContentReady(content) {
            if (!root.pastePending) return
            root.pastePending = false
            root.add(content)
        }
        function onCopied(identity) {
            if (!root.copyPending) return
            root.copyPending = false
            root.status = "Скопировано"
        }
        function onErrorChanged() {
            if ((root.copyPending || root.pastePending) && root.clipboard.error) {
                root.copyPending = false
                root.pastePending = false
                root.error = root.clipboard.error
            }
        }
    }
    function send(action, data) {
        if (!worker.running) { error = "Служба полки не запущена"; return false }
        error = ""
        status = ""
        busy = true
        worker.write(JSON.stringify(Object.assign({action: action}, data || {})) + "\n")
        return true
    }
    function add(data) {
        if (data.error) { error = data.error; return false }
        return send("add", data)
    }
    function refresh() { if (!busy) send("list") }
    function favorite(id) { send("fav", {id: id}) }
    function remove(id) { send("remove", {id: id}) }
    function taken(id) { send("taken", {id: id}) }
    function edit(id, text) { send("edit", {id: id, text: text}) }
    function into(id, urls) { send("into", {id: id, urls: urls}) }
    function open(id) { send("open", {id: id}) }
    function folder(id) { send("folder", {id: id}) }
    function copy(item) {
        if (item.missing) { error = "Файл перемещён или удалён"; return }
        if (!clipboard) { error = "Буфер обмена недоступен"; return }
        if (clipboard.copying) { error = "Дождитесь завершения копирования"; return }
        error = ""
        copyPending = true
        clipboard.copyContent(item.kind === "text" || item.kind === "link" ? "text/plain;charset=utf-8" : "text/uri-list",
                              item.kind === "text" ? item.text : item.uri)
    }
    property Process worker: Process {
        command: ["python3", "-u", Qt.resolvedUrl("shelf_store.py").toString().replace("file://", "")]
        running: root.enabled
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    root.busy = false
                    root.error = message.error || ""
                    if (message.event === "state") {
                        root.items = message.items
                        root.ready = message.ready
                        root.status = root.error ? "" : "Готово"
                    }
                } catch (failure) { root.error = "Некорректный ответ службы полки" }
            }
        }
        onExited: (code, status) => {
            root.ready = false
            root.busy = false
            if (root.enabled) {
                if (!root.error) root.error = "Служба полки остановилась"
                root.retry.restart()
            }
        }
    }
    property Timer retry: Timer {
        interval: 3000
        onTriggered: if (root.enabled && !root.worker.running) root.worker.running = true
    }
}
