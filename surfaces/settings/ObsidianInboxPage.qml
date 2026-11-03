pragma ComponentBehavior: Bound
import QtQuick

Column {
    id: root
    objectName: "obsidianInboxSettingsPage"
    required property var tokens
    property var values: ({})
    signal changed(var patch)
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }
    function reveal(item) {
        let node = parent
        while (node) {
            if (node.reveal) { node.reveal(item); return }
            node = node.parent
        }
    }
    SettingsToggle {
        tokens: root.tokens
        text: "Quick Capture"
        description: "Сохранять заметки в локальный Obsidian Vault"
        checked: root.values.quickCaptureEnabled || false
        onClicked: root.changed({quickCaptureEnabled: checked})
    }
    Label { text: "Путь к Obsidian Vault" }
    SettingsField {
        tokens: root.tokens
        objectName: "quickCaptureVaultField"
        text: root.values.quickCaptureVault || ""
        placeholderText: "~/Documents/My Vault"
        Accessible.name: "Путь к Obsidian Vault"
        onEditingFinished: root.changed({quickCaptureVault: text})
        onActiveFocusChanged: if (activeFocus) root.reveal(this)
    }
    Label { text: "Контекст по умолчанию" }
    SettingsSegmented {
        tokens: root.tokens
        model: [{key: "Work", label: "Work"}, {key: "Personal", label: "Personal"}]
        currentKey: root.values.quickCaptureContext || "Work"
        onActivated: key => root.changed({quickCaptureContext: key})
    }
    Label { text: "Папка Work внутри Vault" }
    SettingsField {
        tokens: root.tokens
        objectName: "quickCaptureWorkPathField"
        text: root.values.quickCaptureWorkPath || "Inbox/Work"
        Accessible.name: "Папка Work внутри Vault"
        onEditingFinished: root.changed({quickCaptureWorkPath: text})
        onActiveFocusChanged: if (activeFocus) root.reveal(this)
    }
    Label { text: "Папка Personal внутри Vault" }
    SettingsField {
        tokens: root.tokens
        objectName: "quickCapturePersonalPathField"
        text: root.values.quickCapturePersonalPath || "Inbox/Personal"
        Accessible.name: "Папка Personal внутри Vault"
        onEditingFinished: root.changed({quickCapturePersonalPath: text})
        onActiveFocusChanged: if (activeFocus) root.reveal(this)
    }
}
