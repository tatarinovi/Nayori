pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Compact single-choice control. The chosen segment is filled with the accent.
Rectangle {
    id: root
    required property var tokens
    // [{ key: string, label: string }]
    property var model: []
    property string currentKey: ""
    // true: segments share the width equally; false: each takes its label width.
    property bool equalWidth: false
    signal activated(string key)
    signal focusReceived()

    implicitHeight: 32
    implicitWidth: row.implicitWidth + 4
    radius: tokens.radius.small + 4
    color: tokens.material.sidebar
    border.width: 1
    border.color: tokens.color.border

    RowLayout {
        id: row
        anchors { fill: parent; margins: 2 }
        spacing: 2
        Repeater {
            model: root.model
            delegate: AbstractButton {
                id: segment
                required property var modelData
                readonly property bool selected: root.currentKey === modelData.key
                Layout.fillWidth: root.equalWidth
                Layout.fillHeight: true
                Layout.preferredWidth: root.equalWidth ? 1 : implicitWidth
                implicitWidth: label.implicitWidth + 28
                hoverEnabled: true
                focusPolicy: Qt.StrongFocus
                text: modelData.label
                Accessible.role: Accessible.RadioButton
                Accessible.name: text
                Accessible.checked: selected
                onClicked: root.activated(modelData.key)
                onActiveFocusChanged: if (activeFocus) root.focusReceived()
                background: Rectangle {
                    radius: root.radius - 2
                    color: segment.selected ? root.tokens.color.accent
                        : segment.down ? root.tokens.color.surface
                        : segment.hovered ? root.tokens.color.surfaceAlt : "transparent"
                    border.width: segment.visualFocus ? 1 : 0
                    border.color: segment.selected ? root.tokens.color.accentText : root.tokens.color.accent
                }
                contentItem: Text {
                    id: label
                    text: segment.text
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    color: segment.selected ? root.tokens.color.accentText : root.tokens.color.text
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.small.size
                    font.weight: segment.selected ? Font.DemiBold : root.tokens.type.body.weight
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
