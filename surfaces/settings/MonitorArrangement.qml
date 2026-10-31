pragma ComponentBehavior: Bound

import QtQuick
import "MonitorLayout.js" as MonitorLayout

// Схема мониторов. Перетаскивание двигает блок, координаты считает MonitorLayout.
FocusScope {
    id: root

    required property var tokens
    property var monitors: []
    property string selectedName: ""
    property string primaryName: ""
    property bool snap: true
    property string dragName: ""
    property real dragX: 0
    property real dragY: 0
    signal chosen(string name)
    signal arranged(var monitors)

    implicitHeight: 232
    height: 232
    activeFocusOnTab: true
    Accessible.name: "Расположение мониторов"
    Accessible.role: Accessible.Pane

    readonly property var frame: MonitorLayout.view(monitors, Math.max(0, width), Math.max(0, height - 0), 24)

    function logicalX(item) {
        return dragName === item.name ? dragX : item.x
    }

    function logicalY(item) {
        return dragName === item.name ? dragY : item.y
    }

    function finish(name, x, y) {
        arranged(MonitorLayout.drop(monitors, name, x, y, snap))
    }

    Rectangle {
        id: stage
        anchors.fill: parent
        radius: root.tokens.radius.medium
        color: root.tokens.color.background
        border.width: 1
        border.color: root.tokens.color.border
        clip: true

        Canvas {
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = Qt.rgba(root.tokens.color.textMuted.r, root.tokens.color.textMuted.g, root.tokens.color.textMuted.b, 0.28)
                for (let y = 10; y < height; y += 16) {
                    for (let x = 10; x < width; x += 16)
                        ctx.fillRect(x, y, 1.4, 1.4)
                }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Repeater {
            model: root.monitors
            delegate: Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool selected: modelData.name === root.selectedName
                readonly property bool dragging: modelData.name === root.dragName
                x: root.frame.ox + root.logicalX(modelData) * root.frame.scale
                y: root.frame.oy + root.logicalY(modelData) * root.frame.scale
                width: Math.max(72, modelData.width * root.frame.scale)
                height: Math.max(48, modelData.height * root.frame.scale)
                radius: root.tokens.radius.small
                color: root.tokens.color.surfaceAlt
                border.width: selected || dragging ? 2 : 1
                border.color: selected || dragging ? root.tokens.color.accent : root.tokens.color.border
                z: dragging ? 3 : selected ? 2 : 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: tile.border.width
                    radius: Math.max(0, tile.radius - 1)
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.alpha(root.tokens.color.accent, 0.55) }
                        GradientStop { position: 0.62; color: Qt.alpha(root.tokens.color.background, 0.2) }
                        GradientStop { position: 1; color: Qt.alpha(root.tokens.color.background, 0.72) }
                    }
                }

                Canvas {
                    id: star
                    visible: root.primaryName !== "" && tile.modelData.name === root.primaryName
                    width: 14
                    height: 14
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    property color ink: root.tokens.color.text
                    onInkChanged: requestPaint()
                    onVisibleChanged: requestPaint()
                    onPaint: {
                        const context = getContext("2d")
                        context.reset()
                        context.fillStyle = ink
                        context.beginPath()
                        const cx = width / 2
                        const cy = height / 2
                        const outer = width / 2 - 0.5
                        const inner = outer * 0.42
                        for (let point = 0; point < 5; point++) {
                            const outerAngle = -Math.PI / 2 + point * (Math.PI * 2 / 5)
                            const innerAngle = outerAngle + Math.PI / 5
                            const ox = cx + Math.cos(outerAngle) * outer
                            const oy = cy + Math.sin(outerAngle) * outer
                            if (point === 0)
                                context.moveTo(ox, oy)
                            else
                                context.lineTo(ox, oy)
                            context.lineTo(cx + Math.cos(innerAngle) * inner, cy + Math.sin(innerAngle) * inner)
                        }
                        context.closePath()
                        context.fill()
                    }
                }

                Rectangle {
                    x: 8
                    y: 8
                    width: 22
                    height: 22
                    radius: 11
                    color: tile.selected ? root.tokens.color.accent : Qt.alpha(root.tokens.color.background, 0.72)
                    border.width: 1
                    border.color: root.tokens.color.accent
                    Text {
                        anchors.centerIn: parent
                        text: String(tile.index + 1)
                        color: tile.selected ? root.tokens.color.accentText : root.tokens.color.text
                        font.family: root.tokens.type.small.family
                        font.pixelSize: 12
                        font.weight: 600
                        textFormat: Text.PlainText
                    }
                }

                Column {
                    anchors.centerIn: parent
                    width: tile.width - 16
                    spacing: 2
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.name || "Экран"
                        color: root.tokens.color.text
                        font.family: root.tokens.type.body.family
                        font.pixelSize: 16
                        font.weight: 600
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: tile.modelData.modeLabel
                        color: root.tokens.color.text
                        font.family: root.tokens.type.small.family
                        font.pixelSize: root.tokens.type.small.size
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: tile.modelData.locked ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                    Accessible.name: (tile.modelData.name || "Экран") + (tile.modelData.name === root.primaryName && root.primaryName !== "" ? ", основной" : "") + (tile.selected ? ", выбран" : "")
                    Accessible.role: Accessible.Button
                    property real originX: 0
                    property real originY: 0
                    property real pressStageX: 0
                    property real pressStageY: 0
                    onPressed: mouse => {
                        const pos = mapToItem(stage, mouse.x, mouse.y)
                        originX = tile.modelData.x
                        originY = tile.modelData.y
                        pressStageX = pos.x
                        pressStageY = pos.y
                        root.dragName = tile.modelData.name
                        root.dragX = originX
                        root.dragY = originY
                        root.chosen(tile.modelData.name)
                        root.forceActiveFocus()
                    }
                    onPositionChanged: mouse => {
                        if (!pressed || tile.modelData.locked)
                            return
                        const pos = mapToItem(stage, mouse.x, mouse.y)
                        const scale = root.frame.scale > 0 ? root.frame.scale : 1
                        root.dragX = originX + (pos.x - pressStageX) / scale
                        root.dragY = originY + (pos.y - pressStageY) / scale
                    }
                    onReleased: {
                        const moved = !tile.modelData.locked && Math.hypot(root.dragX - originX, root.dragY - originY) > 1
                        const name = tile.modelData.name
                        const x = root.dragX
                        const y = root.dragY
                        root.dragName = ""
                        if (moved)
                            root.finish(name, x, y)
                    }
                    onCanceled: root.dragName = ""
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (root.selectedName === "" || root.dragName !== "")
            return
        let dx = 0
        let dy = 0
        if (event.key === Qt.Key_Left)
            dx = -80
        else if (event.key === Qt.Key_Right)
            dx = 80
        else if (event.key === Qt.Key_Up)
            dy = -80
        else if (event.key === Qt.Key_Down)
            dy = 80
        else
            return
        let current = null
        for (let index = 0; index < root.monitors.length; index++) {
            if (root.monitors[index].name === root.selectedName)
                current = root.monitors[index]
        }
        if (!current || current.locked)
            return
        root.finish(current.name, current.x + dx, current.y + dy)
        event.accepted = true
    }
}
