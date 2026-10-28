pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

// Fully drawn in the shell palette; no platform-native ComboBox styling.
AbstractButton {
    id: root
    required property var tokens
    property var model: []
    property string currentKey: ""
    signal activated(string key)
    signal focusReceived()
    readonly property string currentLabel: {
        for (const option of model)
            if (option.key === currentKey) return option.label
        return ""
    }
    implicitWidth: 190
    implicitHeight: 38
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.ComboBox
    Accessible.name: currentLabel
    onActiveFocusChanged: if (activeFocus) focusReceived()
    onClicked: menu.opened ? menu.close() : menu.open()
    Keys.onDownPressed: menu.open()
    Keys.onUpPressed: menu.open()
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down || menu.opened ? root.tokens.color.surfaceAlt
            : root.hovered ? root.tokens.color.surface : root.tokens.material.sidebar
        border.width: 1
        border.color: root.visualFocus || menu.opened ? root.tokens.color.accent : root.tokens.color.border
    }
    contentItem: Item {
        Text {
            anchors { left: parent.left; leftMargin: 12; right: arrow.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            text: root.currentLabel
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.small.size
        }
        Canvas {
            id: arrow
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: 10; height: 6
            property color ink: root.tokens.color.textMuted
            onInkChanged: requestPaint()
            onPaint: {
                const context = getContext("2d")
                context.reset()
                context.strokeStyle = ink
                context.lineWidth = 1.5
                context.lineCap = "round"
                context.lineJoin = "round"
                context.beginPath()
                context.moveTo(1, 1)
                context.lineTo(5, 5)
                context.lineTo(9, 1)
                context.stroke()
            }
            rotation: menu.opened ? 180 : 0
        }
    }
    Popup {
        id: menu
        x: root.width - width
        y: root.height + 6
        margins: 8
        width: Math.max(root.width, 210)
        padding: 5
        implicitHeight: options.implicitHeight + padding * 2
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: {
            for (let index = 0; index < root.model.length; ++index)
                if (root.model[index].key === root.currentKey) {
                    choices.itemAt(index).forceActiveFocus()
                    break
                }
        }
        background: Rectangle {
            radius: root.tokens.radius.small + 3
            color: root.tokens.color.background
            border.width: 1
            border.color: root.tokens.color.border
        }
        contentItem: Column {
            id: options
            spacing: 3
            Repeater {
                id: choices
                model: root.model
                delegate: AbstractButton {
                    id: option
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.currentKey === modelData.key
                    width: options.width
                    height: 36
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: selected
                    onClicked: {
                        root.activated(modelData.key)
                        menu.close()
                        root.forceActiveFocus()
                    }
                    Keys.onDownPressed: choices.itemAt((index + 1) % root.model.length).forceActiveFocus()
                    Keys.onUpPressed: choices.itemAt((index + root.model.length - 1) % root.model.length).forceActiveFocus()
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: option.selected ? root.tokens.color.accentSoft
                            : option.hovered || option.activeFocus ? root.tokens.color.surfaceAlt : "transparent"
                        border.width: option.visualFocus ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 10
                        text: option.modelData.label + (option.selected ? "  ✓" : "")
                        verticalAlignment: Text.AlignVCenter
                        color: option.selected ? root.tokens.color.accentSoftText : root.tokens.color.text
                        font.family: root.tokens.type.body.family
                        font.pixelSize: root.tokens.type.small.size
                        textFormat: Text.PlainText
                    }
                }
            }
        }
    }
}
