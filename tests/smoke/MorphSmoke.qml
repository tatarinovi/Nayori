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
            onLauncherDismissed: launcherOpen = false
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
                island.expanded = false
                island.launcherOpen = true
                Qt.callLater(function() {
                    check(Math.abs(island.width - island.launcherWidth) < 1, "launcher width")
                    check(Math.abs(island.height - 48) < 1, "launcher is the search row")
                    check(island.launcherBlend === 1, "launcher blend settled")
                    check(island.searchFocused, "search field focused")
                    check(!island.outsidePress(8, 8), "inside press")
                    check(island.launcherOpen, "inside press stays open")
                    check(island.outsidePress(-12, 8), "outside press")
                    check(!island.launcherOpen, "outside press closes")
                    Qt.callLater(function() {
                        check(Math.abs(island.width - 352) < 1 && Math.abs(island.height - 48) < 1, "outside close returns to capsule")
                        check(!island.searchFocused, "close releases focus")
                        island.launcherOpen = true
                        Qt.callLater(function() {
                            check(island.searchFocused, "reopen focuses search")
                            island.launcherOpen = false
                            Qt.callLater(function() {
                                check(!island.searchFocused, "second close releases focus")
                                check(Math.abs(island.width - 352) < 1 && Math.abs(island.height - 48) < 1, "launcher returns to capsule")
                                console.log("MORPH_ISLAND_PASS")
                                Qt.quit()
                            })
                        })
                    })
                })
            })
        }
    }
}
