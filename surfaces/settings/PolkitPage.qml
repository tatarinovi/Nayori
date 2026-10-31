pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
    property var settings: null
    property var polkit: null
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Диалог появляется, когда система просит подтвердить действие. Пароль проверяет системная служба, Nayori его не сохраняет"
    }
    SettingsToggle {
        objectName: "polkitAgent"
        tokens: root.tokens
        text: "Агент подтверждения Nayori"
        description: "Пока выключено, Nayori не регистрируется и не заменяет другой агент"
        checked: !!(root.settings && root.settings.polkitAgent)
        onClicked: if (root.settings) root.settings.update({ polkitAgent: checked })
    }
    Label {
        width: parent.width
        color: root.polkit && root.polkit.phase === "refused" ? root.tokens.color.secondary : root.tokens.color.text
        font.pixelSize: 13
        text: root.polkit ? root.polkit.statusText : "Агент выключен. Nayori не регистрируется и не заменяет другой агент"
        Accessible.role: Accessible.StaticText
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Если другой агент уже запущен, выключите его сами. Nayori не останавливает чужие процессы и не отбирает имя"
    }
}
