pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool watching: false
    property var profiles: []
    property bool ready: false
    property bool available: false
    property string queryError: ""
    property string actionError: ""
    readonly property string error: actionError || queryError
    property string notice: ""
    property string operation: ""
    property string operationUuid: ""
    property bool refreshPending: false
    property int revision: 0
    property int queryRevision: 0
    readonly property bool busy: operation !== ""
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../../scripts/wireguard-control.py").toString()).replace(/^file:\/\//, "")

    function refresh(clearError) {
        if (clearError === true)
            actionError = ""
        if (query.running || busy) {
            refreshPending = true
            return
        }
        refreshPending = false
        queryRevision = revision
        query.running = true
    }

    function apply(data, isAction) {
        try {
            const result = JSON.parse(data)
            if (result.profiles !== undefined) {
                if (JSON.stringify(profiles) !== JSON.stringify(result.profiles))
                    profiles = result.profiles
                available = true
            } else if (!isAction) {
                available = false
                profiles = []
            }
            if (isAction)
                actionError = result.error || ""
            else
                queryError = result.error || ""
            if (isAction && result.profiles !== undefined)
                queryError = ""
            ready = true
        } catch (_) {
            if (isAction)
                actionError = "Не удалось прочитать состояние WireGuard. Обновите список"
            else
                queryError = "Не удалось прочитать состояние WireGuard. Обновите список"
            available = false
            ready = true
        }
    }

    function toggle(profile) {
        if (busy || !available || !profile || profile.state === "activating" || profile.state === "deactivating")
            return
        operation = profile.active ? "down" : "up"
        revision++
        operationUuid = profile.uuid
        actionError = ""
        notice = ""
        action.command = ["python3", scriptPath, operation, operationUuid]
        action.running = true
    }

    function importFile(file) {
        if (busy)
            return
        operation = "import"
        revision++
        operationUuid = ""
        actionError = ""
        notice = ""
        action.command = ["python3", scriptPath, "import", file.toString()]
        action.running = true
    }

    onWatchingChanged: if (watching) refresh()
    Component.onCompleted: if (watching) refresh()

    // nmcli listens to NM signals; there is no periodic polling while idle.
    property Process monitor: Process {
        command: ["nmcli", "monitor"]
        running: root.watching || root.busy
        stdout: SplitParser { onRead: root.debounce.restart() }
        stderr: StdioCollector {}
    }
    property Timer debounce: Timer {
        interval: 150
        onTriggered: if (root.watching || root.busy) root.refresh()
    }
    property Process query: Process {
        command: ["python3", root.scriptPath, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.busy || root.queryRevision !== root.revision)
                    root.refreshPending = true
                else
                    root.apply(text, false)
            }
        }
        stderr: StdioCollector {}
        onExited: function(code) {
            if (code !== 0) {
                root.ready = true
                root.available = false
                root.queryError = "Сервис WireGuard недоступен. Проверьте python3 и nmcli"
            }
            if (root.refreshPending && !root.busy && root.watching)
                Qt.callLater(root.refresh)
        }
    }
    property Process action: Process {
        stdout: StdioCollector { onStreamFinished: root.apply(text, true) }
        stderr: StdioCollector {}
        onExited: function(code) {
            if (code !== 0)
                root.actionError = "Не удалось выполнить операцию WireGuard. Проверьте состояние сети"
            if (root.operation === "import" && root.error === "")
                root.notice = "Профиль WireGuard импортирован"
            root.operation = ""
            root.operationUuid = ""
            if (root.watching)
                Qt.callLater(root.refresh)
        }
    }
}
