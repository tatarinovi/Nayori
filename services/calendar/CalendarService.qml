import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var settings: null
    readonly property string url: settings ? (settings.values.calendarUrl || "") : ""
    readonly property string user: settings ? (settings.values.calendarUser || "") : ""
    property var events: []
    property string error: ""
    property bool busy: false
    property string pendingUrl: ""
    property string pendingUser: ""
    property int generation: 0
    property int requestedGeneration: 0
    function connect(address, login, password) {
        if (busy || !worker.running) return
        pendingUrl = address.trim(); pendingUser = login.trim()
        requestedGeneration = generation
        busy = true; error = ""
        worker.write(JSON.stringify({url: pendingUrl, user: pendingUser, password: password}) + "\n")
    }
    function refresh() { if (url && user) connect(url, user, "") }
    onUrlChanged: { generation++; events = []; Qt.callLater(refresh) }
    onUserChanged: { generation++; events = []; Qt.callLater(refresh) }
    property Timer schedule: Timer { interval: 900000; running: !!root.url; repeat: true; onTriggered: root.refresh() }
    property Process worker: Process {
        command: ["python3", "-u", Qt.resolvedUrl("caldav_worker.py").toString().replace("file://", "")]
        running: true
        stdinEnabled: true
        onStarted: root.refresh()
        onExited: { root.busy = false; root.error = "Служба календаря остановлена" }
        stdout: SplitParser {
            onRead: data => {
                root.busy = false
                if (root.requestedGeneration !== root.generation) { Qt.callLater(root.refresh); return }
                try {
                    const response = JSON.parse(data)
                    root.error = response.error || ""
                    if (!root.error) {
                        root.events = response.events || []
                        if (response.connected && root.settings) root.settings.update({calendarUrl: root.pendingUrl, calendarUser: root.pendingUser})
                    }
                } catch (failure) { root.error = "Некорректный ответ службы календаря" }
            }
        }
    }
}
