import QtQuick
import Quickshell
import "tokens"
import "surfaces/panel"
ShellRoot {
    Tokens { id: theme; surfaceStyle: "frosted" }
    QtObject {
        id: state
        property string preferredTerminal: "kitty"
        property string preferredFileManager: "io.github.lgse.Strata"
        property var overlayScreen
        property bool launcherOpened: false
        function openSettings(page) {}
    }
    FloatingWindow {
        id: window
        implicitWidth: 450; implicitHeight: 540
        color: theme.color.background
        StartButton { id: button; tokens: theme; x: 30; y: 480 }
    }
    StartMenu {
        id: menu
        tokens: theme; shellState: state
        panelScreen: window.screen; anchorItem: button; anchorWindow: window
    }
    Timer {
        interval: 600; running: true
        onTriggered: menu.opened = true
    }
    Timer {
        interval: 1800; running: true
        onTriggered: {
            menu.menuContent.grabToImage(function(result) {
                result.saveToFile("/tmp/nayori-start-menu.png")
                menu.showPage("power")
                if (menu.page !== "power") throw new Error("Power navigation failed")
                Qt.callLater(function() {
                    menu.menuContent.grabToImage(function(powerImage) {
                        powerImage.saveToFile("/tmp/nayori-start-power.png")
                        finishChecks()
                    })
                })
            })
        }
    }
    property int motionStage: 0
    Timer {
        id: motionCheck
        interval: 60
        repeat: true
        onTriggered: {
            if (motionStage === 0) {
                if (!menu.visible || menu.reveal <= 0 || menu.reveal >= 1)
                    throw new Error("Exit did not animate")
                if (menu.blurBounds.height !== menu.revealedHeight || menu.revealedHeight >= menu.menuHeight)
                    throw new Error("Blur did not shrink with the menu")
                menu.opened = true
            } else if (motionStage === 1) {
                if (!menu.visible || menu.reveal <= 0)
                    throw new Error("Interrupted exit did not reopen")
                theme.animationsEnabled = false
                menu.opened = false
            } else if (motionStage === 2) {
                if (menu.blurBounds.height !== 0) throw new Error("Blur survived reduced-motion close")
                if (menu.visible || menu.presenting || menu.reveal !== 0)
                    throw new Error("Reduced motion did not close immediately")
                menu.opened = true
            } else if (motionStage === 3) {
                if (!menu.visible || menu.reveal !== 1)
                    throw new Error("Reduced motion did not open immediately")
                theme.animationsEnabled = true
                menu.showPage("power")
                interval = 350
            } else if (motionStage === 4) {
                menu.dismissOutside()
                if (menu.opened || !menu.presenting)
                    throw new Error("External dismissal did not start fade")
            } else {
                if (menu.blurBounds.height !== 0) throw new Error("Blur survived close")
                if (menu.presenting || menu.reveal !== 0)
                    throw new Error("External dismissal did not finish fade")
                console.log("START_MENU_RENDER_AND_MOTION_OK")
                Qt.quit()
            }
            motionStage++
        }
    }
    function finishChecks() {
                menu.dismissEscape()
                if (menu.page !== "main")
                    throw new Error("Escape failed")
                if (menu.menuContent.y + menu.menuContent.height > menu.height - theme.spacing.small - theme.panel.height)
                    throw new Error("Menu must clear the panel")
                menu.dismissOutside()
                if (menu.opened) throw new Error("External dismissal did not close menu")
                menu.toggle()
                if (!menu.opened) throw new Error("Subsequent click did not open menu")
                menu.opened = false
                motionStage = 0
                motionCheck.restart()
    }
}
