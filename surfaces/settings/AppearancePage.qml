pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    required property var tokens
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 16
            Label { text: "Внешний вид"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
            CheckBox {
                id: animations
                width: parent.width
                text: "Анимации"
                checked: root.animationsEnabled
                focusPolicy: Qt.StrongFocus
                onClicked: root.animationsChangedRequested(checked)
                spacing: 12
                padding: 12
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: root.tokens.color.surfaceAlt
                    border.width: animations.visualFocus || animations.hovered ? 1 : 0
                    border.color: root.tokens.color.accent
                }
                indicator: Rectangle {
                    x: animations.leftPadding
                    y: (animations.height - height) / 2
                    width: 20
                    height: 20
                    radius: 5
                    color: animations.checked ? root.tokens.color.accent : root.tokens.color.background
                    border.width: animations.checked ? 0 : 1
                    border.color: root.tokens.color.accentSoft
                    Label { anchors.centerIn: parent; text: animations.checked ? "✓" : ""; color: root.tokens.color.background }
                }
                contentItem: Column {
                    property real labelIndent: animations.indicator.width + animations.spacing
                    spacing: 6
                    Label { width: parent.width; leftPadding: parent.labelIndent; text: "Анимации" }
                    Label { width: parent.width; leftPadding: parent.labelIndent; text: "Движение лисы и переходы интерфейса"; color: root.tokens.color.textMuted; font.pixelSize: 13 }
                }
            }
        }
