pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
ShellRoot {
    id: root
    property bool allowed: false
    property bool ready: false
    function emitEvent(data) { console.log("NAYORI_EVENT " + JSON.stringify(data)) }
    function fail(message) { emitEvent({type:"error", message:message}); Qt.quit() }
    function snapshot(n) {
        emitEvent({type:"notification", id:n.id, appName:n.appName, appIcon:n.appIcon,
            summary:n.summary, body:n.body, actions:n.actions.map(a => ({id:a.identifier, text:a.text}))})
    }
    Process {
        id: check
        command: ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner", "s", "org.freedesktop.Notifications"]
        running: true
        property string result: ""
        stdout: SplitParser { onRead: data => check.result = data.trim() }
        onExited: code => {
            if (code !== 0 || result !== "b false") root.fail("Сервис уведомлений занят или D-Bus недоступен; приём Nayori выключен.")
            else { root.allowed = true; verifyDelay.start() }
        }
    }
    LazyLoader {
        id: serverLoader
        active: root.allowed
        NotificationServer {
            id: server
            keepOnReload: false
            bodySupported: true
            actionsSupported: true
            bodyMarkupSupported: false
            onNotification: n => { n.tracked = true; root.snapshot(n) }
            property Instantiator observers: Instantiator {
                model: server.trackedNotifications
                delegate: QtObject {
                    id: observer
                    required property var modelData
                    property Timer expiry: Timer {
                        interval: Math.max(1, observer.modelData.expireTimeout)
                        running: observer.modelData.expireTimeout > 0
                        onTriggered: observer.modelData.expire()
                    }
                    property var connection: Connections {
                        target: observer.modelData
                        function onSummaryChanged() { root.snapshot(observer.modelData) }
                        function onBodyChanged() { root.snapshot(observer.modelData) }
                        function onAppNameChanged() { root.snapshot(observer.modelData) }
                        function onAppIconChanged() { root.snapshot(observer.modelData) }
                        function onActionsChanged() { root.snapshot(observer.modelData) }
                        function onExpireTimeoutChanged() { if (observer.modelData.expireTimeout > 0) observer.expiry.restart(); else observer.expiry.stop() }
                        function onClosed() { root.emitEvent({type:"closed",id:observer.modelData.id}) }
                    }
                }
            }
        }
    }
    Timer { id: verifyDelay; interval: 100; onTriggered: verify.running = true }
    Process {
        id: verify
        command: ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", "org.freedesktop.Notifications"]
        property string result: ""
        stdout: SplitParser { onRead: data => verify.result = data.trim() }
        onExited: code => {
            if (code !== 0 || result !== "u " + Quickshell.processId) root.fail("Не удалось занять сервис уведомлений; приём Nayori выключен.")
            else { root.ready = true; root.emitEvent({type:"ready"}) }
        }
    }
    IpcHandler {
        target: "notifications"
        function invoke(id: int, action: string): void {
            if (!root.ready || !serverLoader.item) return
            const n = serverLoader.item.trackedNotifications.values.find(n => n.id === id)
            if (!n) return
            if (action === "__dismiss") n.dismiss()
            else { const a = n.actions.find(a => a.identifier === action); if (a) a.invoke() }
        }
    }
}
