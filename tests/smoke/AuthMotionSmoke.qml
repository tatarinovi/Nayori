import QtQuick
import QtQuick.Window
import Quickshell
import "sddm/nayori/components"

ShellRoot {
    id: root
    property int stage: 0
    AuthPalette { id: palette }
    Window {
        visible: true; width: 1280; height: 720
        AuthView { id: view; anchors.fill: parent; colors: palette; username: "test" }
    }
    Timer {
        interval: 300; running: true; repeat: true
        onTriggered: {
            if (root.stage === 0) {
                if (Math.abs(view.reveal - 1) > 0.001) throw new Error("entry did not finish")
                view.exiting = true
                if (view.reveal < 0.9) throw new Error("exit skipped animation")
                root.stage++
            } else {
                if (view.reveal > 0.001) throw new Error("exit did not finish")
                view.animationsEnabled = false
                view.exiting = false
                if (view.reveal !== 1) throw new Error("disabled motion must be immediate")
                view.exiting = true
                if (view.reveal !== 0) throw new Error("disabled exit must be immediate")
                console.log("AUTH_MOTION_SMOKE_PASS")
                Qt.quit()
            }
        }
    }
}
