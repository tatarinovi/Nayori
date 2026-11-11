pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var settingsService: null
    property bool busy: false
    property bool ready: false
    property bool recording: false
    property string error: ""
    property string notice: ""
    property string mod: "Super"
    property bool modExplicit: false
    property bool validateAvailable: false
    property var rows: []
    property var revision: ({})
    property var warnings: []
    property var conflicts: []
    property var draftConflicts: []
    property var shellActions: []
    property var niriActions: []
    property var pendingChange: null
    property int previewSerial: 0
    signal saved()

    readonly property var nativeRow: ({id: "native:super-tap", keys: "Super_L", title: "Пуск · нажатие Super",
        aliases: ["Super_L", "Super_R"], action: "start.toggle", source: "Nayori", adapter: "native", scope: "global", phase: "tap",
        category: "Shell", enabled: !settingsService || settingsService.values.superTapEnabled !== false,
        editable: false, custom: false, defaultKeys: "Super_L",
        reason: "Нажатие и отпускание Super. Для другой комбинации создайте действие Nayori → Пуск."})
    readonly property var allRows: rows.concat([nativeRow])

    function send(message) {
        if (!worker.running) { error = "Служба сочетаний недоступна"; return false }
        worker.write(JSON.stringify(message) + "\n")
        return true
    }
    function reload() {
        if (busy) return
        busy = true
        if (!send({action: "read", mod: mod})) busy = false
    }
    function apply(change) {
        if (busy) return
        error = ""
        notice = ""
        pendingChange = change
        change.revision = revision
        change.mod = mod
        busy = true
        if (!send({action: "apply", change: change})) busy = false
    }
    function preview(change) {
        let draft = allRows.slice()
        if (change) {
            const index = draft.findIndex(row => row.id === change.id)
            if (index >= 0) draft[index] = Object.assign({}, draft[index], {keys: change.keys, active: true})
            else draft.push({id: "draft", keys: change.keys, title: change.title || "Новое сочетание",
                source: change.kind === "shell" ? "Nayori" : "Niri", enabled: true, scope: "global"})
        }
        send({action: "preview", rows: draft, mod: mod, serial: ++previewSerial, draft: change !== null})
    }
    function toggleSuper() {
        if (settingsService) settingsService.update({superTapEnabled: nativeRow.enabled === false})
    }
    function receive(line) {
        let result
        try { result = JSON.parse(line) }
        catch (failure) { error = "Служба сочетаний вернула неверный ответ"; busy = false; return }
        if (result.action === "preview") {
            if (result.serial === previewSerial) {
                draftConflicts = result.conflicts || []
                if (!result.draft) conflicts = draftConflicts
            }
            return
        }
        busy = false
        if (!result.ok) {
            error = result.error || "Не удалось сохранить сочетание"
            if (result.action === "live") reload()
            return
        }
        if (result.action === "read") {
            ready = true
            rows = result.rows || []
            revision = result.revision || {}
            warnings = result.warnings || []
            conflicts = result.conflicts || []
            shellActions = result.shellActions || []
            niriActions = result.niriActions || []
            mod = result.mod || "Super"
            modExplicit = result.modExplicit === true
            validateAvailable = result.validateAvailable === true
            preview(null)
        } else if (result.action === "apply") {
            notice = result.changed ? "Сочетание сохранено. Резервная копия лежит рядом с конфигурацией." : "Изменений нет"
            saved()
            pendingChange = null
            // Reload is explicit and separate from inspection/validation.
            if (result.changed) { busy = true; send({action: "live"}) }
            else reload()
        } else if (result.action === "live") reload()
    }
    onAllRowsChanged: if (ready) preview(null)
    property Process worker: Process {
        command: ["python3", "-u", decodeURIComponent(Qt.resolvedUrl("keybinds.py").toString()).replace(/^file:\/\//, "")]
        running: true
        stdinEnabled: true
        onStarted: root.reload()
        stdout: SplitParser { onRead: line => root.receive(line) }
        stderr: StdioCollector { id: errors }
        onExited: {
            root.busy = false
            root.error = errors.text.trim() || "Служба сочетаний остановилась"
        }
    }
}
