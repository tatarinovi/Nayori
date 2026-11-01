import QtQuick
import Quickshell
import "tokens"
import "islands/status"

ShellRoot {
    id: root
    Tokens { id: theme }
    QtObject { id: battery; property bool ready: true; property bool isPresent: true; property real percentage: 0.57 }
    FloatingWindow {
        visible: true
        implicitWidth: 200; implicitHeight: 80
        BatteryIndicator { id: indicator; tokens: theme; device: battery }
    }
    function check(value, message) { if (!value) throw new Error("BATTERY_FAIL: " + message) }
    Timer {
        interval: 100; running: true
        onTriggered: {
            root.check(indicator.visible && indicator.percent === 57, "initial charge")
            battery.percentage = 0.1
            root.check(indicator.percent === 10 && indicator.description.indexOf("от батареи") >= 0, "discharge update")
            indicator.onBattery = false
            root.check(indicator.description.indexOf("подключено к сети") >= 0, "mains")
            battery.percentage = 2
            root.check(indicator.percent === 100, "clamp")
            battery.percentage = 0
            root.check(indicator.visible && indicator.percent === 0, "empty battery remains visible")
            battery.percentage = NaN
            root.check(!indicator.visible, "invalid charge")
            battery.percentage = 0.5
            battery.isPresent = false
            root.check(!indicator.visible, "absent")
            battery.isPresent = true; battery.ready = false
            root.check(!indicator.visible, "unavailable")
            indicator.device = null
            root.check(!indicator.visible, "missing device")
            console.log("BATTERY_SMOKE_PASS")
            Qt.quit()
        }
    }
}
