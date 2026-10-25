import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string username: Quickshell.env("USER") || ""
    property string hostname: ""
    property string avatar: ""
    property int uptimeSeconds: -1
    property bool active: false
    readonly property string uptime: {
        if (uptimeSeconds < 0) return ""
        const minutes = Math.floor(uptimeSeconds / 60)
        const hours = Math.floor(minutes / 60)
        const days = Math.floor(hours / 24)
        if (days > 0) return days + " д " + hours % 24 + " ч"
        if (hours > 0) return hours + " ч " + minutes % 60 + " мин"
        return minutes + " мин"
    }
    property Timer updateTimer: Timer {
        interval: 30000
        running: root.active
        repeat: true
        onTriggered: root.refresh()
    }
    function refresh() { if (!probe.running) probe.running = true }
    property Process probe: Process {
        command: ["python3", Qt.resolvedUrl("user_profile.py").toString().replace("file://", "")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.username = data.username
                    root.hostname = data.hostname
                    root.avatar = data.avatar
                    root.uptimeSeconds = data.uptime
                } catch (error) { console.warn("User profile:", error) }
            }
        }
    }
}
