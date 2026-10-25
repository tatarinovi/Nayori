pragma ComponentBehavior: Bound

import QtQuick
import "../companion"

Column {
    id: root
    required property var tokens
    property var companionTokens: tokens
    property bool companionEnabled: false
    property bool companionDesktopOnly: false
    property bool companionReactToPointer: true
    property bool companionSystemLines: true
    property bool animationsEnabled: true
    property bool previewActive: false
    signal companionChangedRequested(bool enabled)
    signal companionDesktopOnlyChangedRequested(bool enabled)
    signal companionReactToPointerChangedRequested(bool enabled)
    signal companionSystemLinesChangedRequested(bool enabled)
    signal revealRequested(var item)
    spacing: 16

    Rectangle {
        width: parent.width
        height: 688
        radius: root.tokens.radius.small
        color: root.tokens.color.background
        border.color: root.tokens.color.border
        // Над Naomi — место под облачко (128 пикселей), поэтому компонент выше иллюстрации.
        NaomiCompanion {
            id: previewNaomi
            objectName: "naomiPreview"
            tokens: root.companionTokens
            width: 280
            height: 534 + 128
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            illustrationWidth: 280
            illustrationHeight: 534
            active: root.previewActive
            animationsEnabled: root.animationsEnabled
            reactToPointer: root.companionReactToPointer
            followPointer: true
        }
        SettingsButton {
            objectName: "settingsNaomiSayButton"
            tokens: root.tokens
            text: "Сказать реплику"
            anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
            onClicked: previewNaomi.say("Вот так я говорю. Тихо и коротко.", 0)
            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
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
        description: root.companionReactToPointer
            ? "Справа снизу на основном мониторе. Клики проходят сквозь Naomi, кроме небольшого овала вокруг головы."
            : "Справа снизу на основном мониторе. Не мешает нажимать на окна и рабочий стол."
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
    SettingsToggle {
        objectName: "settingsCompanionReactToggle"
        tokens: root.tokens
        text: "Реагировать на курсор"
        description: root.companionReactToPointer
            ? "Naomi замечает курсор над головой и радуется, когда её гладят. Вокруг головы на рабочем столе клики не проходят сквозь Naomi: это небольшой овал."
            : "Naomi не следит за курсором. Окно целиком пропускает клики и наведение."
        checked: root.companionReactToPointer
        onClicked: root.companionReactToPointerChangedRequested(checked)
        onFocusReceived: root.revealRequested(this)
    }
    SettingsToggle {
        objectName: "settingsCompanionSystemLinesToggle"
        tokens: root.tokens
        text: "Комментировать системные события"
        description: root.companionSystemLines
            ? "Naomi замечает высокую нагрузку, долгое бездействие и возвращение, новые терминалы и игры, множество окон, низкий заряд, ночную работу, обновление системы и потерю интернета. Реплики редкие, у каждой своя пауза."
            : "Naomi молчит о событиях системы. Приветствие, редкие реплики и реплики на поглаживание остаются."
        checked: root.companionSystemLines
        enabled: root.companionEnabled
        onClicked: root.companionSystemLinesChangedRequested(checked)
        onFocusReceived: root.revealRequested(this)
    }
    SettingsLabel {
        width: parent.width
        tokens: root.tokens
        text: root.animationsEnabled
            ? "Naomi дышит, моргает, качает волосами и шарфом, ушки иногда вздрагивают. Если провести курсором по голове, она зажмурится и улыбнётся, а облачко скажет пару слов. Здесь, в предпросмотре, голова ещё поворачивается за курсором."
            : "Анимации выключены в разделе «Внешний вид». Naomi отображается без движения, но по-прежнему говорит и реагирует на поглаживание."
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
}
