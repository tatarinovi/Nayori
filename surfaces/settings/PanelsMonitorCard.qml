pragma ComponentBehavior: Bound

import QtQuick

// One monitor: identity header and the state of the four islands on it.
// Only the top island of a secondary monitor has a setting; the rest report their auto-hide state.
Rectangle {
    id: card
    required property var tokens
    property string outputName: ""
    property string detail: ""
    property bool primary: false
    property bool selected: false
    property bool topSwitchable: false
    property bool topShown: true
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    signal topShownRequested(bool shown)
    signal itemFocused(Item item)

    function stateText(autoHide) { return autoHide ? "Автоскрытие" : "Всегда" }

    width: parent ? parent.width : implicitWidth
    implicitHeight: column.implicitHeight + 24
    radius: tokens.radius.medium
    color: Qt.alpha(tokens.color.background, 0.35)
    border.width: selected ? 2 : 1
    border.color: selected ? tokens.color.accent : tokens.color.border

    Column {
        id: column
        x: 12; y: 12
        width: parent.width - 24
        spacing: 8
        Item {
            width: parent.width
            height: nameColumn.implicitHeight + 8
            SettingsNavGlyph {
                id: icon
                name: "display"
                width: 22; height: 22
                ink: card.tokens.color.textMuted
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
            }
            Column {
                id: nameColumn
                anchors { left: icon.right; leftMargin: 12; right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 2
                Row {
                    spacing: 8
                    Text {
                        id: nameText
                        text: card.outputName
                        color: card.tokens.color.text
                        font.family: card.tokens.type.body.family
                        font.pixelSize: card.tokens.type.body.size + 2
                        font.weight: Font.DemiBold
                        textFormat: Text.PlainText
                    }
                    Rectangle {
                        visible: card.primary
                        anchors.verticalCenter: nameText.verticalCenter
                        width: badge.implicitWidth + 16
                        height: 20
                        radius: height / 2
                        color: card.tokens.color.accentSoft
                        Text {
                            id: badge
                            anchors.centerIn: parent
                            text: "Основной"
                            color: card.tokens.color.accentSoftText
                            font.family: card.tokens.type.small.family
                            font.pixelSize: card.tokens.type.small.size - 2
                            textFormat: Text.PlainText
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: card.detail
                    color: card.tokens.color.textMuted
                    font.family: card.tokens.type.small.family
                    font.pixelSize: card.tokens.type.small.size - 1
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }
            }
        }
        SettingsIconSwitch {
            objectName: "panels-" + card.outputName + "-top"
            tokens: card.tokens
            glyph: "topisland"
            text: "Верхний остров"
            showSwitch: card.topSwitchable
            checked: card.topShown
            status: card.stateText(card.autoHideTop)
            onClicked: card.topShownRequested(checked)
            onFocusReceived: card.itemFocused(this)
        }
        SettingsIconSwitch {
            objectName: "panels-" + card.outputName + "-apps"
            tokens: card.tokens
            glyph: "apps"
            text: "Док приложений"
            showSwitch: false
            status: card.stateText(card.autoHideApps)
        }
        SettingsIconSwitch {
            objectName: "panels-" + card.outputName + "-workspaces"
            tokens: card.tokens
            glyph: "workspaces"
            text: "Рабочие столы"
            showSwitch: false
            status: card.stateText(card.autoHideWorkspaces)
        }
        SettingsIconSwitch {
            objectName: "panels-" + card.outputName + "-status"
            tokens: card.tokens
            glyph: "island"
            text: "Системный остров"
            showSwitch: false
            status: card.stateText(card.autoHideStatus)
        }
    }
}
