import QtQuick
import QtQuick.Controls
import "../shared"

Button {
    id: root
    required property var tokens
    property string iconName: ""
    property string hint: ""
    implicitWidth: 32
    implicitHeight: 32
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: hint
    PanelTooltip {
        tokens: root.tokens
        target: root
        hovered: root.hovered && !root.down
        text: root.hint
    }
    scale: down && !tokens.motion.off ? 0.96 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale { NumberAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast; easing.type: Easing.OutCubic } }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down || root.checked ? root.tokens.color.accentSoft
              : root.hovered ? root.tokens.color.surface : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
    }
    contentItem: Item {
        Canvas {
            id: glyph
            anchors.centerIn: parent
            width: 20
            height: 20
            visible: root.iconName !== ""
            property string kind: root.iconName
            property color ink: !root.enabled ? root.tokens.color.textMuted
                : (root.down || root.checked) ? root.tokens.color.accentSoftText
                : root.tokens.color.text
            onKindChanged: requestPaint()
            onInkChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = ink
                ctx.lineWidth = 1.6
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.beginPath()
                if (kind === "chevron-up" || kind === "chevron-down") {
                    const top = kind === "chevron-up" ? 12 : 8
                    const bottom = kind === "chevron-up" ? 7 : 13
                    ctx.moveTo(5, top); ctx.lineTo(10, bottom); ctx.lineTo(15, top)
                } else if (kind === "settings") {
                    for (let i = 0; i < 32; i++) {
                        const angle = i * Math.PI / 16 - Math.PI / 8
                        const radius = i % 4 === 1 || i % 4 === 2 ? 8 : 6.3
                        const x = 10 + Math.cos(angle) * radius
                        const y = 10 + Math.sin(angle) * radius
                        if (i === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.closePath()
                    ctx.moveTo(13, 10); ctx.arc(10, 10, 3, 0, Math.PI * 2)
                } else if (kind === "device-forget") {
                    ctx.moveTo(4, 5); ctx.lineTo(16, 5)
                    ctx.moveTo(8, 2); ctx.lineTo(12, 2)
                    ctx.moveTo(6, 5); ctx.lineTo(7, 17); ctx.lineTo(13, 17); ctx.lineTo(14, 5)
                    ctx.moveTo(9, 8); ctx.lineTo(9, 14)
                    ctx.moveTo(11, 8); ctx.lineTo(11, 14)
                } else if (kind === "device-connect" || kind === "device-disconnect") {
                    ctx.moveTo(7, 3); ctx.lineTo(7, 7)
                    ctx.moveTo(13, 3); ctx.lineTo(13, 7)
                    ctx.moveTo(5, 7); ctx.lineTo(15, 7); ctx.lineTo(15, 10)
                    ctx.quadraticCurveTo(15, 14, 10, 14)
                    ctx.quadraticCurveTo(5, 14, 5, 10); ctx.closePath()
                    ctx.moveTo(10, 14); ctx.lineTo(10, 18)
                    if (kind === "device-disconnect") {
                        ctx.moveTo(3, 3); ctx.lineTo(17, 17)
                    }
                } else if (kind.indexOf("bluetooth") === 0) {
                    ctx.moveTo(6, 6); ctx.lineTo(14, 13); ctx.lineTo(10, 17)
                    ctx.lineTo(10, 3); ctx.lineTo(14, 7); ctx.lineTo(6, 14)
                    if (kind === "bluetooth-off") {
                        ctx.moveTo(3, 3); ctx.lineTo(17, 17)
                    } else if (kind === "bluetooth-unavailable") {
                        ctx.moveTo(17, 4); ctx.lineTo(17, 10)
                        ctx.moveTo(17, 13); ctx.lineTo(17, 13.2)
                    } else if (kind === "bluetooth-connected") {
                        ctx.moveTo(3, 10); ctx.lineTo(4, 10)
                        ctx.moveTo(17, 10); ctx.lineTo(18, 10)
                    }
                } else if (kind.indexOf("audio-") === 0) {
                    ctx.moveTo(3, 8); ctx.lineTo(6, 8); ctx.lineTo(10, 4)
                    ctx.lineTo(10, 16); ctx.lineTo(6, 12); ctx.lineTo(3, 12); ctx.closePath()
                    if (kind.indexOf("muted") >= 0) {
                        ctx.moveTo(14, 8); ctx.lineTo(18, 12)
                        ctx.moveTo(18, 8); ctx.lineTo(14, 12)
                    } else {
                        ctx.moveTo(13, 7); ctx.quadraticCurveTo(16, 10, 13, 13)
                        if (kind.indexOf("high") >= 0 || kind.indexOf("medium") >= 0) {
                            ctx.moveTo(16, 4); ctx.quadraticCurveTo(21, 10, 16, 16)
                        }
                    }
                } else if (kind.indexOf("wireless") >= 0) {
                    ctx.moveTo(2, 6); ctx.quadraticCurveTo(10, 0, 18, 6)
                    ctx.moveTo(5, 10); ctx.quadraticCurveTo(10, 6, 15, 10)
                    ctx.moveTo(8, 13); ctx.quadraticCurveTo(10, 11, 12, 13)
                    ctx.moveTo(10, 16); ctx.lineTo(10, 16.2)
                } else {
                    ctx.rect(5, 2, 10, 8)
                    ctx.moveTo(10, 10); ctx.lineTo(10, 14)
                    ctx.moveTo(3, 17); ctx.lineTo(3, 14); ctx.lineTo(17, 14); ctx.lineTo(17, 17)
                    if (kind.indexOf("offline") >= 0) {
                        ctx.moveTo(2, 2); ctx.lineTo(18, 18)
                    }
                }
                ctx.stroke()
            }
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: root.width > 64 ? 10 : 0
            anchors.rightMargin: root.width > 64 ? 10 : 0
            horizontalAlignment: root.width > 64 ? Text.AlignLeft : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            visible: root.iconName === ""
            text: root.text
            color: root.down || root.checked ? root.tokens.color.accentSoftText : root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
        }
    }
}
