pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../services/island"
import "../../services/island/NotificationPolicy.js" as Policy

Column {
    id: root
    required property var tokens
    property bool notificationsEnabled: true
    property bool receptionEnabled: false
    property bool receptionAvailable: false
    property string receptionError: ""
    property var sources: []
    property bool dndManual: false
    property double dndUntil: 0
    signal notificationsEnabledChangedRequested(bool enabled)
    signal receptionChangedRequested(bool enabled)
    signal dndUntilRequested(double until)
    signal dndManualRequested()
    signal dndClearRequested()
    signal sourceModeRequested(string key, string mode)
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }
    readonly property var sourceModes: [
        {key: "normal", label: "Обычный показ"},
        {key: "expanded", label: "Только в развёрнутом острове"},
        {key: "off", label: "Отключено"}
    ]
    property DoNotDisturb dndClock: DoNotDisturb {
        manual: root.dndManual
        until: root.dndUntil
    }

    function startFor(minutes) {
        root.dndUntilRequested(Policy.untilFromMinutes(Date.now(), minutes))
    }

    SettingsCard {
        width: parent.width
        tokens: root.tokens
        title: "Показ"
        subtitle: "Общий переключатель относится и к системным, и к уведомлениям Nayori"
        SettingsToggle {
            objectName: "notificationEnabledToggle"
            tokens: root.tokens
            text: "Показывать уведомления"
            description: "Новые уведомления не попадают в историю и на остров. Уже сохранённые остаются"
            checked: root.notificationsEnabled
            onClicked: root.notificationsEnabledChangedRequested(checked)
        }
    }

    SettingsCard {
        width: parent.width
        tokens: root.tokens
        title: "Системный приём"
        subtitle: "Nayori занимает сервис уведомлений. Если имя уже занято, приём не включается"
        SettingsToggle {
            objectName: "notificationReceptionToggle"
            tokens: root.tokens
            text: "Принимать системные уведомления"
            checked: root.receptionEnabled
            onClicked: root.receptionChangedRequested(checked)
        }
        Label {
            objectName: "notificationReceptionStatus"
            width: parent.width
            font.pixelSize: 13
            color: root.receptionEnabled && root.receptionError ? root.tokens.color.secondary : root.tokens.color.textMuted
            text: !root.receptionEnabled ? "Приём выключен"
                  : root.receptionError ? root.receptionError
                  : root.receptionAvailable ? "Приём работает"
                  : "Запуск приёма…"
        }
        Label {
            objectName: "notificationReceptionHint"
            width: parent.width
            visible: root.receptionEnabled && root.receptionError.length > 0
            font.pixelSize: 13
            color: root.tokens.color.textMuted
            text: "Выключите приём и включите снова, чтобы повторить."
        }
    }

    SettingsCard {
        width: parent.width
        tokens: root.tokens
        title: "Не беспокоить"
        subtitle: "Новые уведомления остаются в истории и не появляются в свёрнутом острове, в том числе после окончания режима"
        Label {
            objectName: "notificationDndStatus"
            width: parent.width
            visible: root.dndClock.active
            color: root.tokens.color.text
            text: root.dndManual ? "Пока не выключите" : root.dndClock.label
        }
        Flow {
            width: parent.width
            spacing: 8
            SettingsButton {
                objectName: "notificationDnd15"
                tokens: root.tokens
                text: "15 минут"
                onClicked: root.startFor(15)
            }
            SettingsButton {
                objectName: "notificationDnd60"
                tokens: root.tokens
                text: "1 час"
                onClicked: root.startFor(60)
            }
            SettingsButton {
                objectName: "notificationDnd120"
                tokens: root.tokens
                text: "2 часа"
                onClicked: root.startFor(120)
            }
            SettingsButton {
                objectName: "notificationDndManual"
                tokens: root.tokens
                text: "До выключения"
                onClicked: root.dndManualRequested()
            }
        }
        RowLayout {
            width: parent.width
            spacing: 8
            SpinBox {
                id: customMinutes
                objectName: "notificationDndMinutes"
                Layout.fillWidth: true
                from: 1
                to: 1440
                value: 30
                editable: true
                implicitHeight: root.tokens.settings.control
                palette.text: root.tokens.color.text
                palette.buttonText: root.tokens.color.text
                palette.base: root.tokens.color.surfaceAlt
                palette.button: root.tokens.color.surfaceAlt
                palette.highlight: root.tokens.color.accent
                palette.highlightedText: root.tokens.color.accentText
                Accessible.name: "Своё время режима «Не беспокоить», минуты"
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.settings.body
            }
            SettingsButton {
                objectName: "notificationDndCustom"
                tokens: root.tokens
                text: "Включить"
                primary: true
                onClicked: root.startFor(customMinutes.value)
            }
        }
        Label {
            width: parent.width
            font.pixelSize: 13
            color: root.tokens.color.textMuted
            text: "Своё время — от 1 минуты до 24 часов"
        }
        SettingsButton {
            objectName: "notificationDndOff"
            visible: root.dndClock.active
            tokens: root.tokens
            text: "Выключить"
            onClicked: root.dndClearRequested()
        }
    }

    SettingsCard {
        width: parent.width
        tokens: root.tokens
        title: "Приложения"
        subtitle: "Обычный показ — оба состояния острова. Только в развёрнутом — история без свёрнутого острова. Отключено — новые уведомления не сохраняются"
        Label {
            objectName: "notificationSourcesEmpty"
            width: parent.width
            visible: !root.sources || root.sources.length === 0
            font.pixelSize: 13
            color: root.tokens.color.textMuted
            text: "Приложения появятся после первого уведомления."
        }
        Repeater {
            model: root.sources || []
            delegate: Column {
                id: sourceRow
                required property var modelData
                width: parent.width
                spacing: 8
                Label {
                    objectName: "notificationSourceTitle"
                    width: parent.width
                    text: sourceRow.modelData.title || sourceRow.modelData.appName || sourceRow.modelData.key
                }
                SettingsSelect {
                    objectName: "notificationSourceMode"
                    width: Math.min(320, parent.width)
                    tokens: root.tokens
                    model: root.sourceModes
                    currentKey: sourceRow.modelData.mode || "normal"
                    Accessible.name: "Показ уведомлений " + (sourceRow.modelData.title || "")
                    onActivated: key => root.sourceModeRequested(sourceRow.modelData.key, key)
                }
            }
        }
    }
}
