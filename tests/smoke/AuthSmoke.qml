import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import "sddm/nayori/components"
import "surfaces/lock"

ShellRoot {
    id: root
    property int submissions: 0
    property var powerActions: []
    function check(ok, reason) { if (!ok) throw new Error(reason) }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    AuthPalette { id: palette; accent: "#81C8BE"; background: "#172626" }
    AuthPowerMenu {
        id: powerMenu
        colors: palette
        canSuspend: true; canReboot: true; canPowerOff: true
        onRequested: action => root.powerActions.push(action)
    }
    Window {
        width: 1280; height: 720; visible: true
        AuthView {
            id: view
            anchors.fill: parent
            colors: palette
            username: "test"
            wallpaper: Qt.resolvedUrl("assets/wallpapers/nayori.png")
            onSubmitted: secret => {
                root.check(secret === "abc", "submitted secret")
                root.check(root.find(view, "authPassword").text === "", "clear before delivery")
                root.submissions++
            }
        }
    }
    Timer {
        interval: 500; running: true
        onTriggered: {
            const field = root.find(view, "authPassword")
            root.check(!!field, "password exists")
            root.check(root.find(view, "authAvatar").cornerRadius === 12, "rounded square avatar matches Start")
            root.check(powerMenu.popupType === Popup.Item, "power menu stays in lock surface")
            for (let i = 0; i < powerMenu.count; ++i) powerMenu.itemAt(i).triggered()
            root.check(root.powerActions.join(",") === "suspend,reboot,powerOff", "all power menu actions")
            powerMenu.canReboot = false
            root.check(!powerMenu.itemAt(1).enabled, "power capabilities")
            root.check(view.colors.accent.toString() === "#81c8be", "dynamic accent")
            view.relayKey("abc", 0)
            view.relayKey("", Qt.Key_Return)
            root.check(root.submissions === 1, "submit once")
            view.busy = true
            view.relayKey("abc", 0)
            root.check(field.text === "", "ignore input while busy")
            view.busy = false
            view.relayKey("private", 0)
            view.primary = false
            root.check(field.text === "", "clear on primary change")
            root.check(!root.find(view, "authSidebar").visible, "secondary wallpaper only")
            view.relayKey("abc", 0)
            root.check(field.text === "", "secondary cannot keep password")
            view.primary = true
            view.loginMode = true
            view.usersModel = [{ name: "test" }, { name: "other" }]
            view.sessionsModel = [{ name: "Niri" }, { name: "Plasma" }]
            root.check(root.find(view, "authSession").visible, "login session choice")
            root.check(root.find(view, "authUser").visible, "login user choice")
            view.relayKey("abc", 0)
            view.username = "other"
            root.check(field.text === "", "clear on user change")
            palette.accent = "#E5C890"
            root.check(view.colors.accent.toString() === "#e5c890", "live theme change")
            console.log("AUTH_SMOKE_PASS")
            Qt.quit()
        }
    }
}
