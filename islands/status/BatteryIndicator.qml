import QtQuick
import "../shared"

Item {
    id: root
    required property var tokens
    property var device: null
    property bool onBattery: true
    readonly property bool available: !!device && device.ready && device.isPresent
        && typeof device.percentage === "number" && isFinite(device.percentage)
    readonly property int percent: available ? Math.round(Math.max(0, Math.min(1, device.percentage)) * 100) : 0
    readonly property string description: "Аккумулятор: " + percent + "% · " + (onBattery ? "от батареи" : "подключено к сети")
    visible: available
    width: icon.width + 4 + label.implicitWidth
    height: tokens.panel.control
    Accessible.role: Accessible.StaticText
    Accessible.name: description

    Item {
        id: icon
        width: 22
        height: 32
        Rectangle {
            x: 1; y: 10; width: 18; height: 12; radius: 2
            color: "transparent"
            border.width: 1.5
            border.color: root.tokens.color.text
            Rectangle {
                x: 3; y: 3; height: 6
                width: 12 * root.percent / 100
                radius: 1
                color: root.onBattery && root.percent <= 20 ? root.tokens.color.secondary : root.tokens.color.accent
            }
        }
        Rectangle { x: 19; y: 13; width: 2; height: 6; radius: 1; color: root.tokens.color.text }
    }
    Text {
        id: label
        anchors.left: icon.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: root.percent + "%"
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
        font.features: ({ "tnum": 1 })
    }
    HoverHandler { id: hover }
    PanelTooltip { tokens: root.tokens; target: root; hovered: hover.hovered; text: root.description }
}
