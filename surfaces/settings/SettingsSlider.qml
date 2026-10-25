pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Slider {
    id: slider
    required property var tokens
    property real source: 0
    property string label: ""
    signal changed(real value)
    from: 0
    to: 1
    implicitHeight: 32
    Accessible.name: label
    onMoved: changed(value)
    Binding {
        target: slider
        property: "value"
        value: slider.source
        when: !slider.pressed
    }
    background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: slider.availableWidth
        height: 4
        radius: 2
        color: slider.tokens.color.surface
        Rectangle {
            width: slider.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: slider.tokens.color.accent
        }
    }
    handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + (slider.availableHeight - height) / 2
        width: 16
        height: 16
        radius: 8
        color: slider.tokens.color.text
        border.width: slider.visualFocus ? 2 : 0
        border.color: slider.tokens.color.accent
    }
}
