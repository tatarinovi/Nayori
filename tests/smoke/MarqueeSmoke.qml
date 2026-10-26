import QtQuick
import Quickshell
import "surfaces/island"
ShellRoot {
    id: root
    QtObject {
        id: theme
        property QtObject motion: QtObject { property bool off: false; property int base: 220 }
        property QtObject color: QtObject { property color textMuted: "white"; property color text: "white" }
        property QtObject type: QtObject {
            property QtObject body: QtObject { property string family: "sans-serif"; property int size: 14; property int weight: Font.Normal }
        }
    }
    QtObject {
        id: onceTheme
        property QtObject motion: QtObject { property bool off: false; property int base: 220 }
        property var color: theme.color
        property var type: theme.type
    }
    property real stoppedOffset: 0
    TextMetrics {
        id: onceMetrics
        text: "One pass title"
        font.family: "sans-serif"; font.pixelSize: 14; font.weight: Font.Normal
    }
    FloatingWindow {
        visible: true
        implicitWidth: 352; implicitHeight: 48
        MarqueeText {
            id: once
            tokens: onceTheme; loop: false
            width: onceMetrics.advanceWidth - 28; height: 48
            text: onceMetrics.text
        }
        MarqueeText { id: title; tokens: theme; width: 100; height: 48; text: "A very long track title that must scroll without moving the controls" }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            root.check(title.scrolling && title.offset > 0, "long title moves")
            title.active = false
            root.check(!title.scrolling && title.offset === 0, "inactive title stops and resets")
            title.active = true
            theme.motion.off = true
            root.check(!title.scrolling && title.offset === 0, "reduced motion stops and resets")
            theme.motion.off = false
            title.text = "Short"
        }
    }
    Timer {
        interval: 1700; running: true
        onTriggered: {
            root.check(!title.scrolling && title.offset === 0, "short title stays still")
            title.text = "Another long title that must scroll from the beginning"
        }
    }
    Timer {
        interval: 3000; running: true
        onTriggered: {
            root.check(title.scrolling && title.offset > 0, "new title restarts")
            title.width = 1000
        }
    }
    Timer {
        interval: 2400; running: true
        onTriggered: {
            root.check(once.offset > 0 && Math.abs(once.offset - 28) < 0.5, "single pass stops with the end of the text visible")
            root.stoppedOffset = once.offset
        }
    }
    Timer {
        interval: 3200; running: true
        onTriggered: {
            root.check(!title.scrolling && title.offset === 0, "resizing clears scrolling")
            root.check(once.offset === root.stoppedOffset, "single pass stays at the end without restarting")
            once.text = "Next single pass title"
            Qt.callLater(function() {
                root.check(once.offset === 0, "new single pass text starts at the beginning")
                console.log("MARQUEE_SMOKE_PASS")
                Qt.quit()
            })
        }
    }
}
