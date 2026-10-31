pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../settings"

FocusScope {
    id: root
    required property var tokens
    property var view: null
    property var service: null
    property bool primary: true
    signal cancelRequested()
    implicitWidth: 440
    implicitHeight: column.implicitHeight + 48
    Accessible.role: Accessible.Dialog
    Accessible.name: "Подтверждение действия"
    Accessible.description: view && view.message ? view.message : "Система просит подтвердить действие"

    property int appliedGeneration: -1
    onViewChanged: applyGeneration()
    function applyGeneration() {
        const generation = root.view ? root.view.generation : -1
        if (generation === appliedGeneration) return
        appliedGeneration = generation
        passwordField.text = ""
        if (root.primary && root.view && root.view.responseRequired)
            passwordField.forceActiveFocus()
    }
    function confirm() {
        if (!service || !service.canSubmit()) return
        const response = passwordField.text
        passwordField.text = ""
        service.submit(response)
    }
    property alias responseField: passwordField
    readonly property int responseEcho: passwordField.echoMode
    readonly property bool responseEmpty: passwordField.text.length === 0
    readonly property string titleText: titleLabel.text
    readonly property string errorLine: errorLabel.text
    readonly property string identityLine: identityLabel.text

    Rectangle {
        anchors.fill: parent
        radius: root.tokens.radius.medium
        color: root.tokens.material.dense
        border.width: 1
        border.color: root.tokens.color.border
    }
    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            IconImage {
                visible: source !== ""
                source: {
                    const name = root.view && root.view.iconName ? root.view.iconName : ""
                    return name ? Quickshell.iconPath(name) : ""
                }
                implicitWidth: 32
                implicitHeight: 32
            }
            Text {
                id: titleLabel
                Layout.fillWidth: true
                text: "Нужно подтверждение"
                color: root.tokens.color.text
                font.family: root.tokens.type.display.family
                font.pixelSize: root.tokens.type.display.size
                font.weight: root.tokens.type.display.weight
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }
        }
        Text {
            Layout.fillWidth: true
            text: root.view && root.view.message ? root.view.message : "Система просит подтвердить действие"
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            font.weight: root.tokens.type.body.weight
            lineHeight: root.tokens.type.body.lineHeight
            lineHeightMode: Text.ProportionalHeight
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            visible: root.view && root.view.actionId
            text: root.view ? root.view.actionId : ""
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Accessible.ignored: true
        }
        Text {
            id: identityLabel
            Layout.fillWidth: true
            visible: !!root.view && root.view.identities && root.view.identities.length === 1
            text: {
                if (!root.view || !root.view.identities || !root.view.identities.length) return ""
                return "От\u00A0имени " + root.view.identities[0].title
            }
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: !!root.view && root.view.identities && root.view.identities.length > 1
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: "Кто подтверждает"
                color: root.tokens.color.textMuted
                font.family: root.tokens.type.small.family
                font.pixelSize: root.tokens.type.small.size
                textFormat: Text.PlainText
            }
            Repeater {
                model: root.view && root.view.identities ? root.view.identities : []
                delegate: Button {
                    id: identityButton
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    focusPolicy: Qt.StrongFocus
                    activeFocusOnTab: true
                    text: modelData.title
                    Accessible.name: "Подтвердить от\u00A0имени " + modelData.title
                    Accessible.role: Accessible.Button
                    onClicked: if (root.service) root.service.select(modelData.id)
                    contentItem: Text {
                        text: identityButton.text
                        color: root.tokens.color.text
                        font.family: root.tokens.type.body.family
                        font.pixelSize: root.tokens.type.body.size
                        horizontalAlignment: Text.AlignLeft
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 12
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: identityButton.index === (root.view ? root.view.selected : -1)
                            ? root.tokens.color.surface : root.tokens.color.surfaceAlt
                        border.width: identityButton.visualFocus ? 2 : 1
                        border.color: identityButton.visualFocus ? root.tokens.color.accent
                            : identityButton.index === (root.view ? root.view.selected : -1)
                                ? root.tokens.color.accentSoft : root.tokens.color.border
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !!root.view && root.view.hint !== ""
            text: root.view ? root.view.hint : ""
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        Text {
            id: errorLabel
            Layout.fillWidth: true
            visible: text !== ""
            text: {
                if (!root.view) return ""
                if (root.view.errorText) return root.view.errorText
                if (root.view.failed) return "Пароль не подошёл. Попробуйте снова"
                return ""
            }
            color: root.tokens.color.secondary
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Accessible.role: Accessible.AlertMessage
        }
        Text {
            Layout.fillWidth: true
            visible: !!root.view && root.view.infoText && !root.view.errorText
            text: root.view ? root.view.infoText : ""
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            text: passwordField.echoMode === TextInput.Password ? "Пароль" : "Ответ"
            color: root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            textFormat: Text.PlainText
        }
        SettingsField {
            id: passwordField
            Layout.fillWidth: true
            tokens: root.tokens
            echoMode: root.view && root.view.responseVisible ? TextInput.Normal : TextInput.Password
            passwordMaskDelay: 0
            inputMethodHints: echoMode === TextInput.Password
                ? Qt.ImhSensitiveData | Qt.ImhHiddenText | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                : Qt.ImhNoPredictiveText
            activeFocusOnTab: true
            Accessible.name: echoMode === TextInput.Password ? "Пароль" : "Ответ"
            Accessible.role: Accessible.EditableText
            Keys.onEscapePressed: event => { root.cancelRequested(); event.accepted = true }
            Keys.onReturnPressed: event => { root.confirm(); event.accepted = true }
            Keys.onEnterPressed: event => { root.confirm(); event.accepted = true }
            onTextChanged: if (text.indexOf("\n") >= 0) text = text.replace(/\n/g, "")
        }
        Text {
            Layout.fillWidth: true
            visible: !!root.view && root.view.pending > 0
            text: root.view && root.view.pending === 1
                ? "После этого останется ещё один запрос"
                : "После этого останутся ещё запросы"
            color: root.tokens.color.textMuted
            font.family: root.tokens.type.small.family
            font.pixelSize: root.tokens.type.small.size
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            SettingsButton {
                id: cancelButton
                tokens: root.tokens
                text: "Отмена"
                Accessible.name: "Отмена"
                activeFocusOnTab: true
                Keys.onEscapePressed: event => { root.cancelRequested(); event.accepted = true }
                onClicked: root.cancelRequested()
            }
            SettingsButton {
                id: confirmButton
                tokens: root.tokens
                primary: true
                text: "Подтвердить"
                Accessible.name: "Подтвердить"
                enabled: !!root.view && root.view.responseRequired && passwordField.text.length > 0
                activeFocusOnTab: true
                Keys.onEscapePressed: event => { root.cancelRequested(); event.accepted = true }
                Keys.onReturnPressed: event => { root.confirm(); event.accepted = true }
                Keys.onEnterPressed: event => { root.confirm(); event.accepted = true }
                onClicked: root.confirm()
            }
        }
    }
    Component.onCompleted: applyGeneration()
}
