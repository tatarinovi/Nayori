// Isolated renderer: no layer-shell windows and no writes to system services.
// QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=basic \
// timeout 7s qs -p PanelSmoke.qml --no-color
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "tokens"
import "surfaces/island"
import "islands/status"
import "islands/apps"
import "islands/workspaces"

ShellRoot {
    id: root
    Tokens { id: theme }
    Cpu { id: cpuTest; active: false }
    property int stage: 0
    property bool nestedMenuTested: false
    function check(condition, message) {
        if (!condition)
            throw new Error("SMOKE_FAIL: " + message)
    }
    function capturePopup(name, nextMenu) {
        for (let i = 0; i < status.data.length; i++) {
            const candidate = status.data[i]
            if (candidate && candidate.toString().indexOf("Popup") >= 0 && candidate.contentItem) {
                const surface = candidate.contentItem.children[0]
                surface.grabToImage(function(image) {
                    image.saveToFile("/tmp/nayori-" + name + ".png")
                    if (nextMenu === "inspect-tray") {
                        const entries = SystemTray.items.values
                        for (let n = 0; n < entries.length; n++) {
                            if (entries[n].hasMenu) {
                                status.openTrayMenu(entries[n], null)
                                break
                            }
                        }
                    } else {
                        status.opened = nextMenu
                    }
                })
            }
        }
    }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 820
        implicitHeight: 180
        color: theme.color.background
        Item {
            id: scene
            anchors.fill: parent
            DynamicIsland {
                id: island
                tokens: theme
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
            }
            WorkspacesIsland { id: workspaces; tokens: theme; x: 24; y: 108 }
            AppsIsland { id: apps; tokens: theme; anchors.horizontalCenter: parent.horizontalCenter; y: 108 }
            StatusIsland { id: status; tokens: theme; menuWindow: window; anchors.right: parent.right; anchors.rightMargin: 24; y: 108 }
        }
    }
    Timer {
        interval: 650
        running: true
        repeat: true
        onTriggered: {
            if (root.stage === 0) {
                root.check(workspaces.height === 48 && apps.height === 56 && status.height === 48, "panel heights")
                root.check(island.width === 352 && island.height === 48, "island geometry")
                root.check(/\d\d:\d\d:\d\d/.test(island.Accessible.name), "clock has seconds")
                cpuTest.active = true
                cpuTest.resetBaseline()
                cpuTest.consume("cpu 100 0 100 800 0 0 0 0 100 0")
                cpuTest.consume("cpu 150 0 100 850 0 0 0 0 150 0")
                root.check(Math.abs(cpuTest.load - 0.5) < 0.0001, "CPU delta, excluding guest")
                cpuTest.consume("invalid")
                root.check(cpuTest.previousTotal === -1, "invalid CPU data resets baseline")
                cpuTest.active = false
                scene.grabToImage(function(image) { image.saveToFile("/tmp/nayori-panel-rest.png") })
                status.opened = "audio"
            } else if (root.stage === 1) {
                root.capturePopup("audio-menu", "network")
            } else if (root.stage === 2) {
                root.capturePopup("network-menu", "tray")
            } else if (root.stage === 3) {
                root.capturePopup("tray-menu", "inspect-tray")
            } else if (root.stage === 4) {
                if (status.currentTrayMenu) {
                    const rows = status.currentTrayMenu.children.values
                    for (let n = 0; n < rows.length; n++) {
                        if (rows[n].hasChildren) {
                            status.pushTrayMenu(rows[n])
                            root.check(status.trayMenuStack.length === 2, "submenu retains parent opener")
                            root.nestedMenuTested = true
                            break
                        }
                    }
                    console.log("TRAY_READ_ONLY_MENU", rows.length, "nested:", root.nestedMenuTested)
                }
            } else if (root.stage === 5) {
                if (root.nestedMenuTested) {
                    root.check(status.currentTrayMenu.menu !== null, "submenu remains live")
                    status.popTrayMenu()
                    root.check(status.trayMenuStack.length === 1, "back retains root opener")
                }
                status.opened = ""
                root.check(status.trayMenuStack.length === 0, "close destroys all menu openers")
                // Only triggers the island view; does not change system volume.
                island.audioInitialized = true
                island.flashVolume()
            } else if (root.stage === 6) {
                scene.grabToImage(function(image) { image.saveToFile("/tmp/nayori-panel-volume.png") })
                root.check(status.opened === "", "menus close")
                root.check(island.width === 352 && island.height === 48, "event keeps fixed geometry")
                console.log("PANEL_SMOKE_PASS")
                stop()
            }
            root.stage++
        }
    }
}
