pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../settings"

ColumnLayout {
    id: root
    required property var tokens
    required property var service
    signal settingsRequested()
    readonly property bool interacting: input.activeFocus || (!!service && service.busy)
    function focusInput() { input.forceActiveFocus(Qt.ShortcutFocusReason) }
    spacing: root.tokens.spacing.small
    RowLayout {
        Layout.fillWidth: true
        SettingsSegmented {
            tokens: root.tokens
            model: [{key: "Work", label: "Work"}, {key: "Personal", label: "Personal"}]
            currentKey: root.service ? root.service.context : "Work"
            enabled: !!root.service && root.service.ready && !root.service.busy
            onActivated: key => root.service.edit(input.text, key)
        }
        Item { Layout.fillWidth: true }
        IslandAction { tokens: root.tokens; text: "Настроить"; onClicked: root.settingsRequested() }
    }
    IslandLabel {
        objectName: "quickCaptureConfigurationHint"
        tokens: root.tokens
        Layout.fillWidth: true
        visible: text !== ""
        text: root.service ? root.service.configurationHint : ""
        color: root.tokens.color.textMuted
        font.pixelSize: 12
    }
    ScrollView {
        id: editorScroll
        Layout.minimumWidth: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 80
        clip: true
        TextArea {
            id: input
            objectName: "quickCaptureInput"
            width: editorScroll.availableWidth
            text: root.service ? root.service.text : ""
            readOnly: !root.service || !root.service.ready || root.service.busy
            placeholderText: "Заметка в Inbox…"
            Accessible.name: "Заметка в Obsidian Inbox"
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: root.tokens.color.text
            placeholderTextColor: root.tokens.color.textMuted
            selectionColor: root.tokens.color.accentSoft
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.body.size
            background: Rectangle {
                color: root.tokens.color.surfaceAlt
                radius: root.tokens.radius.small
                border.width: 1
                border.color: input.activeFocus ? root.tokens.color.accent : root.tokens.color.border
            }
            onTextChanged: if (root.service && text !== root.service.text) root.service.edit(text, root.service.context)
            Keys.onPressed: event => {
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                    root.service.save()
                    event.accepted = true
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        IslandLabel {
            tokens: root.tokens
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            text: root.service ? root.service.error || root.service.status || "Enter — сохранить · Shift+Enter — новая строка" : "Служба заметок недоступна"
            color: root.service && root.service.error ? root.tokens.color.secondary : root.tokens.color.textMuted
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        IslandAction {
            tokens: root.tokens
            text: "Открыть"
            visible: !!root.service && root.service.lastUri !== ""
            onClicked: Qt.openUrlExternally(root.service.lastUri)
        }
        IslandAction {
            objectName: "quickCaptureSave"
            tokens: root.tokens
            text: "Сохранить"
            enabled: !!root.service && root.service.ready && !root.service.busy && root.service.text.trim() !== ""
            onClicked: root.service.save()
        }
    }
}
