import QtQuick
import QtQuick.Window
import Quickshell
import "sddm/nayori/components"
import "surfaces/lock"
import "tokens"

ShellRoot {
    id: root
    property bool loginMode: Quickshell.env("NAYORI_AUTH_PREVIEW") === "login"
    readonly property bool dynamicPalette: Quickshell.env("NAYORI_AUTH_DYNAMIC") === "1"
    Tokens {
        id: themeTokens
        accentDerived: root.dynamicPalette
        accentSource: "#81C8BE"
        neutralDerived: root.dynamicPalette
        backgroundSource: "#172626"
        surfaceSource: "#3D5650"
        surfaceAltSource: "#293E38"
    }
    readonly property var themeColors: themeTokens.color
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const result = find(child, name)
            if (result) return result
        }
        return null
    }
    QtObject {
        id: musicModel
        property real position: 134
        property var player: ({trackTitle: "Night Drive", trackArtist: "Nayori Radio", trackArtUrl: Qt.resolvedUrl("assets/wallpapers/nayori.png"), length: 277, positionSupported: true, canGoPrevious: true, canGoNext: true, canTogglePlaying: true, isPlaying: true})
    }
    Window {
        id: window
        width: 2560; height: 720; visible: true
        color: themeColors.background
        Item {
            id: board
            anchors.fill: parent
            AuthView {
                id: primary
                width: 1280; height: 720
                colors: themeColors
                wallpaper: Qt.resolvedUrl("assets/wallpapers/nayori.png")
                username: "katamy"
                loginMode: root.loginMode
                usersModel: [{name: "katamy"}, {name: "Другой пользователь"}]
                sessionsModel: [{name: "Niri"}, {name: "Plasma (Wayland)"}]
                canSuspend: true; canReboot: true; canPowerOff: true
                layoutName: "EN"
                mediaComponent: media
                Component { id: media; LockMusic { colors: themeColors; music: musicModel } }
            }
            AuthView {
                x: 1280; width: 1280; height: 720
                colors: themeColors
                primary: false
                wallpaper: Qt.resolvedUrl("assets/wallpapers/nayori.png")
            }
            Rectangle { x: 1280; height: parent.height; width: 2; color: themeColors.accent }
        }
    }
    Timer {
        interval: 500; running: Quickshell.env("NAYORI_AUTH_POWER_MENU") === "1"
        onTriggered: root.find(primary, "authPowerButton").clicked()
    }
    Timer {
        interval: 1200; running: true
        onTriggered: {
            const path = Quickshell.env("NAYORI_AUTH_SCREENSHOT")
            if (path) window.contentItem.grabToImage(result => {
                if (!result.saveToFile(path)) throw new Error("Screenshot failed")
                console.log("AUTH_PREVIEW_SAVED")
                Qt.quit()
            })
        }
    }
}
