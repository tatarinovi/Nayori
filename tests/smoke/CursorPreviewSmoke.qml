pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "tokens" as Theme
import "surfaces/settings"

ShellRoot {
    id: root
    Theme.Tokens { id: theme }
    property int attempts: 0
    property bool resized: false
    function findImage(item) {
        if (item.objectName === "cursorPreviewImage") return item
        for (const child of item.children || []) {
            const found = findImage(child)
            if (found) return found
        }
        return null
    }
    property Item fixture: Item {
        width: 480
        height: 640
        CursorControls { id: controls; width: parent.width; tokens: theme }
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            root.attempts++
            if (root.attempts > 60) {
                console.error("CURSOR_PREVIEW_FAIL timed out")
                Qt.quit()
                return
            }
            const image = root.findImage(root.fixture)
            if (!controls.preview || !image || image.status !== Image.Ready) return
            if (!root.resized && (controls.draftTheme !== "PreviewTest" || controls.preview.size !== 24)) {
                console.error("CURSOR_PREVIEW_FAIL initial theme/size")
                Qt.quit()
                return
            }
            if (!root.resized) {
                controls.draftSize = 48
                root.resized = true
                return
            }
            if (!controls.preview || controls.preview.size !== 48 || image.width !== 48) {
                console.error("CURSOR_PREVIEW_FAIL size selection")
                Qt.quit()
                return
            }
            console.log("CURSOR_PREVIEW_PASS")
            Qt.quit()
        }
    }
}
