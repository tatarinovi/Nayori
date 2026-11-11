import QtQuick
import Quickshell
import "tokens"
import "islands/shared"

ShellRoot {
    id: test
    property int sample: 0
    readonly property var samples: [
        "Настройки", "Громкость", "Bluetooth", "Рабочий стол 1",
        "Wi-Fi: подключено", "Firefox", "Батарея · 85%",
        "Очень длинное название приложения, которое должно переноситься по словам и ограничиваться тремя строками",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "Первая строка\nВторая строка", ""
    ]
    Tokens { id: theme }
    FloatingWindow {
        visible: true
        implicitWidth: 400
        implicitHeight: 100
        Item { id: anchorTarget; anchors.centerIn: parent; width: 40; height: 40 }
    }
    PanelTooltip {
        id: tooltip
        tokens: theme
        target: anchorTarget
        text: test.samples[test.sample]
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            const label = tooltip.contentItem.children[0].children[0]
            test.check(tooltip.width <= 300, "bounded popup width")
            test.check(label.lineCount <= 3, "bounded line count")
            if (test.sample < 7) {
                test.check(label.width >= label.implicitWidth,
                           "full text width for " + tooltip.text + ": " + label.width + " < " + label.implicitWidth)
                test.check(label.lineCount === 1, "short tooltip stays on one line: " + tooltip.text)
            } else if (test.sample === 7 || test.sample === 8) {
                test.check(tooltip.width === 300 && label.lineCount > 1, "long tooltip wraps")
            } else if (test.sample === 9) {
                test.check(label.lineCount === 2, "explicit newline preserved")
            } else {
                test.check(!tooltip.visible, "empty tooltip hidden")
            }
            if (test.sample === test.samples.length - 1) {
                stop()
                console.log("PANEL_TOOLTIP_PASS")
                Qt.quit()
            } else {
                ++test.sample
            }
        }
    }
}
