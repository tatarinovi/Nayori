pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Row with a label on the left and a pill switch on the right.
CheckBox {
    id: control
    required property var tokens
    property string description: ""
    signal focusReceived()

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(32, contentItem.implicitHeight + 8)
    padding: 0
    spacing: 10
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : 0.45
    Accessible.name: text
    Accessible.description: description
    onActiveFocusChanged: if (activeFocus) focusReceived()

    background: Rectangle {
        radius: control.tokens.radius.small
        color: "transparent"
        border.width: control.visualFocus ? 1 : 0
        border.color: control.tokens.color.accent
    }
    indicator: Rectangle {
        x: control.width - width
        y: (control.height - height) / 2
        width: 40
        height: 22
        radius: height / 2
        color: control.checked ? control.tokens.color.accent : control.tokens.color.background
        border.width: control.checked ? 0 : 1
        border.color: control.hovered ? control.tokens.color.accent : control.tokens.color.accentSoft
        Behavior on color { enabled: !control.tokens.motion.off; ColorAnimation { duration: control.tokens.motion.fast } }
        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: control.checked ? parent.width - width - 3 : 3
            color: control.checked ? control.tokens.color.text : control.tokens.color.textMuted
            Behavior on x { enabled: !control.tokens.motion.off; NumberAnimation { duration: control.tokens.motion.fast; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Item {
        implicitHeight: labels.implicitHeight
        Column {
            id: labels
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                rightPadding: control.indicator.width + control.spacing
                text: control.text
                color: control.tokens.color.text
                font.family: control.tokens.type.body.family
                font.pixelSize: control.tokens.type.small.size
                font.weight: control.tokens.type.body.weight
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
            Text {
                visible: control.description.length > 0
                width: parent.width
                rightPadding: control.indicator.width + control.spacing
                text: control.description
                color: control.tokens.color.textMuted
                font.family: control.tokens.type.small.family
                font.pixelSize: control.tokens.type.small.size - 1
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }
        }
    }
}
