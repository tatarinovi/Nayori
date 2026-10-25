pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    required property var tokens
        id: control
        required property string label
        required property int reserved
        signal adjusted(int amount)
        signal focusReceived()
        spacing: 8
        Item {
            width: parent.width
            height: 24
            SettingsLabel { tokens: control.tokens; text: control.label; anchors.verticalCenter: parent.verticalCenter }
            SettingsLabel { tokens: control.tokens;
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: control.reserved + " px"
                color: control.tokens.color.accent
                font.features: { "tnum": 1 }
            }
        }
        Slider {
            id: slider
            objectName: control.label === "Сверху" ? "topReservationSlider" : "bottomReservationSlider"
            width: parent.width
            height: 32
            from: 0
            to: 200
            stepSize: 4
            snapMode: Slider.SnapAlways
            value: control.reserved
            focusPolicy: Qt.StrongFocus
            Accessible.name: control.label
            onActiveFocusChanged: if (activeFocus) control.focusReceived()
            onMoved: control.adjusted(Math.round(value))
            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: slider.availableWidth
                height: 4
                radius: 2
                color: control.tokens.color.surface
                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height
                    radius: parent.radius
                    color: control.tokens.color.accent
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                width: 20
                height: 20
                radius: 10
                color: slider.pressed ? control.tokens.color.text : control.tokens.color.accent
                border.width: slider.visualFocus ? 2 : 0
                border.color: control.tokens.color.text
            }
        }
    }
