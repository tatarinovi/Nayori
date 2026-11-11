import QtQuick
import Quickshell
import "tokens"
import "surfaces/desktop"

ShellRoot {
    id: root
    Tokens { id: theme }
    property int stage: 0
    property int executions: 0
    property var power: null
    function check(ok, message) { if (!ok) throw new Error("DESKTOP_CONTEXT_FAIL: " + message) }
    FloatingWindow {
        implicitWidth: 380; implicitHeight: 300
        visible: true
        color: "#202020"
        DesktopContextMenu {
            id: menu
            tokens: theme
            x: 16; y: 16
            width: implicitWidth; height: implicitHeight
            opened: true
            wallpaperSource: Qt.resolvedUrl("assets/wallpapers/nayori.png")
            onRequested: action => { if (action === "lock") root.executions++ }
        }
    }
    Timer {
        id: steps
        interval: 650; running: true; repeat: true
        onTriggered: {
            const buttons = menu.buttons()
            if (root.stage === 0) {
                root.check(buttons.length === 9, "exact menu actions")
                root.check(menu.width <= 344 && menu.height < 250, "compact bounds")
                root.check(buttons[0].text === "Обои" && buttons[2].text === "Терминал", "quick actions")
                root.power = buttons[5]
                for (let i = 5; i < buttons.length; i++) buttons[i].clicked()
                root.check(root.executions === 0, "click must not execute")
                root.power.forceActiveFocus()
                root.power.down = true
                interval = 180
            } else if (root.stage === 1) {
                root.check(root.power.holdProgress > 0 && root.power.holdProgress < 1, "visible hold progress")
                root.check(root.power.backgroundProgress === root.power.holdProgress, "hold fills button background")
                root.check(root.power.frostedTile && buttons[0].frostedTile, "shared frosted tile style")
                root.check(String(buttons[0].backdropSource) === String(menu.wallpaperSource), "current wallpaper passed to tile")
                const preview = buttons[0].background.children.find(item => item.objectName === "menu-wallpaper-preview")
                root.check(preview.width === buttons[0].width && preview.height === buttons[0].height, "wallpaper covers complete tile without inset")
                root.power.down = false
                interval = 650
            } else if (root.stage === 2) {
                root.check(root.executions === 0 && root.power.holdProgress === 0, "early release cancels")
                root.power.down = true
            } else if (root.stage === 3) {
                root.check(root.executions === 1, "hold executes once")
            } else if (root.stage === 4) {
                root.check(root.executions === 1, "long hold does not repeat")
                root.power.down = false
                root.power.down = true
                menu.opened = false
            } else if (root.stage === 5) {
                root.check(root.executions === 1, "closing cancels pending hold")
                root.power.down = false
                theme.animationsEnabled = false
                menu.opened = true
                root.power.forceActiveFocus()
                root.power.down = true
                interval = 180
            } else if (root.stage === 6) {
                root.check(root.executions === 1 && menu.opacity === 1, "reduced motion preserves hold delay")
                menu.busy = true
                interval = 650
            } else if (root.stage === 7) {
                root.check(root.executions === 1, "busy cancels hold")
                menu.busy = false
                root.power.down = false
                menu.grabToImage(result => result.saveToFile("/tmp/nayori-desktop-context.png"))
            } else if (root.stage === 8) {
                theme.animationsEnabled = true
                menu.opened = false
                interval = 40
            } else if (root.stage === 9) {
                root.check(menu.visible && menu.opacity > 0 && menu.opacity < 1, "close retains intermediate frame")
                root.check(!menu.enabled && menu.scale < 1, "closing disables input and scales down")
                menu.opened = true
            } else if (root.stage === 10) {
                root.check(menu.visible && menu.opacity > 0 && menu.enabled, "interrupted close reopens")
                menu.opened = false
                interval = 650
            } else if (root.stage === 11) {
                root.check(!menu.presenting && !menu.visible && menu.opacity === 0, "close releases presentation")
                theme.animationsEnabled = false
                menu.opened = true
                root.check(menu.opacity === 1 && menu.visible, "reduced motion opens immediately")
                menu.opened = false
                root.check(menu.opacity === 0 && !menu.presenting, "reduced motion closes immediately")
            } else {
                console.log("DESKTOP_CONTEXT_PASS")
                Qt.quit()
            }
            root.stage++
        }
    }
}
