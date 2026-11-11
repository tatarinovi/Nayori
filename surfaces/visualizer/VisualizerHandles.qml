pragma ComponentBehavior: Bound
import QtQuick
import "vendor"

Item {
    id: root
    required property VizItem cfg
    required property var service
    required property var tokens
    focus: visible && selected
    readonly property bool fullFrame: cfg.isAura || cfg.styleId === "frame"
    readonly property bool selected: service.selectedId === cfg.instanceId
    Item {
        id: box
        x: root.fullFrame ? 8 : root.cfg.x * root.width
        y: root.fullFrame ? 8 : root.cfg.y * root.height
        width: root.fullFrame ? root.width - 16 : root.cfg.w * root.width
        height: root.fullFrame ? root.height - 16 : root.cfg.h * root.height
        rotation: root.fullFrame ? 0 : root.cfg.angle
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: root.selected ? root.tokens.color.accent : root.tokens.color.border
            border.width: root.selected ? 2 : 1
            radius: 6
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: root.fullFrame ? Qt.PointingHandCursor : Qt.SizeAllCursor
            property point start
            property point origin
            onPressed: mouse => {
                root.service.select(root.cfg.instanceId)
                root.forceActiveFocus()
                start = mapToItem(root, mouse.x, mouse.y)
                origin = Qt.point(root.cfg.x, root.cfg.y)
            }
            onPositionChanged: mouse => {
                if (!pressed || root.fullFrame) return
                const p = mapToItem(root, mouse.x, mouse.y)
                root.service.patch(root.cfg.instanceId, {x: origin.x + (p.x - start.x) / root.width, y: origin.y + (p.y - start.y) / root.height})
            }
        }
        Repeater {
            model: root.selected && !root.fullFrame ? 4 : 0
            delegate: Rectangle {
                id: corner
                required property int index
                readonly property bool rightSide: index % 2 === 1
                readonly property bool bottomSide: index >= 2
                x: (rightSide ? box.width : 0) - width / 2
                y: (bottomSide ? box.height : 0) - height / 2
                width: 24; height: 24; radius: 12
                color: root.tokens.color.accent
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SizeFDiagCursor
                    property point start
                    property var before
                    onPressed: mouse => { start = mapToItem(root, mouse.x, mouse.y); before = {x: root.cfg.x, y: root.cfg.y, w: root.cfg.w, h: root.cfg.h, angle: root.cfg.angle} }
                    onPositionChanged: mouse => {
                        if (!pressed) return
                        const p = mapToItem(root, mouse.x, mouse.y)
                        const a = before.angle * Math.PI / 180
                        const dx = p.x - start.x, dy = p.y - start.y
                        const lx = dx * Math.cos(a) + dy * Math.sin(a), ly = -dx * Math.sin(a) + dy * Math.cos(a)
                        const w = Math.max(0.05, Math.min(1, before.w + (corner.rightSide ? lx : -lx) / root.width))
                        const h = Math.max(0.05, Math.min(1, before.h + (corner.bottomSide ? ly : -ly) / root.height))
                        const cx = (corner.rightSide ? 1 : -1) * (w - before.w) * root.width / 2
                        const cy = (corner.bottomSide ? 1 : -1) * (h - before.h) * root.height / 2
                        root.service.patch(root.cfg.instanceId, {w: w, h: h,
                            x: before.x + (cx * Math.cos(a) - cy * Math.sin(a)) / root.width + (before.w - w) / 2,
                            y: before.y + (cx * Math.sin(a) + cy * Math.cos(a)) / root.height + (before.h - h) / 2})
                    }
                }
            }
        }
        Rectangle {
            visible: root.selected && !root.fullFrame
            x: (box.width - width) / 2; y: -44
            width: 28; height: 28; radius: 14
            color: root.tokens.color.accent
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                property real offset
                function angleAt(mouse) {
                    const p = mapToItem(root, mouse.x, mouse.y)
                    return Math.atan2(p.y - (root.cfg.y + root.cfg.h / 2) * root.height,
                        p.x - (root.cfg.x + root.cfg.w / 2) * root.width) * 180 / Math.PI
                }
                onPressed: mouse => { offset = root.cfg.angle - angleAt(mouse) }
                onPositionChanged: mouse => {
                    if (pressed) root.service.patch(root.cfg.instanceId, {angle: ((angleAt(mouse) + offset) % 360 + 360) % 360})
                }
            }
        }
    }
}
