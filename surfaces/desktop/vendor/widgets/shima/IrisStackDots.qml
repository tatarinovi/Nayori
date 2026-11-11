import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick




// The page dots of a widget stack, in the gutter of the plate. The lit one is a single mark that travels to the
// page shown on the widget's own move curve; a dot turns to its page.
Item {
    readonly property var nayoriIrisStackDots: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    required property var face
    readonly property var stack: root.face.widget.stack
    readonly property int count: root.stack ? root.stack.count : 0
    readonly property int current: root.stack ? root.stack.shownIndex : 0
    readonly property real dot: root.face.dp(6)
    readonly property real gap: root.face.dp(6)
    readonly property real pitch: root.dot + root.gap

    width: root.face.padding
    height: root.count * root.dot + Math.max(0, root.count - 1) * root.gap + root.face.dp(16)

    Item {
        id: track
        anchors.centerIn: parent
        width: root.dot
        height: root.count * root.dot + Math.max(0, root.count - 1) * root.gap

        Repeater {
            model: root.count

            Rectangle {
                id: mark
                required property int index
                x: 0
                y: mark.index * root.pitch
                width: root.dot
                height: root.dot
                radius: root.dot / 2
                color: root.face.inkTertiary

                TapHandler {
                    margin: root.gap / 2
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: DesktopWidgetStacks.show(root.face.widget.outputName, root.stack.id, root.stack.keys[mark.index])
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }

        Rectangle {
            y: root.current * root.pitch
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            color: root.face.ink
            Behavior on y {
                enabled: nayoriIrisStackDots.irisStyle.motionEnabled
                NumberAnimation {
                    duration: nayoriIrisStackDots.irisStyle.moveDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: nayoriIrisStackDots.irisStyle.moveCurve
                }
            }
        }
    }

    Accessible.role: Accessible.PageTabList
    Accessible.name: root.count > 0 ? nayoriIrisStackDots.translation.tr("Page %1 of %2").arg(root.current + 1).arg(root.count) : ""
}
