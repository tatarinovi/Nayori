import QtQuick
import Quickshell
import "surfaces/island"
ShellRoot {
    QtObject {
        id: theme
        property QtObject motion: QtObject { property bool off: false }
        property QtObject color: QtObject { property color textMuted: "white" }
        property QtObject type: QtObject {
            property QtObject body: QtObject { property string family: "sans-serif"; property int size: 14; property int weight: Font.Normal }
        }
    }
    FloatingWindow {
        visible: true
        implicitWidth: 352; implicitHeight: 48
        MarqueeText { id: title; tokens: theme; width: 100; height: 48; text: "A very long track title that must scroll without moving the controls" }
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    Timer {
        interval: 1500; running: true
        onTriggered: {
            check(title.scrolling && title.offset > 0, "long title moves")
            title.active = false
            check(!title.scrolling && title.offset === 0, "inactive title stops and resets")
            title.active = true
            theme.motion.off = true
            check(!title.scrolling && title.offset === 0, "reduced motion stops and resets")
            theme.motion.off = false
            title.text = "Short"
        }
    }
    Timer {
        interval: 1700; running: true
        onTriggered: {
            check(!title.scrolling && title.offset === 0, "short title stays still")
            title.text = "Another long title that must scroll from the beginning"
        }
    }
    Timer {
        interval: 3000; running: true
        onTriggered: {
            check(title.scrolling && title.offset > 0, "new title restarts")
            title.width = 1000
        }
    }
    Timer {
        interval: 3200; running: true
        onTriggered: {
            check(!title.scrolling && title.offset === 0, "resizing clears scrolling")
            console.log("MARQUEE_SMOKE_PASS")
            Qt.quit()
        }
    }
}
