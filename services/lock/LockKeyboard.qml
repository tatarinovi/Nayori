import QtQuick
import Quickshell.Io
import "../niri"

QtObject {
    id: root
    property bool enabled: false
    property bool capsLock: false
    readonly property string layout: Niri.keyboardLayout
    readonly property bool canSwitch: Niri.available
    function nextLayout() { if (canSwitch && !switcher.running) switcher.running = true }
    property Process layoutProcess: Process {
        id: switcher
        command: ["niri", "msg", "action", "switch-layout", "next"]
    }
    property Process leds: Process {
        running: root.enabled
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("keyboard_leds.py").toString()).replace(/^file:\/\//, "")]
        stdout: SplitParser { onRead: line => root.capsLock = line === "1" }
    }
}
