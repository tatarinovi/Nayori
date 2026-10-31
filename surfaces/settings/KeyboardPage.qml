pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    property var niriConfig: null
    spacing: 16
    property bool editing: false
    property string trackKey: ""
    property string cardError: ""

    component Label: SettingsLabel { tokens: root.tokens }
    component Choice: Item {
        id: choice
        property string title: ""
        property var options: []
        property string current: ""
        signal picked(string key)
        width: parent ? parent.width : implicitWidth
        implicitHeight: 38
        Label {
            anchors.left: parent.left
            anchors.right: select.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12
            text: choice.title
            elide: Text.ElideRight
        }
        SettingsSelect {
            id: select
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            tokens: root.tokens
            model: choice.options
            currentKey: choice.current
            onActivated: key => choice.picked(key)
        }
    }

    readonly property var tracks: [
        {key: "", label: "Не задана"},
        {key: "global", label: "Общая"},
        {key: "window", label: "Для окна"}
    ]

    function whole(text) {
        const cleaned = text.trim()
        if (cleaned === "")
            return null
        if (!/^\d+$/.test(cleaned))
            return NaN
        return Number(cleaned)
    }

    function pull() {
        if (editing)
            return
        const data = service.keyboard || {}
        layoutField.text = data.layout || ""
        variantField.text = data.variant || ""
        optionsField.text = data.options || ""
        delayField.text = data["repeat-delay"] === null || data["repeat-delay"] === undefined ? "" : String(data["repeat-delay"])
        rateField.text = data["repeat-rate"] === null || data["repeat-rate"] === undefined ? "" : String(data["repeat-rate"])
        trackKey = data["track-layout"] || ""
        numlockSwitch.checked = data.numlock === true
        cardError = ""
    }

    function textOrNull(value) {
        return value.trim() === "" ? null : value
    }

    function applyKeyboard() {
        cardError = ""
        const delay = whole(delayField.text)
        const rate = whole(rateField.text)
        if ((typeof delay === "number" && !isFinite(delay)) || (typeof rate === "number" && !isFinite(rate))) {
            cardError = "Задержка и частота повтора — целые числа. Пустое поле убирает строку"
            return
        }
        service.applyChanges({
            keyboard: {set: {
                layout: textOrNull(layoutField.text),
                variant: textOrNull(variantField.text),
                options: textOrNull(optionsField.text),
                "repeat-delay": delay,
                "repeat-rate": rate,
                "track-layout": trackKey === "" ? null : trackKey,
                numlock: numlockSwitch.checked
            }}
        })
    }

    NiriConfigApply {
        id: service
        onRevisionChanged: root.pull()
        onSettled: root.editing = false
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Раскладка и повтор записываются в блок keyboard. Список ниже niri отдаёт сам, эта страница его не переключает"
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.configPath !== ""
        text: "Файл: " + service.configPath
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.readerMismatch
        text: "Просмотр раскладок из сеанса остаётся. Запись идёт в файл, который открывает niri"
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: service.error !== ""
        text: service.error
    }
    Label {
        width: parent.width
        color: root.tokens.color.text
        font.pixelSize: 13
        visible: service.notice !== "" && service.error === ""
        text: service.notice
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.ready && !service.validateAvailable
        text: "Команда niri не найдена. Изменения не записываются, потому что их нельзя проверить"
    }

    SettingsCard {
        id: card
        tokens: root.tokens
        title: "Конфигурация"
        subtitle: "Несколько раскладок пишутся через запятую, например us,ru. Пустое поле убирает строку"
        readonly property bool locked: !!(service.keyboard && service.keyboard.editable === false)
        Label {
            width: parent.width
            visible: card.locked
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: service.keyboard && service.keyboard.lockedReason ? service.keyboard.lockedReason : "Этот блок Nayori не меняет"
        }
        Label { text: "Раскладки" }
        SettingsField {
            tokens: root.tokens
            id: layoutField
            enabled: !card.locked && service.validateAvailable
            placeholderText: "us,ru"
            onTextEdited: root.editing = true
        }
        Label { text: "Вариант" }
        SettingsField {
            tokens: root.tokens
            id: variantField
            enabled: !card.locked && service.validateAvailable
            placeholderText: ",winkeys"
            onTextEdited: root.editing = true
        }
        Label { text: "Параметры XKB" }
        SettingsField {
            tokens: root.tokens
            id: optionsField
            enabled: !card.locked && service.validateAvailable
            placeholderText: "grp:win_space_toggle"
            onTextEdited: root.editing = true
        }
        Label { text: "Задержка повтора, мс" }
        SettingsField {
            tokens: root.tokens
            id: delayField
            enabled: !card.locked && service.validateAvailable
            placeholderText: "600"
            onTextEdited: root.editing = true
        }
        Label { text: "Частота повтора" }
        SettingsField {
            tokens: root.tokens
            id: rateField
            enabled: !card.locked && service.validateAvailable
            placeholderText: "25"
            onTextEdited: root.editing = true
        }
        Choice {
            title: "Область раскладки"
            enabled: !card.locked && service.validateAvailable
            options: root.tracks
            current: root.trackKey
            onPicked: key => { root.editing = true; root.trackKey = key }
        }
        SettingsSwitch {
            id: numlockSwitch
            enabled: !card.locked && service.validateAvailable
            tokens: root.tokens
            text: "Num Lock при запуске"
            onClicked: root.editing = true
        }
        Label {
            width: parent.width
            visible: !!(service.keyboard && ((service.keyboard.model || "") !== "" || (service.keyboard.rules || "") !== ""))
            color: root.tokens.color.textMuted
            font.pixelSize: 13
            text: "Строки model и rules остаются в файле как есть"
        }
        Label {
            width: parent.width
            visible: !!(service.keyboard && service.keyboard.extra && service.keyboard.extra.length)
            color: root.tokens.color.textMuted
            font.pixelSize: 13
            text: "В блоке ещё есть строки, Nayori их не меняет: " + ((service.keyboard && service.keyboard.extra) ? service.keyboard.extra.join(", ") : "")
        }
        Label {
            width: parent.width
            visible: root.cardError !== ""
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: root.cardError
        }
        SettingsButton {
            text: "Применить"
            primary: true
            tokens: root.tokens
            enabled: !card.locked && service.ready && service.validateAvailable && !service.busy
            onClicked: root.applyKeyboard()
        }
    }

    Label { text: "Текущие раскладки"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: root.niriConfig && root.niriConfig.layoutsText !== "" ? root.niriConfig.layoutsText : "Раскладки ещё не прочитаны"
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.niriConfig && root.niriConfig.error !== "" && service.error === ""
        text: root.niriConfig ? root.niriConfig.error : ""
    }
}
