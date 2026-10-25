pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "В Nayori нет экрана блокировки. Собрать здесь свой экран нельзя. Блокировка сеанса на странице «Питание» вызывает loginctl lock-session и системный экран, если он настроен"
    
    }
}
