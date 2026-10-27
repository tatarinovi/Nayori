pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../sddm/nayori/components"
import "../../services/system"
import "../../services/lock"

Scope {
    id: root
    required property var controller
    UserProfile { id: profile }
    LockKeyboard { id: keyboard; enabled: true }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: previewWindow
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: screen && screen.name === root.controller.mainOutput ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            AuthView {
                anchors.fill: parent
                colors: root.controller.tokens.color
                primary: !!previewWindow.screen && previewWindow.screen.name === root.controller.mainOutput
                wallpaper: root.controller.wallpapers.wallpaper(previewWindow.screen ? previewWindow.screen.name : "").source
                wallpaperMode: root.controller.wallpapers.wallpaper(previewWindow.screen ? previewWindow.screen.name : "").mode
                username: profile.username
                avatar: profile.avatar
                preview: true
                animationsEnabled: !root.controller.tokens.motion.off
                enterDuration: root.controller.tokens.motion.base
                exitDuration: root.controller.tokens.motion.fast
                motionCurve: root.controller.tokens.motion.easeOut
                canSuspend: true
                canReboot: true
                canPowerOff: true
                onPowerRequested: action => root.controller.status = "Предпросмотр: действие питания не выполняется"
                status: root.controller.status
                mediaComponent: previewMusic
                mediaAvailable: !!root.controller.music && !!root.controller.music.player
                capsLock: keyboard.capsLock
                layoutName: keyboard.layout
                canSwitchLayout: keyboard.canSwitch
                onLayoutRequested: keyboard.nextLayout()
                onSubmitted: value => root.controller.submit(value)
                onPreviewClosed: root.controller.closePreview()
                Keys.onEscapePressed: root.controller.closePreview()
                Component { id: previewMusic; LockMusic { colors: root.controller.tokens.color; music: root.controller.music } }
            }
        }
    }
}
