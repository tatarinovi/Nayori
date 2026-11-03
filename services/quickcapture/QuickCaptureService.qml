import QtQuick
import Quickshell.Io

QtObject {
    id: root
    required property var settings
    property bool ready: false
    property bool busy: false
    property string text: ""
    property string context: settings.values.quickCaptureContext
    property string operationId: ""
    property bool attempted: false
    property string error: ""
    property string status: ""
    property string lastUri: ""
    readonly property string configurationHint: !settings.values.quickCaptureEnabled
        ? "Quick Capture выключен. Нажмите «Настроить», чтобы включить сохранение в Obsidian"
        : !settings.values.quickCaptureVault
        ? "Укажите папку Vault через «Настроить». Текст останется в черновике"
        : ""
    signal saved()
    function edit(value, selectedContext) {
        if (!ready || busy) return
        if (attempted && (text !== value || context !== selectedContext)) {
            operationId = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx".replace(/x/g, () => Math.floor(Math.random() * 16).toString(16))
            attempted = false
        }
        text = value
        context = selectedContext
        status = ""
        worker.write(JSON.stringify({action: "draft", text: text, context: context, id: operationId}) + "\n")
    }
    function save() {
        if (!ready || busy || !text.trim()) return
        if (!settings.values.quickCaptureEnabled) { error = "Включите Quick Capture: Приложения → Obsidian Inbox"; return }
        busy = true
        attempted = true
        error = ""
        status = "Сохранение…"
        worker.write(JSON.stringify({action: "save", text: text, context: context, id: operationId,
            vault: settings.values.quickCaptureVault,
            directory: context === "Work" ? settings.values.quickCaptureWorkPath : settings.values.quickCapturePersonalPath}) + "\n")
    }
    property Connections settingsEvents: Connections {
        target: root.settings
        function onValuesChanged() {
            if (!root.text && !root.busy) root.context = root.settings.values.quickCaptureContext
        }
    }
    property Process worker: Process {
        command: ["python3", "-u", decodeURIComponent(Qt.resolvedUrl("quick_capture.py").toString()).replace(/^file:\/\//, "")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    const message = JSON.parse(line)
                    if (message.event === "ready") {
                        root.text = message.draft.text
                        root.context = message.draft.context || root.settings.values.quickCaptureContext
                        root.operationId = message.draft.id
                        root.ready = true
                    } else if (message.event === "saved") {
                        root.busy = false
                        root.attempted = false
                        root.text = ""
                        root.lastUri = message.uri
                        root.status = "Сохранено в Obsidian"
                        // A new id is supplied by the worker, never generated in the view.
                        root.operationId = message.id
                        root.saved()
                    } else if (message.event === "error") {
                        if (message.action === "save") root.busy = false
                        root.status = ""
                        root.error = message.error
                    } else if (message.event === "draft") {
                        root.error = ""
                        if (!root.busy) root.status = "Черновик сохранён"
                    }
                } catch (failure) {
                    root.busy = false
                    root.error = "Не удалось прочитать ответ. Текст остался в поле ввода"
                }
            }
        }
        onExited: {
            root.ready = false
            root.busy = false
            root.status = ""
            if (!root.error) root.error = "Служба заметок остановилась. Черновик на диске сохранён; перезапустите Nayori"
        }
    }
}
