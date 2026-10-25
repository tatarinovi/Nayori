pragma ComponentBehavior: Bound

import QtQuick
import "../companion"

Column {
    id: root
    required property var tokens
    property var companionTokens: tokens
    property bool companionEnabled: false
    property bool companionDesktopOnly: false
    property bool animationsEnabled: true
    property bool previewActive: false
    signal companionChangedRequested(bool enabled)
    signal companionDesktopOnlyChangedRequested(bool enabled)
    signal revealRequested(var item)
    spacing: 16

    Rectangle {
        width: parent.width
        height: 560
        radius: root.tokens.radius.small
        color: root.tokens.color.background
        border.color: root.tokens.color.border
        NaomiIllustration {
            tokens: root.companionTokens
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            width: 280
            height: 534
            active: root.previewActive
            animationsEnabled: root.animationsEnabled
            followPointer: true
        }
    }
    SettingsLabel {
        width: parent.width
        tokens: root.tokens
        text: "Шарф, повязка на шее и заколка берут цвет из палитры обоев основного монитора. Волосы, кожа, одежда и глаза остаются неизменными."
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    SettingsToggle {
        objectName: "settingsCompanionToggle"
        tokens: root.tokens
        text: "Показывать Naomi на рабочем столе"
        description: "Справа снизу на основном мониторе. Не мешает нажимать на окна и рабочий стол."
        checked: root.companionEnabled
        onClicked: root.companionChangedRequested(checked)
        onFocusReceived: root.revealRequested(this)
    }
    SettingsToggle {
        objectName: "settingsCompanionDesktopOnlyToggle"
        tokens: root.tokens
        text: "Только на рабочем столе"
        description: root.companionDesktopOnly
            ? "Naomi видна над обоями и скрыта за окнами приложений."
            : "Naomi показывается поверх всех окон. Отключите, чтобы она оставалась за окнами."
        checked: root.companionDesktopOnly
        enabled: root.companionEnabled
        onClicked: root.companionDesktopOnlyChangedRequested(checked)
        onFocusReceived: root.revealRequested(this)
    }
    SettingsLabel {
        width: parent.width
        tokens: root.tokens
        text: root.animationsEnabled
            ? "Naomi дышит, моргает, качает волосами и шарфом, ушки иногда вздрагивают. Здесь голова поворачивается за курсором, на рабочем столе — нет. Общения и системных действий пока нет."
            : "Анимации выключены в разделе «Внешний вид». Naomi отображается без движения."
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
}
