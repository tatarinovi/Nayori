import QtQuick
import Quickshell.Io

Item {
    id: root
    visible: false
    property url folder: ""
    property string query: ""
    property var entries: []
    property string snapshot: ""
    property string scannedFolder: ""
    property bool loaded: false
    readonly property bool loading: scan.running && !loaded
    readonly property int count: rows.count
    property int imageCount: 0
    property int folderCount: 0
    property alias model: rows

    function filter() {
        const needle = query.toLowerCase()
        rows.clear()
        const matches = entries.filter(entry => entry.fileName.toLowerCase().includes(needle))
        imageCount = matches.filter(entry => !entry.isFolder).length
        folderCount = matches.length - imageCount
        if (matches.length) rows.append(matches)
    }
    function refresh() {
        if (!enabled || scan.running || !String(folder)) return
        scannedFolder = String(folder)
        scan.command = ["python3", decodeURIComponent(String(Qt.resolvedUrl("wallpaper_library.py")).replace(/^file:\/\//, "")), scannedFolder]
        scan.running = true
    }
    onFolderChanged: {
        entries = []
        snapshot = ""
        loaded = false
        Qt.callLater(refresh)
    }
    onEnabledChanged: if (enabled) Qt.callLater(refresh)
    onEntriesChanged: filter()
    onQueryChanged: filter()
    Component.onCompleted: refresh()
    ListModel { id: rows }
    // Scan outside the GUI thread; refresh only while the owning gallery is open.
    Timer { interval: 2000; running: root.enabled; repeat: true; onTriggered: root.refresh() }
    Process {
        id: scan
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.scannedFolder !== String(root.folder)) return
                try {
                    const next = JSON.parse(text)
                    if (!Array.isArray(next)) return
                    if (text !== root.snapshot) {
                        root.snapshot = text
                        root.entries = next
                    }
                    root.loaded = true
                } catch (error) { console.warn("Wallpaper collection scan failed:", error) }
            }
        }
        onExited: if (root.scannedFolder !== String(root.folder)) Qt.callLater(root.refresh)
    }
}
