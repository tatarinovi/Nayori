pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    id: button
    required property var tokens
    property bool selected: false
    property bool navigation: false
    property string detail: ""
    property string glyph: ""
    padding: 0
    opacity: enabled ? 1 : 0.45
    implicitHeight: Math.max(tokens.settings.control, captions.implicitHeight + 16)
    implicitWidth: Math.max(120, caption.implicitWidth + 24 + (glyph ? 30 : 0))
    focusPolicy: Qt.StrongFocus
    Accessible.name: text + (detail ? ", " + detail : "")
    background: Rectangle {
        radius: button.tokens.radius.small
        color: button.down ? button.tokens.color.surface : button.selected || button.hovered ? button.tokens.color.surfaceAlt : "transparent"
        border.width: button.visualFocus || (!button.navigation && !button.selected) ? 1 : 0
        border.color: button.visualFocus ? button.tokens.color.accent : button.tokens.color.border
    }
    contentItem: Item {
        SettingsNavGlyph {
            id: icon
            objectName: "settings-action-icon"
            visible: !!button.glyph
            name: button.glyph
            ink: button.selected ? button.tokens.color.accent : button.tokens.color.textMuted
            width: 20; height: 20
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        }
        Column {
            id: captions
            objectName: "settings-action-captions"
            anchors { left: parent.left; leftMargin: button.glyph ? 42 : 12; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            spacing: button.detail ? 4 : 0
            SettingsLabel {
                id: caption
                tokens: button.tokens
                width: parent.width
                text: button.text
                lineHeight: button.navigation ? 1 : 1.4
                color: button.selected ? button.tokens.color.accent : button.tokens.color.text
            }
            SettingsLabel {
                objectName: "settings-action-path"
                tokens: button.tokens
                width: parent.width
                visible: !!button.detail
                text: button.detail
                font.pixelSize: 12
                lineHeight: 1.2
                color: button.tokens.color.textMuted
            }
        }
    }
}
