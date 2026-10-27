pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

// The lock's last frame is mapped underneath the lock on each output, then
// fades over the desktop after PAM succeeds and the compositor unlocks.
Scope {
    id: root
    required property var controller
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: window
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}
            color: "transparent"
            readonly property var shot: root.controller.revealShots[modelData.name]
            readonly property var fallback: root.controller.wallpapers.wallpaper(modelData.name)
            Rectangle {
                id: frame
                anchors.fill: parent
                color: root.controller.tokens.color.background
                opacity: root.controller.revealStage === 3 ? 0 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.controller.tokens.motion.off ? 0 : root.controller.tokens.motion.base
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root.controller.tokens.motion.easeOut
                    }
                }
                Image {
                    anchors.centerIn: parent
                    width: !window.shot && window.fallback.mode === "center" ? implicitWidth : parent.width
                    height: !window.shot && window.fallback.mode === "center" ? implicitHeight : parent.height
                    source: window.shot ? window.shot.url : window.fallback.source
                    fillMode: window.shot ? Image.Stretch
                        : window.fallback.mode === "fill" ? Image.PreserveAspectCrop
                        : window.fallback.mode === "fit" ? Image.PreserveAspectFit : Image.Stretch
                    asynchronous: false
                    cache: false
                    autoTransform: true
                }
            }
            Timer {
                running: true
                interval: 120
                onTriggered: root.controller.revealSurfaceReady(window.modelData.name)
            }
        }
    }
}
