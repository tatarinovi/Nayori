pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    property var niriConfig: null
    spacing: 16
    property bool editing: false
    property string mouseProfile: ""
    property string mouseScroll: ""
    property bool mouseAccelUnset: true
    property real mouseAccel: 0
    property string padProfile: ""
    property string padScroll: ""
    property string padClick: ""
    property string padMap: ""
    property string padDrag: ""
    property bool padAccelUnset: true
    property real padAccel: 0

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

    readonly property var profiles: [
        {key: "", label: "Не задан"},
        {key: "flat", label: "Ровный"},
        {key: "adaptive", label: "Адаптивный"}
    ]
    readonly property var scrolls: [
        {key: "", label: "Не задана"},
        {key: "two-finger", label: "Двумя пальцами"},
        {key: "edge", label: "От края"},
        {key: "on-button-down", label: "Кнопкой"},
        {key: "no-scroll", label: "Без прокрутки"}
    ]
    readonly property var clicks: [
        {key: "", label: "Не задан"},
        {key: "button-areas", label: "Области кнопок"},
        {key: "clickfinger", label: "Число пальцев"}
    ]
    readonly property var maps: [
        {key: "", label: "Не заданы"},
        {key: "left-right-middle", label: "Левая, правая, средняя"},
        {key: "left-middle-right", label: "Левая, средняя, правая"}
    ]
    readonly property var drags: [
        {key: "", label: "Не задано"},
        {key: "true", label: "Включено"},
        {key: "false", label: "Выключено"}
    ]

    function optionalNumber(text) {
        const cleaned = text.trim().replace(",", ".")
        if (cleaned === "")
            return null
        const value = Number(cleaned)
        return isFinite(value) ? value : NaN
    }

    function accelText(unset, value) {
        if (unset)
            return "не задана"
        return String(Math.round(value * 100) / 100).replace(".", ",")
    }

    function pullDevice(block, prefix) {
        const data = block || {}
        if (prefix === "mouse") {
            mouseOff.checked = data.off === true
            mouseNatural.checked = data["natural-scroll"] === true
            mouseLeft.checked = data["left-handed"] === true
            mouseMiddle.checked = data["middle-emulation"] === true
            mouseProfile = data["accel-profile"] || ""
            mouseScroll = data["scroll-method"] || ""
            mouseFactor.text = data["scroll-factor"] === null || data["scroll-factor"] === undefined ? "" : String(data["scroll-factor"])
            mouseAccelUnset = data["accel-speed"] === null || data["accel-speed"] === undefined
            mouseAccel = mouseAccelUnset ? 0 : Number(data["accel-speed"])
        } else {
            padOff.checked = data.off === true
            padTap.checked = data.tap === true
            padDwt.checked = data.dwt === true
            padDwtp.checked = data.dwtp === true
            padNatural.checked = data["natural-scroll"] === true
            padLeft.checked = data["left-handed"] === true
            padMiddle.checked = data["middle-emulation"] === true
            padLock.checked = data["drag-lock"] === true
            padExternal.checked = data["disabled-on-external-mouse"] === true
            padButtonLock.checked = data["scroll-button-lock"] === true
            padProfile = data["accel-profile"] || ""
            padScroll = data["scroll-method"] || ""
            padClick = data["click-method"] || ""
            padMap = data["tap-button-map"] || ""
            padDrag = data.drag === true ? "true" : data.drag === false ? "false" : ""
            padFactor.text = data["scroll-factor"] === null || data["scroll-factor"] === undefined ? "" : String(data["scroll-factor"])
            padButton.text = data["scroll-button"] === null || data["scroll-button"] === undefined ? "" : String(data["scroll-button"])
            padAccelUnset = data["accel-speed"] === null || data["accel-speed"] === undefined
            padAccel = padAccelUnset ? 0 : Number(data["accel-speed"])
        }
    }

    function pull() {
        if (editing)
            return
        pullDevice(service.mouse, "mouse")
        pullDevice(service.touchpad, "pad")
        mouseError = ""
        padError = ""
    }

    function mark() {
        editing = true
    }

    property string mouseError: ""
    property string padError: ""

    function applyMouse() {
        mouseError = ""
        const factor = optionalNumber(mouseFactor.text)
        if (typeof factor === "number" && !isFinite(factor)) {
            mouseError = "Множитель прокрутки должен быть числом"
            return
        }
        service.applyChanges({
            mouse: {set: {
                off: mouseOff.checked,
                "natural-scroll": mouseNatural.checked,
                "left-handed": mouseLeft.checked,
                "middle-emulation": mouseMiddle.checked,
                "accel-profile": mouseProfile === "" ? null : mouseProfile,
                "scroll-method": mouseScroll === "" ? null : mouseScroll,
                "accel-speed": mouseAccelUnset ? null : Math.round(mouseAccel * 100) / 100,
                "scroll-factor": factor
            }}
        })
    }

    function applyPad() {
        padError = ""
        const factor = optionalNumber(padFactor.text)
        const button = optionalNumber(padButton.text)
        if ((typeof factor === "number" && !isFinite(factor)) || (typeof button === "number" && !isFinite(button))) {
            padError = "Нужны числа. Пустое поле убирает строку"
            return
        }
        if (button !== null && !Number.isInteger(button)) {
            padError = "Кнопка прокрутки — целое число"
            return
        }
        service.applyChanges({
            touchpad: {set: {
                off: padOff.checked,
                tap: padTap.checked,
                dwt: padDwt.checked,
                dwtp: padDwtp.checked,
                "natural-scroll": padNatural.checked,
                "left-handed": padLeft.checked,
                "middle-emulation": padMiddle.checked,
                "drag-lock": padLock.checked,
                "disabled-on-external-mouse": padExternal.checked,
                "scroll-button-lock": padButtonLock.checked,
                drag: padDrag === "" ? null : padDrag === "true",
                "accel-profile": padProfile === "" ? null : padProfile,
                "scroll-method": padScroll === "" ? null : padScroll,
                "click-method": padClick === "" ? null : padClick,
                "tap-button-map": padMap === "" ? null : padMap,
                "accel-speed": padAccelUnset ? null : Math.round(padAccel * 100) / 100,
                "scroll-factor": factor,
                "scroll-button": button
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
        text: "Скорость, прокрутка и касание записываются в блоки mouse и touchpad. Настройки GNOME на сессию niri не влияют"
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
        text: "Текст из старого просмотра может относиться к другому файлу. Запись идёт в файл, который открывает niri"
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
        id: mouseCard
        tokens: root.tokens
        title: "Мышь"
        subtitle: "Переключатель без строки в файле выключен. Пустое поле убирает строку"
        readonly property bool locked: !!(service.mouse && service.mouse.editable === false)
        Label {
            width: parent.width
            visible: mouseCard.locked
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: service.mouse && service.mouse.lockedReason ? service.mouse.lockedReason : "Этот блок Nayori не меняет"
        }
        SettingsSwitch {
            id: mouseOff
            enabled: !mouseCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Отключение"
            description: "В блоке появляется строка off"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: mouseNatural
            enabled: !mouseCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Естественная прокрутка"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: mouseLeft
            enabled: !mouseCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Левая рука"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: mouseMiddle
            enabled: !mouseCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Эмуляция средней кнопки"
            onClicked: root.mark()
        }
        Choice {
            title: "Профиль ускорения"
            enabled: !mouseCard.locked && service.validateAvailable
            options: root.profiles
            current: root.mouseProfile
            onPicked: key => { root.mark(); root.mouseProfile = key }
        }
        Choice {
            title: "Прокрутка"
            enabled: !mouseCard.locked && service.validateAvailable
            options: root.scrolls
            current: root.mouseScroll
            onPicked: key => { root.mark(); root.mouseScroll = key }
        }
        Label { text: "Скорость указателя · " + root.accelText(root.mouseAccelUnset, root.mouseAccel) }
        SettingsSlider {
            width: parent.width
            enabled: !mouseCard.locked && service.validateAvailable
            tokens: root.tokens
            from: -1
            to: 1
            stepSize: 0.05
            source: root.mouseAccel
            label: "Скорость указателя"
            onChanged: value => {
                root.mark()
                root.mouseAccelUnset = false
                root.mouseAccel = value
            }
        }
        SettingsButton {
            visible: !root.mouseAccelUnset
            text: "Убрать скорость"
            tokens: root.tokens
            enabled: !mouseCard.locked && service.validateAvailable
            onClicked: {
                root.mark()
                root.mouseAccelUnset = true
                root.mouseAccel = 0
            }
        }
        Label { text: "Множитель прокрутки" }
        SettingsField {
            tokens: root.tokens
            id: mouseFactor
            enabled: !mouseCard.locked && service.validateAvailable
            placeholderText: "1"
            onTextEdited: root.mark()
        }
        Label {
            width: parent.width
            visible: !!(service.mouse && service.mouse.extra && service.mouse.extra.length)
            color: root.tokens.color.textMuted
            font.pixelSize: 13
            text: "В блоке ещё есть строки, Nayori их не меняет: " + ((service.mouse && service.mouse.extra) ? service.mouse.extra.join(", ") : "")
        }
        Label {
            width: parent.width
            visible: root.mouseError !== ""
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: root.mouseError
        }
        SettingsButton {
            text: "Применить"
            primary: true
            tokens: root.tokens
            enabled: !mouseCard.locked && service.ready && service.validateAvailable && !service.busy
            onClicked: root.applyMouse()
        }
    }

    SettingsCard {
        id: padCard
        tokens: root.tokens
        title: "Тачпад"
        subtitle: "Касание, пауза при наборе и прокрутка пишутся в блок touchpad"
        readonly property bool locked: !!(service.touchpad && service.touchpad.editable === false)
        Label {
            width: parent.width
            visible: padCard.locked
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: service.touchpad && service.touchpad.lockedReason ? service.touchpad.lockedReason : "Этот блок Nayori не меняет"
        }
        SettingsSwitch {
            id: padOff
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Отключение"
            description: "В блоке появляется строка off"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padTap
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Касание"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padDwt
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Пауза при наборе"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padDwtp
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Пауза при трекпоинте"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padNatural
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Естественная прокрутка"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padLeft
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Левая рука"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padMiddle
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Эмуляция средней кнопки"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padLock
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Фиксация перетаскивания"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padExternal
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Пауза при внешней мыши"
            onClicked: root.mark()
        }
        SettingsSwitch {
            id: padButtonLock
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            text: "Фиксация кнопки прокрутки"
            onClicked: root.mark()
        }
        Choice {
            title: "Перетаскивание"
            enabled: !padCard.locked && service.validateAvailable
            options: root.drags
            current: root.padDrag
            onPicked: key => { root.mark(); root.padDrag = key }
        }
        Choice {
            title: "Профиль ускорения"
            enabled: !padCard.locked && service.validateAvailable
            options: root.profiles
            current: root.padProfile
            onPicked: key => { root.mark(); root.padProfile = key }
        }
        Choice {
            title: "Прокрутка"
            enabled: !padCard.locked && service.validateAvailable
            options: root.scrolls
            current: root.padScroll
            onPicked: key => { root.mark(); root.padScroll = key }
        }
        Choice {
            title: "Способ нажатия"
            enabled: !padCard.locked && service.validateAvailable
            options: root.clicks
            current: root.padClick
            onPicked: key => { root.mark(); root.padClick = key }
        }
        Choice {
            title: "Кнопки касания"
            enabled: !padCard.locked && service.validateAvailable
            options: root.maps
            current: root.padMap
            onPicked: key => { root.mark(); root.padMap = key }
        }
        Label { text: "Скорость указателя · " + root.accelText(root.padAccelUnset, root.padAccel) }
        SettingsSlider {
            width: parent.width
            enabled: !padCard.locked && service.validateAvailable
            tokens: root.tokens
            from: -1
            to: 1
            stepSize: 0.05
            source: root.padAccel
            label: "Скорость тачпада"
            onChanged: value => {
                root.mark()
                root.padAccelUnset = false
                root.padAccel = value
            }
        }
        SettingsButton {
            visible: !root.padAccelUnset
            text: "Убрать скорость"
            tokens: root.tokens
            enabled: !padCard.locked && service.validateAvailable
            onClicked: {
                root.mark()
                root.padAccelUnset = true
                root.padAccel = 0
            }
        }
        Label { text: "Множитель прокрутки" }
        SettingsField {
            tokens: root.tokens
            id: padFactor
            enabled: !padCard.locked && service.validateAvailable
            placeholderText: "1"
            onTextEdited: root.mark()
        }
        Label { text: "Кнопка прокрутки" }
        SettingsField {
            tokens: root.tokens
            id: padButton
            enabled: !padCard.locked && service.validateAvailable
            placeholderText: "273"
            onTextEdited: root.mark()
        }
        Label {
            width: parent.width
            visible: !!(service.touchpad && service.touchpad.extra && service.touchpad.extra.length)
            color: root.tokens.color.textMuted
            font.pixelSize: 13
            text: "В блоке ещё есть строки, Nayori их не меняет: " + ((service.touchpad && service.touchpad.extra) ? service.touchpad.extra.join(", ") : "")
        }
        Label {
            width: parent.width
            visible: root.padError !== ""
            color: root.tokens.color.secondary
            font.pixelSize: 13
            text: root.padError
        }
        SettingsButton {
            text: "Применить"
            primary: true
            tokens: root.tokens
            enabled: !padCard.locked && service.ready && service.validateAvailable && !service.busy
            onClicked: root.applyPad()
        }
    }
}
