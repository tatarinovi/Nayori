pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../companion"

Column {
    id: root
    required property var tokens
    property var companionTokens: tokens
    property string companionStyle: "current"
    signal companionStyleChangedRequested(string style)
    property bool companionEnabled: false
    property bool companionDesktopOnly: false
    property bool companionReactToPointer: true
    property bool companionSystemLines: true
    property string fullscreenCompanionOutput: ""
    property string companionScreen: "primary"
    property string companionSide: "right"
    property bool animationsEnabled: true
    property bool previewActive: false
    // overview, look, place
    property string section: "overview"
    signal companionChangedRequested(bool enabled)
    signal companionDesktopOnlyChangedRequested(bool enabled)
    signal companionReactToPointerChangedRequested(bool enabled)
    signal companionSystemLinesChangedRequested(bool enabled)
    signal fullscreenCompanionOutputChangedRequested(string output)
    signal companionScreenChangedRequested(string screen)
    signal companionSideChangedRequested(string side)
    signal revealRequested(var item)
    readonly property var screens: Quickshell.screens
    readonly property var companionMonitorChoices: {
        const items = [{ key: "", label: "Не показывать" }]
        const list = screens || []
        const connected = {}
        let primary = ""
        for (let i = 0; i < list.length; ++i) {
            const screen = list[i]
            if (!screen)
                continue
            const name = screen.name || "Экран"
            if (primary === "") {
                primary = name
                continue
            }
            items.push({ key: name, label: name })
            connected[name] = true
        }
        if (fullscreenCompanionOutput !== "" && fullscreenCompanionOutput !== primary && !connected[fullscreenCompanionOutput])
            items.push({ key: fullscreenCompanionOutput, label: fullscreenCompanionOutput })
        return items
    }
    readonly property bool companionTargetMissing: {
        if (fullscreenCompanionOutput === "")
            return false
        const list = screens || []
        for (let i = 0; i < list.length; ++i)
            if (list[i] && (list[i].name || "Экран") === fullscreenCompanionOutput)
                return false
        return true
    }
    spacing: 16

    component PreviewFrame: Rectangle {
        id: frame
        property bool named: false
        width: root.width
        height: (root.companionStyle === "pixel-art" ? 400 : 534) + 154
        radius: root.tokens.radius.small
        color: root.tokens.color.background
        border.color: root.tokens.color.border
        // Над Naomi — место под облачко (128 пикселей), поэтому компонент выше иллюстрации.
        NaomiCompanion {
            id: previewNaomi
            companionStyle: root.companionStyle
            objectName: frame.named ? "naomiPreview" : ""
            tokens: root.companionTokens
            width: 280
            height: illustrationHeight + 128
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
            illustrationWidth: 280
            illustrationHeight: root.companionStyle === "pixel-art" ? 400 : 534
            active: root.previewActive
            animationsEnabled: root.animationsEnabled
            reactToPointer: root.companionReactToPointer
            followPointer: true
        }
        SettingsButton {
            objectName: frame.named ? "settingsNaomiSayButton" : ""
            tokens: root.tokens
            text: "Сказать реплику"
            anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
            onClicked: previewNaomi.say("Вот так я говорю. Тихо и коротко.", 0)
            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        }
    }

    Loader {
        active: root.section === "overview"
        visible: active
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Column {
            width: root.width
            spacing: 16
            SettingsToggle {
                objectName: "settingsCompanionToggle"
                tokens: root.tokens
                text: "Показывать Naomi на рабочем столе"
                description: root.companionReactToPointer
                    ? "Клики проходят сквозь Naomi, кроме небольшого овала вокруг головы."
                    : "Не мешает нажимать на окна и рабочий стол."
                checked: root.companionEnabled
                onClicked: root.companionChangedRequested(checked)
                onFocusReceived: root.revealRequested(this)
            }
            PreviewFrame { named: true }
            SettingsLabel {
                visible: !root.animationsEnabled
                width: parent.width
                tokens: root.tokens
                text: "Анимации выключены в разделе «Внешний вид». Naomi отображается без движения, но по-прежнему говорит и реагирует на поглаживание"
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
    Loader {
        active: root.section === "look"
        visible: active
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Column {
            width: root.width
            spacing: 16
            SettingsLabel { tokens: root.tokens; text: "Облик Naomi" }
            SettingsSegmented {
                objectName: "settingsNaomiStyle"
                tokens: root.tokens
                width: Math.min(parent.width, 360)
                model: [{key: "current", label: "Текущий"}, {key: "pixel-art", label: "Pixel art"}, {key: "layered", label: "Naomi v3"}]
                currentKey: root.companionStyle
                onActivated: key => root.companionStyleChangedRequested(key)
            }
            PreviewFrame { }
            SettingsLabel {
                width: parent.width
                tokens: root.tokens
                text: root.companionStyle === "layered"
                    ? "Naomi дышит, слегка покачивает головой и волосами и моргает. Цвета исходного рисунка."
                    : root.companionStyle === "pixel-art"
                    ? "Пиксельный рисунок без файлов изображений. Одежда, бант и глаза берут цвет из обоев основного монитора. Кожа и чёрные волосы сохраняют свой цвет."
                    : "Шарф, повязка на шее и заколка берут цвет из палитры обоев основного монитора. Волосы, кожа, одежда и глаза остаются неизменными."
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
    }
    Loader {
        active: root.section === "place"
        visible: active
        width: parent.width
        height: item ? item.implicitHeight : 0
        sourceComponent: Column {
            width: root.width
            spacing: 16
            Column {
                id: companionScreenBlock
                objectName: "settingsNaomiScreen"
                visible: (root.screens ? root.screens.length : 0) > 1 || root.companionScreen === "secondary"
                width: parent.width
                spacing: 8
                enabled: root.companionEnabled
                opacity: enabled ? 1 : 0.55
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Монитор"
                }
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Основной или второй подключённый экран"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                SettingsSegmented {
                    objectName: "settingsNaomiScreenChoice"
                    width: Math.min(parent.width, 360)
                    tokens: root.tokens
                    equalWidth: true
                    model: [{key: "primary", label: "Основной"}, {key: "secondary", label: "Второй"}]
                    currentKey: root.companionScreen
                    onActivated: key => root.companionScreenChangedRequested(key)
                    onFocusReceived: root.revealRequested(companionScreenBlock)
                }
                SettingsLabel {
                    visible: root.companionScreen === "secondary" && (root.screens ? root.screens.length : 0) < 2
                    width: parent.width
                    tokens: root.tokens
                    text: "Второй монитор не подключён. Naomi остаётся на\u00A0основном"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            Column {
                id: companionSideBlock
                objectName: "settingsNaomiSide"
                width: parent.width
                spacing: 8
                enabled: root.companionEnabled
                opacity: enabled ? 1 : 0.55
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Сторона"
                }
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Нижний угол экрана"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                NaomiSidePicker {
                    tokens: root.tokens
                    side: root.companionSide
                    onActivated: place => root.companionSideChangedRequested(place)
                    onFocusReceived: root.revealRequested(companionSideBlock)
                }
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
            Column {
                id: companionMonitorBlock
                objectName: "settingsNaomiMonitor"
                visible: (root.screens ? root.screens.length : 0) > 1 && root.companionScreen !== "secondary"
                width: parent.width
                spacing: 8
                enabled: root.companionEnabled
                opacity: enabled ? 1 : 0.55
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Монитор при полном экране"
                }
                SettingsLabel {
                    width: parent.width
                    tokens: root.tokens
                    text: "Пока основной монитор в\u00A0полноэкранном режиме, Naomi показывается на\u00A0выбранном экране"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
                SettingsSegmented {
                    objectName: "settingsNaomiMonitorChoice"
                    width: parent.width
                    tokens: root.tokens
                    equalWidth: true
                    model: root.companionMonitorChoices
                    currentKey: root.fullscreenCompanionOutput
                    onActivated: key => root.fullscreenCompanionOutputChangedRequested(key)
                    onFocusReceived: root.revealRequested(companionMonitorBlock)
                }
                SettingsLabel {
                    visible: root.companionTargetMissing
                    width: parent.width
                    tokens: root.tokens
                    text: "Выбранный монитор не подключён. Naomi остаётся скрытой, пока он не появится"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
