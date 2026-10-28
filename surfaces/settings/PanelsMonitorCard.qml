pragma ComponentBehavior: Bound

import QtQuick

// Independent visibility modes for each part of this output.
Rectangle {
    id: card
    required property var tokens
    property string outputName: ""
    property string detail: ""
    property bool primary: false
    property bool selected: false
    property int topReserved: 0
    property int bottomReserved: 0
    signal reservationRequested(int top, int bottom)
    property var modes: ({})
    signal modeRequested(string part, string mode)
    signal itemFocused(Item item)

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
        Repeater {
            model: [
                {key: "top", label: "Верхний остров"},
                {key: "apps", label: "Док приложений"},
                {key: "workspaces", label: "Рабочие столы"},
                {key: "status", label: "Трей и системный остров"}
            ]
            delegate: Item {
                id: partRow
                required property var modelData
                width: column.width
                height: Math.max(partLabel.implicitHeight, selector.implicitHeight) + 4
                SettingsLabel {
                    id: partLabel
                    tokens: card.tokens
                    text: partRow.modelData.label
                    width: parent.width - selector.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                }
                SettingsSelect {
                    id: selector
                    objectName: "panels-" + card.outputName + "-" + partRow.modelData.key
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.min(190, parent.width * 0.57)
                    tokens: card.tokens
                    Accessible.name: partRow.modelData.label + ": " + currentLabel
                    model: [
                        {key: "always", label: "Показывать всегда"},
                        {key: "auto", label: "Авто-скрытие"},
                        {key: "hidden", label: "Не отображать"}
                    ]
                    currentKey: card.modes[partRow.modelData.key] || "always"
                    onActivated: key => card.modeRequested(partRow.modelData.key, key)
                    onFocusReceived: card.itemFocused(this)
                }
            }
        }
        Rectangle { width: parent.width; height: 1; color: card.tokens.color.border }
        SettingsLabel {
            tokens: card.tokens
            text: "Отступы от краёв"
            color: card.tokens.color.textMuted
        }
        SettingsReservationControl {
            objectName: "panels-" + card.outputName + "-top-reservation"
            width: parent.width
            tokens: card.tokens
            label: "Сверху"
            reserved: card.topReserved
            onAdjusted: amount => card.reservationRequested(amount, card.bottomReserved)
            onFocusReceived: card.itemFocused(this)
        }
        SettingsReservationControl {
            objectName: "panels-" + card.outputName + "-bottom-reservation"
            width: parent.width
            tokens: card.tokens
            label: "Снизу"
            reserved: card.bottomReserved
            onAdjusted: amount => card.reservationRequested(card.topReserved, amount)
            onFocusReceived: card.itemFocused(this)
        }
        Flow {
            width: parent.width
            spacing: 8
            SettingsButton {
                tokens: card.tokens
                text: "По размеру панелей"
                onClicked: card.reservationRequested(64, 72)
                onActiveFocusChanged: if (activeFocus) card.itemFocused(this)
            }
            SettingsButton {
                tokens: card.tokens
                text: "Сбросить"
                onClicked: card.reservationRequested(0, 0)
                onActiveFocusChanged: if (activeFocus) card.itemFocused(this)
            }
        }
    }
}
