pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "WidgetLayout.js" as WidgetLayout

// Один таймер на слой. Виджеты системы читают эти поля и не открывают /proc сами.
QtObject {
    id: root
    property bool active: false
    property var cpu: null
    property bool cpuFailed: false
    property var memory: null
    property bool memoryFailed: false
    property var previousCpu: null

    function resetCpu() {
        previousCpu = null
        cpu = null
    }

    function consumeCpu(contents: string) {
        const sample = WidgetLayout.readCpuCounters(contents)
        if (!sample) {
            cpuFailed = true
            resetCpu()
            return
        }
        const load = WidgetLayout.cpuLoad(previousCpu, sample)
        previousCpu = sample
        cpuFailed = false
        cpu = load
    }

    function consumeMemory(contents: string) {
        const sample = WidgetLayout.readMeminfo(contents)
        if (!sample) {
            memoryFailed = true
            memory = null
            return
        }
        memoryFailed = false
        memory = sample.used
    }

    function reload() {
        if (!active)
            return
        stat.reload()
        mem.reload()
    }

    onActiveChanged: {
        resetCpu()
        cpuFailed = false
        memory = null
        memoryFailed = false
        if (active)
            reload()
    }

    property FileView stat: FileView {
        path: "/proc/stat"
        preload: root.active
        printErrors: false
        onLoaded: root.consumeCpu(text())
        onLoadFailed: {
            root.cpuFailed = true
            root.resetCpu()
        }
    }
    property FileView mem: FileView {
        path: "/proc/meminfo"
        preload: root.active
        printErrors: false
        onLoaded: root.consumeMemory(text())
        onLoadFailed: {
            root.memoryFailed = true
            root.memory = null
        }
    }
    property Timer poll: Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.reload()
    }
}
