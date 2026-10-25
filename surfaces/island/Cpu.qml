import QtQuick
import Quickshell.Io

// Sample aggregate jiffies, once a second. guest/guest_nice are already included
// in user/nice, so only the first eight counters contribute to total.
QtObject {
    id: root
    property bool active: true
    readonly property real load: sampleLoad
    property real sampleLoad: 0
    property real previousTotal: -1
    property real previousIdle: -1

    function resetBaseline() {
        previousTotal = -1
        previousIdle = -1
    }

    function consume(contents: string) {
        if (!active)
            return
        const fields = contents.split("\n")[0].trim().split(/\s+/)
        if (fields.length < 9 || fields[0] !== "cpu") {
            resetBaseline()
            return
        }
        let total = 0
        for (let i = 1; i <= 8; i++) {
            const value = Number(fields[i])
            if (!isFinite(value) || value < 0) {
                resetBaseline()
                return
            }
            total += value
        }
        const idle = Number(fields[4]) + Number(fields[5])
        const elapsed = total - previousTotal
        const idleElapsed = idle - previousIdle
        if (previousTotal >= 0 && elapsed > 0 && idleElapsed >= 0)
            sampleLoad = Math.max(0, Math.min(1, 1 - idleElapsed / elapsed))
        previousTotal = total
        previousIdle = idle
    }

    onActiveChanged: {
        resetBaseline()
        if (active)
            stat.reload()
    }

    property FileView stat: FileView {
        path: "/proc/stat"
        preload: root.active
        printErrors: false
        onLoaded: root.consume(text())
        onLoadFailed: {
            root.resetBaseline()
            root.sampleLoad = 0
        }
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.stat.reload()
    }
}
