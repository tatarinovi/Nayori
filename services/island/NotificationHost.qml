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
    // Картинки из image-data существуют только в этом процессе (image://qsimage/…).
    // Они сохраняются в PNG в runtime-каталоге, остров читает уже обычный файл.
    readonly property string imageDirectory: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nayori-notify"
    property bool directoryReady: false
    property var exported: ({})
    property var exportQueue: []
    property var job: null
    property int exportCounter: 0
    function localImage(n) {
        const source = String(n.image || "")
        if (source.indexOf("image://") !== 0) return source
        const done = exported[n.id]
        if (done && done.source === source) return done.path
        if (!exportQueue.some(j => j.id === n.id && j.source === source) && !(job && job.id === n.id && job.source === source)) {
            exportQueue = exportQueue.concat([{id: n.id, source: source}])
            Qt.callLater(root.nextExport)
        }
        return ""
    }
    function nextExport() {
        if (job || !directoryReady || exportQueue.length === 0) return
        const queue = exportQueue.slice()
        job = queue.shift()
        exportQueue = queue
    }
    function finishExport(path) {
        const finished = job
        job = null
        if (finished && path) {
            exported[finished.id] = {source: finished.source, path: path}
            const n = serverLoader.item ? serverLoader.item.trackedNotifications.values.find(n => n.id === finished.id) : null
            if (n) root.snapshot(n)
        }
        Qt.callLater(root.nextExport)
    }
    function snapshot(n) {
        emitEvent({type:"notification", id:n.id, appName:n.appName, appIcon:n.appIcon, desktopEntry:n.desktopEntry,
            image:root.localImage(n), urgency:Number(n.urgency), hasReply:n.hasInlineReply, replyPlaceholder:n.inlineReplyPlaceholder,
            summary:n.summary, body:n.body, actions:n.actions.map(a => ({id:a.identifier, text:a.text}))})
    }
    Process {
        id: makeDirectory
        command: ["mkdir", "-p", root.imageDirectory]
        running: true
        onExited: code => { root.directoryReady = code === 0; root.nextExport() }
    }
    LazyLoader {
        id: imageExporter
        active: root.job !== null
        source: root.job ? Qt.resolvedUrl("NotificationImageExporter.qml") : ""
        onItemChanged: if (item) item.host = root
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
                        function onImageChanged() { root.snapshot(observer.modelData) }
                        function onDesktopEntryChanged() { root.snapshot(observer.modelData) }
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
        function reply(id: int, text: string): void {
            if (!root.ready || !serverLoader.item) return
            const n = serverLoader.item.trackedNotifications.values.find(n => n.id === id)
            if (n && n.hasInlineReply) n.sendInlineReply(text)
        }
    }
}
