pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    property bool showHeading: true
    required property var tokens
    property string surfaceStyle: "solid"
    signal surfaceStyleChangedRequested(string style)
    signal revealRequested(var item)
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 16
            Label { visible: root.showHeading; text: "Внешний вид"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
            Label { text: "Прозрачность"; font.pixelSize: 18 }
            Label {
                width: parent.width
                text: "Выберите оформление всего интерфейса Nayori."
                color: root.tokens.color.textMuted
                font.pixelSize: 13
            }
            ButtonGroup { id: surfaceStyles }
            Repeater {
                model: [
                    {key: "solid", title: "Solid", description: "Графитовые поверхности без прозрачности"},
                    {key: "frosted", title: "Frosted Glass", description: "Матовое стекло: нижние острова прозрачнее, Dynamic Island темнее, меню пуск и настройки плотнее"}
                ]
                RadioButton {
                    id: styleOption
                    required property var modelData
                    objectName: "surfaceStyle-" + modelData.key
                    width: root.width
                    ButtonGroup.group: surfaceStyles
                    checked: root.surfaceStyle === modelData.key
                    onClicked: root.surfaceStyleChangedRequested(modelData.key)
                    focusPolicy: Qt.StrongFocus
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    spacing: 12
                    padding: 12
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.width: styleOption.checked || styleOption.visualFocus || styleOption.hovered ? 1 : 0
                        border.color: root.tokens.color.accent
                    }
                    indicator: Rectangle {
                        x: styleOption.leftPadding
                        y: (styleOption.height - height) / 2
                        width: 20
                        height: 20
                        radius: 10
                        color: root.tokens.color.background
                        border.width: 1
                        border.color: styleOption.checked ? root.tokens.color.accent : root.tokens.color.accentSoft
                        Rectangle {
                            anchors.centerIn: parent
                            width: 10
                            height: 10
                            radius: 5
                            color: root.tokens.color.accent
                            visible: styleOption.checked
                        }
                    }
                    contentItem: Column {
                        spacing: 6
                        Label { width: parent.width; leftPadding: styleOption.indicator.width + styleOption.spacing; text: styleOption.modelData.title }
                        Label {
                            width: parent.width
                            leftPadding: styleOption.indicator.width + styleOption.spacing
                            text: styleOption.modelData.description
                            color: root.tokens.color.textMuted
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
            CheckBox {
                id: animations
                objectName: "settingsAnimationsToggle"
                onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
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
