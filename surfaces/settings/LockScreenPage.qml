pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Экран блокировки использует обои каждого монитора и текущие цвета Nayori, включая динамическую тему. Пароль и управление музыкой отображаются только на основном мониторе"
    
    }
    SettingsButton {
        tokens: root.tokens
        text: "Предпросмотр блокировки"
        onClicked: preview.running = true
    }
    Label {
        width: parent.width
        text: "После установки темы Nayori для SDDM экран входа использует тот же интерфейс, цвета и обои. Изменения темы сохраняются автоматически"
        color: root.tokens.color.textMuted
        font.pixelSize: 13
    }
    Process {
        id: preview
        command: ["qs", "ipc", "-p", Quickshell.shellDir, "call", "lock", "preview"]
    }
}
