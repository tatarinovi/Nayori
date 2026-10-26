import QtQuick
import Quickshell
import Quickshell.Io
import "../niri"
import "NotificationList.js" as List
QtObject {
    id: root
    required property var model
    property bool enabled: Quickshell.env("NAYORI_NOTIFICATIONS") === "1"
    property bool available: false
    property string diagnostic: ""
    property var commands: []
    function invoke(id, action) {
        if (!available) return
        commands.push(["qs", "ipc", "--pid", String(host.processId), "call", "notifications", "invoke", String(id), action])
        nextCommand()
    }
    // Нажатие на уведомление: окно приложения в niri, действие по умолчанию или закрытие.
    function activate(record) {
        const window = List.matchWindow(record, Niri.windows)
        if (window) Niri.focusWindow(window.id)
        const action = List.defaultAction(record)
        if (action) invoke(record.id, action)
        else if (!record.closed) invoke(record.id, "__dismiss")
    }
    function reply(id, text) {
        if (!available) return
        commands.push(["qs", "ipc", "--pid", String(host.processId), "call", "notifications", "reply", String(id), text])
        nextCommand()
    }
    function nextCommand() { if (!actionProcess.running && commands.length) { actionProcess.command = commands.shift(); actionProcess.running = true } }
    property Connections actions: Connections {
        target: root.model
        function onActionRequested(id, action) { root.invoke(id, action) }
        function onDismissRequested(id) { root.invoke(id, "__dismiss") }
        function onReplyRequested(id, text) { root.reply(id, text) }
        function onActivateRequested(record) { root.activate(record) }
    }
    property Process actionProcess: Process { onExited: Qt.callLater(root.nextCommand) }
    function consume(data) {
        const offset = data.indexOf("NAYORI_EVENT ")
        if (offset < 0) return
        try {
            const event = JSON.parse(data.slice(offset + 13))
            if (event.type === "notification") model.receive(event)
            else if (event.type === "closed") model.close(event.id)
            else if (event.type === "ready") available = true
            else if (event.type === "error") { diagnostic = event.message; console.warn(event.message) }
        } catch (error) { console.warn("Notification event:", error) }
    }
    property Process host: Process {
        command: ["qs", "-p", Quickshell.shellPath("services/island/NotificationHost.qml"), "--no-color"]
        running: root.enabled
        stdout: SplitParser { onRead: data => root.consume(data) }
        stderr: SplitParser { onRead: data => root.consume(data) }
        onExited: {
            root.available = false
            root.model.records.filter(r => !r.closed).forEach(r => root.model.close(r.id))
            if (!root.diagnostic) root.diagnostic = "Приём уведомлений остановлен"
        }
    }
}
