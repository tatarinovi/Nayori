import QtQuick
import Quickshell
import "tokens"
import "surfaces/desktop"

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool grabbing: false
    Tokens { id: theme; animationsEnabled: false }
    FloatingWindow {
        visible: true
        implicitWidth: 600; implicitHeight: 400
        color: "#606060"
        Item {
            id: capture
            anchors.fill: parent
            DesktopWidgetFrame {
                id: frame
                tokens: theme
                inputOverlay: true
                spec: ({id: "nowplaying", type: "nowplaying", style: "plain", size: "large", x: 0, y: 0})
            }
        }
    }
    function check(ok, message) {
        if (!ok) { console.error("WIDGET_DIM_FAIL " + message); Qt.exit(1) }
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            test.ticks++
            test.check(test.ticks < 50, "timeout")
            if (test.grabbing) return
            if (test.phase === 0) {
                frame.forceActiveFocus()
                test.phase++
            } else if (test.phase === 1 || test.phase === 2) {
                test.check(frame.inputVisible, "focused interactive copy")
                test.check(frame.layer.enabled === (test.phase === 2), "layer follows dim")
                test.grabbing = true
                const name = test.phase === 1 ? "before" : "after"
                capture.grabToImage(result => {
                    test.check(result.saveToFile(Quickshell.env("NAYORI_WIDGET_DIM_DIR") + "/" + name + ".png"), "capture")
                    frame.desktopDimOpacity = 0.5
                    test.phase++
                    test.grabbing = false
                })
            } else {
                frame.inputOverlay = false
                test.check(!frame.layer.enabled, "background copy avoids second dim")
                console.log("WIDGET_DIM_PASS")
                Qt.quit()
            }
        }
    }
}
