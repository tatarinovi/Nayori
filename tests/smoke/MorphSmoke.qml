import QtQuick
import Quickshell
import "tokens"
import "surfaces/island"
ShellRoot {
    Tokens { id: theme }
    function check(value, message) { if (!value) throw new Error(message) }
    FloatingWindow {
        visible: true
        implicitWidth: 712
        implicitHeight: 522
        color: "transparent"
        MorphingIsland {
            id: island
            tokens: theme
            active: false
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
    Timer { interval: 100; running: true; onTriggered: island.expanded = true }
    Timer {
        interval: 240; running: true
        onTriggered: {
            check(island.width > 352 && island.width < 680, "intermediate width")
            check(island.height > 48 && island.height < 490, "intermediate height")
            island.grabToImage(function(image) { image.saveToFile("/tmp/nayori-morph-middle.png") })
        }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            check(island.width === 680 && island.height === 490, "expanded dimensions")
            island.grabToImage(function(image) {
                image.saveToFile("/tmp/nayori-morph-expanded.png")
                island.expanded = false
            })
        }
    }
    Timer {
        interval: 850; running: true
        onTriggered: {
            check(island.width === 352 && island.height === 48, "returns to capsule")
            theme.motion.off = true
            island.expanded = true
            Qt.callLater(function() {
                check(island.width === 680 && island.height === 490, "reduced motion immediate")
                console.log("MORPH_ISLAND_PASS")
            })
        }
    }
}
