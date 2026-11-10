pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../islands/workspaces"
import "../../islands/workspaces/WorkspaceStyles.js" as Styles

Grid {
    id: root
    required property var tokens
    property string selectedStyle: "dots"
    signal styleSelected(string style)
    signal revealRequested(var item)
    columns: width >= 540 ? 3 : 2
    spacing: 8

    Repeater {
        model: Styles.styles
        delegate: AbstractButton {
            id: choice
            required property var modelData
            objectName: "workspace-style-" + modelData.key
            width: (root.width - (root.columns - 1) * root.spacing) / root.columns
            height: 88
            text: modelData.name
            checked: root.selectedStyle === modelData.key
            Accessible.name: text
            Accessible.role: Accessible.RadioButton
            Accessible.checkable: true
            Accessible.checked: checked
            onClicked: root.styleSelected(modelData.key)
            onActiveFocusChanged: if (activeFocus) root.revealRequested(choice)
            background: Rectangle {
                radius: root.tokens.radius.medium
                color: choice.checked || choice.hovered ? root.tokens.color.surface : root.tokens.material.panel
                border.width: choice.checked || choice.activeFocus ? 2 : 1
                border.color: choice.activeFocus ? root.tokens.color.text
                    : choice.checked ? root.tokens.color.accent : root.tokens.color.border
            }
            contentItem: Column {
                spacing: 6
                topPadding: 10
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: 3
                        WorkspaceIndicator {
                            required property int index
                            tokens: root.tokens
                            style: choice.modelData.key
                            number: index + 1
                            current: index === 0
                            occupied: index === 1
                            width: 28; height: 32
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: choice.text
                    color: root.tokens.color.text
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.small.size
                }
            }
        }
    }
}
