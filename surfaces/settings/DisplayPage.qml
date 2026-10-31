pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"
import "MonitorLayout.js" as MonitorLayout

Column {
    id: root
    required property var tokens
    spacing: 16
    property bool editing: false
    property bool layoutDirty: false
    property string selectedName: ""
    property var monitorModel: []
    property var layout: []

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
            lineHeight: 1
            verticalAlignment: Text.AlignVCenter
        }
        SettingsSelect {
            id: select
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            enabled: choice.enabled
            opacity: choice.enabled ? 1 : 0.45
            tokens: root.tokens
            model: choice.options
            currentKey: choice.current
            onActivated: key => choice.picked(key)
        }
    }

    function scaleText(value) {
        if (typeof value !== "number" || !isFinite(value))
            return ""
        return String(Math.round(value * 100) / 100).replace(".", ",")
    }

    function orientationText(value) {
        if (value === Qt.LandscapeOrientation)
            return "альбомная"
        if (value === Qt.PortraitOrientation)
            return "портретная"
        if (value === Qt.InvertedLandscapeOrientation)
            return "альбомная, перевёрнутая"
        if (value === Qt.InvertedPortraitOrientation)
            return "портретная, перевёрнутая"
        return ""
    }

    function screenText(screen) {
        const scale = scaleText(screen.devicePixelRatio)
        const orientation = orientationText(screen.orientation)
        const parts = [
            screen.width + "×" + screen.height,
            "положение " + screen.x + ", " + screen.y
        ]
        if (scale !== "")
            parts.push("масштаб " + scale)
        if (screen.model)
            parts.push(screen.model)
        if (orientation !== "")
            parts.push(orientation)
        return parts.join(" · ")
    }

    function scaleOptions(current) {
        const preset = ["1", "1.25", "1.5", "1.75", "2", "2.5", "3"]
        const labels = {
            "1": "100%",
            "1.25": "125%",
            "1.5": "150%",
            "1.75": "175%",
            "2": "200%",
            "2.5": "250%",
            "3": "300%"
        }
        const options = [{key: "", label: "Не задан"}]
        const seen = {"": true}
        for (let index = 0; index < preset.length; index++) {
            const key = preset[index]
            seen[key] = true
            options.push({key: key, label: labels[key]})
        }
        if (current && !seen[current])
            options.push({key: current, label: current.replace(".", ",")})
        return options
    }

    function numberKey(value) {
        if (value === null || value === undefined || value === "")
            return ""
        const number = Number(value)
        if (!isFinite(number))
            return ""
        if (Math.abs(number - Math.round(number)) < 1e-9)
            return String(Math.round(number))
        return String(Math.round(number * 10000) / 10000)
    }

    function buildMonitors() {
        const byName = {}
        const order = []
        function ensure(name) {
            if (!name)
                return null
            if (!byName[name]) {
                byName[name] = {name: name, config: null, screen: null, live: null}
                order.push(name)
            }
            return byName[name]
        }
        const configured = service.outputs || []
        for (let index = 0; index < configured.length; index++) {
            const item = ensure(configured[index].name)
            if (!item)
                continue
            if (!item.config || configured[index].editable)
                item.config = configured[index]
        }
        const screens = displays.screens
        if (screens) {
            for (let index = 0; index < screens.length; index++) {
                const screen = screens[index]
                const item = ensure(screen && screen.name ? screen.name : "")
                if (item)
                    item.screen = screen
            }
        }
        const live = service.liveOutputs || []
        for (let index = 0; index < live.length; index++) {
            const item = ensure(live[index].name)
            if (item)
                item.live = live[index]
        }
        const result = []
        for (let index = 0; index < order.length; index++)
            result.push(byName[order[index]])
        return result
    }

    function refreshModel() {
        if (editing)
            return
        monitorModel = buildMonitors()
        syncLayout()
    }

    function layoutSource() {
        const rows = []
        for (let index = 0; index < monitorModel.length; index++) {
            const item = monitorModel[index]
            const config = item.config || {}
            const live = item.live || {}
            const screen = item.screen
            let hasPos = false
            let posX = 0
            let posY = 0
            function known(value) {
                return value !== null && value !== undefined && value !== "" && isFinite(Number(value))
            }
            if (config.position && known(config.position.x) && known(config.position.y)) {
                hasPos = true
                posX = Number(config.position.x)
                posY = Number(config.position.y)
            } else if (known(live.x) && known(live.y)) {
                hasPos = true
                posX = Number(live.x)
                posY = Number(live.y)
            } else if (screen && known(screen.x) && known(screen.y)) {
                hasPos = true
                posX = Number(screen.x)
                posY = Number(screen.y)
            }
            const scale = config.scale !== null && config.scale !== undefined && config.scale !== ""
                ? Number(config.scale)
                : (known(live.scale) ? Number(live.scale) : (screen ? Number(screen.devicePixelRatio) : 1))
            rows.push({
                name: item.name,
                mode: config.mode || live.currentMode || "",
                scale: scale,
                transform: config.transform || "",
                screenWidth: screen ? screen.width : 0,
                screenHeight: screen ? screen.height : 0,
                hasPos: hasPos,
                posX: posX,
                posY: posY,
                locked: config.editable === false,
                modeLabel: modeLabelOf(item)
            })
        }
        return rows
    }

    function modeLabelOf(item) {
        const config = item.config || {}
        const live = item.live || {}
        const raw = config.mode || live.currentMode || ""
        if (raw)
            return String(raw).replace("x", "×").split("@")[0]
        if (item.screen)
            return item.screen.width + "×" + item.screen.height
        return ""
    }

    function syncLayout() {
        if (layoutDirty || editing)
            return
        const next = MonitorLayout.fromModel(layoutSource())
        layout = next
        if (!positionOf(selectedName))
            selectedName = next.length ? next[0].name : ""
    }

    function positionOf(name) {
        for (let index = 0; index < layout.length; index++) {
            if (layout[index].name === name)
                return layout[index]
        }
        return null
    }

    property string primaryDraft: ""

    function primaryName() {
        const screens = displays.screens
        if (!screens || !screens.length || !screens[0])
            return ""
        return screens[0].name || ""
    }

    function configuredPrimary() {
        let marked = ""
        for (let index = 0; index < monitorModel.length; index++) {
            const item = monitorModel[index]
            if (item.config && item.config.focusAtStartup)
                marked = item.name
        }
        return marked
    }

    function effectivePrimary() {
        if (primaryDraft !== "")
            return primaryDraft
        const marked = configuredPrimary()
        if (marked !== "")
            return marked
        return primaryName()
    }

    function primaryOptions() {
        const options = []
        for (let index = 0; index < monitorModel.length; index++) {
            const name = monitorModel[index].name
            if (name)
                options.push({key: name, label: name})
        }
        return options
    }

    function choosePrimary(name) {
        const marked = configuredPrimary()
        const current = marked !== "" ? marked : primaryName()
        primaryDraft = name === current ? "" : name
        if (primaryDraft !== "")
            editing = true
    }

    function splitMode(mode) {
        const text = mode ? String(mode).trim() : ""
        const at = text.indexOf("@")
        if (at < 0)
            return {size: text, refresh: ""}
        return {size: text.slice(0, at), refresh: text.slice(at + 1)}
    }

    function joinMode(size, refresh) {
        const width = size ? String(size).trim() : ""
        const rate = refresh ? String(refresh).trim().replace(",", ".") : ""
        if (width === "")
            return ""
        if (rate === "")
            return width
        return width + "@" + rate
    }

    DisplayList { id: displays }
    NiriConfigApply {
        id: service
        watchOutputs: true
        onRevisionChanged: root.refreshModel()
        onSettled: {
            root.editing = false
            root.layoutDirty = false
            root.primaryDraft = ""
            root.refreshModel()
        }
    }

    Choice {
        title: "Основной монитор"
        visible: root.monitorModel.length > 1
        enabled: service.validateAvailable && !service.busy
        options: root.primaryOptions()
        current: root.effectivePrimary()
        onPicked: key => root.choosePrimary(key)
    }
    Label {
        width: parent.width
        visible: root.primaryDraft !== ""
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Запишется по кнопке «Применить». При запуске niri поставит фокус на этот экран"
    }

    SettingsCard {
        tokens: root.tokens
        title: ""
        Row {
            width: parent.width
            spacing: 12
            Column {
                width: parent.width - refreshMonitors.implicitWidth - parent.spacing
                spacing: 4
                Label {
                    width: parent.width
                    text: "Расположение мониторов"
                    font.family: root.tokens.type.display.family
                    font.pixelSize: root.tokens.type.display.size + 2
                }
                Label {
                    width: parent.width
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    text: "Перетащите мониторы, чтобы изменить расположение. Положение X и Y рассчитывается автоматически"
                }
            }
            SettingsButton {
                id: refreshMonitors
                tokens: root.tokens
                text: "Обновить"
                enabled: !service.busy
                onClicked: {
                    root.editing = false
                    root.layoutDirty = false
                    root.primaryDraft = ""
                    service.reload()
                }
            }
        }
        MonitorArrangement {
            width: parent.width
            tokens: root.tokens
            monitors: root.layout
            selectedName: root.selectedName
            primaryName: root.effectivePrimary()
            snap: true
            onChosen: name => root.selectedName = name
            onArranged: monitors => {
                root.layoutDirty = true
                root.editing = true
                root.layout = monitors
            }
        }
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.readerMismatch
        text: "Просмотр конфигурации читает другой файл. Эта страница меняет файл, который открывает niri"
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
        visible: !service.validateAvailable && service.ready
        text: "Команда niri не найдена. Изменения не записываются, потому что их нельзя проверить"
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.modesError !== ""
        text: service.modesError + ". Разрешение и частоту можно вписать вручную, например 1920x1080 и 60"
    }

    SettingsCard {
        visible: service.pending
        tokens: root.tokens
        title: "Картинка на месте?"
        subtitle: "Если не нажать «Оставить», Nayori вернёт прежние настройки экрана"
        highlighted: true
        Label {
            width: parent.width
            text: "Осталось " + service.secondsLeft + " с"
        }
        Row {
            spacing: 8
            SettingsButton {
                tokens: root.tokens
                text: "Оставить"
                primary: true
                enabled: !service.busy
                onClicked: service.confirm()
            }
            SettingsButton {
                tokens: root.tokens
                text: "Вернуть"
                enabled: !service.busy
                onClicked: service.rollback()
            }
        }
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: service.ready && root.monitorModel.length === 0 && service.error === ""
        text: "Подключённых экранов нет, и в конфигурации нет блоков output"
    }

    Repeater {
        model: root.monitorModel
        delegate: SettingsCard {
            id: card
            required property var modelData
            required property int index
            visible: modelData.name === root.selectedName
            width: root.width
            tokens: root.tokens
            title: ""
            highlighted: modelData.name === root.selectedName
            TapHandler {
                onTapped: root.selectedName = card.modelData.name
            }
            property string sizeKey: ""
            property string refreshKey: ""
            property string scaleKey: ""
            property string transformKey: ""
            property string vrrKey: "off"
            property string cardError: ""
            readonly property bool modesKnown: !!(modelData.live && modelData.live.modes && modelData.live.modes.length)
            readonly property bool locked: !!(modelData.config && modelData.config.editable === false)
            readonly property string unsetTransform: {
                const orient = root.orientationText(modelData.screen ? modelData.screen.orientation : undefined)
                return orient ? "Не задан (" + orient.charAt(0).toUpperCase() + orient.slice(1) + ")" : "Не задан"
            }
            readonly property var transforms: [
                {key: "", label: card.unsetTransform},
                {key: "normal", label: "Обычный"},
                {key: "90", label: "90°"},
                {key: "180", label: "180°"},
                {key: "270", label: "270°"},
                {key: "flipped", label: "Отражение"},
                {key: "flipped-90", label: "Отражение 90°"},
                {key: "flipped-180", label: "Отражение 180°"},
                {key: "flipped-270", label: "Отражение 270°"}
            ]
            readonly property var vrrOptions: [
                {key: "off", label: "Выключена"},
                {key: "on", label: "Включена"},
                {key: "on-demand", label: "По запросу окна"}
            ]

            function subtitleText() {
                const placed = root.positionOf(modelData.name)
                const parts = []
                if (placed && placed.modeLabel)
                    parts.push(placed.modeLabel)
                if (placed)
                    parts.push("положение " + placed.x + ", " + placed.y)
                const scale = root.scaleText(modelData.config && modelData.config.scale !== null && modelData.config.scale !== undefined
                    ? Number(modelData.config.scale)
                    : (modelData.screen ? modelData.screen.devicePixelRatio : NaN))
                if (scale !== "")
                    parts.push("масштаб " + scale)
                if (modelData.screen && modelData.screen.model)
                    parts.push(modelData.screen.model)
                else if (!modelData.screen)
                    parts.push("сейчас не подключён")
                const orient = root.orientationText(modelData.screen ? modelData.screen.orientation : undefined)
                if (orient)
                    parts.push(orient)
                if (!modelData.config)
                    parts.push("в конфигурации ещё нет блока")
                if (card.locked && modelData.config.lockedReason)
                    parts.push(modelData.config.lockedReason)
                return parts.join(" · ")
            }

            function liveModes() {
                return modelData.live && modelData.live.modes ? modelData.live.modes : []
            }

            function ratesFor(size) {
                const rates = []
                const seen = {}
                const modes = liveModes()
                for (let index = 0; index < modes.length; index++) {
                    const mode = modes[index]
                    if (!mode)
                        continue
                    const key = mode.width + "x" + mode.height
                    if (key !== size || seen[mode.refresh])
                        continue
                    seen[mode.refresh] = true
                    rates.push(mode)
                }
                return rates
            }

            function pickRefresh(size, current) {
                const rates = ratesFor(size)
                if (!rates.length)
                    return current
                for (let index = 0; index < rates.length; index++) {
                    if (rates[index].refresh === current)
                        return current
                }
                for (let index = 0; index < rates.length; index++) {
                    if (rates[index].preferred)
                        return rates[index].refresh
                }
                return rates[0].refresh
            }

            function sizeOptions() {
                const options = [{key: "", label: "Как выберет niri"}]
                const seen = {}
                const modes = liveModes()
                for (let index = 0; index < modes.length; index++) {
                    const mode = modes[index]
                    if (!mode)
                        continue
                    const key = mode.width + "x" + mode.height
                    if (!seen[key])
                        seen[key] = {key: key, label: mode.width + "×" + mode.height, preferred: false}
                    if (mode.preferred)
                        seen[key].preferred = true
                }
                const keys = Object.keys(seen)
                for (let index = 0; index < keys.length; index++) {
                    const item = seen[keys[index]]
                    options.push({
                        key: item.key,
                        label: item.preferred ? item.label + ", рекомендуемое" : item.label
                    })
                }
                if (sizeKey && !seen[sizeKey])
                    options.push({key: sizeKey, label: sizeKey.replace("x", "×")})
                return options
            }

            function refreshOptions() {
                const options = [{key: "", label: "Как выберет niri"}]
                const seen = {"": true}
                const rates = ratesFor(sizeKey)
                for (let index = 0; index < rates.length; index++) {
                    const mode = rates[index]
                    seen[mode.refresh] = true
                    let label = String(mode.refresh).replace(".", ",") + "\u00A0Гц"
                    if (mode.preferred)
                        label += ", рекомендуемая"
                    options.push({key: mode.refresh, label: label})
                }
                if (refreshKey && !seen[refreshKey])
                    options.push({key: refreshKey, label: String(refreshKey).replace(".", ",") + "\u00A0Гц"})
                return options
            }

            function pull() {
                const config = modelData.config || {}
                const parts = root.splitMode(config.mode || "")
                sizeKey = parts.size
                refreshKey = parts.refresh
                scaleKey = root.numberKey(config.scale)
                transformKey = config.transform || ""
                vrrKey = config.vrr || "off"
                offSwitch.checked = config.off === true
                sizeField.text = parts.size
                refreshField.text = parts.refresh
                cardError = ""
            }

            function applyCard() {
                cardError = ""
                const placed = root.positionOf(modelData.name)
                const position = placed ? {x: placed.x, y: placed.y} : null
                const modeText = card.modesKnown
                    ? root.joinMode(sizeKey, refreshKey)
                    : root.joinMode(sizeField.text, refreshField.text)
                const mode = modeText === "" ? null : modeText
                root.editing = true
                service.applyChanges({
                    output: {
                        name: modelData.name,
                        set: {
                            mode: mode,
                            scale: scaleKey === "" ? null : Number(scaleKey),
                            transform: transformKey === "" ? null : transformKey,
                            position: position,
                            off: offSwitch.checked,
                            "variable-refresh-rate": vrrKey
                        },
                        primary: root.primaryDraft !== "",
                        primaryName: root.primaryDraft
                    }
                })
            }

            Component.onCompleted: pull()

            Row {
                width: parent.width
                spacing: 8
                Label {
                    text: card.modelData.name || "Экран"
                    font.family: root.tokens.type.display.family
                    font.pixelSize: root.tokens.type.display.size
                }
                Rectangle {
                    visible: card.modelData.name === root.effectivePrimary()
                    radius: 9
                    height: 22
                    width: primaryText.implicitWidth + 16
                    color: Qt.alpha(root.tokens.color.accent, 0.22)
                    y: 2
                    Text {
                        id: primaryText
                        anchors.centerIn: parent
                        text: "Основной"
                        color: root.tokens.color.accent
                        font.family: root.tokens.type.small.family
                        font.pixelSize: 12
                        textFormat: Text.PlainText
                    }
                }
            }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: card.subtitleText()
            }
            Label {
                width: parent.width
                visible: card.locked
                color: root.tokens.color.secondary
                font.pixelSize: 13
                text: card.modelData.config && card.modelData.config.lockedReason ? card.modelData.config.lockedReason : "Этот блок Nayori не меняет"
            }
            Choice {
                title: "Разрешение"
                visible: card.modesKnown
                enabled: !card.locked && service.validateAvailable
                options: card.sizeOptions()
                current: card.sizeKey
                onPicked: key => {
                    root.editing = true
                    card.sizeKey = key
                    card.refreshKey = key === "" ? "" : card.pickRefresh(key, card.refreshKey)
                }
            }
            Choice {
                title: "Частота"
                visible: card.modesKnown
                enabled: !card.locked && service.validateAvailable && card.sizeKey !== ""
                options: card.refreshOptions()
                current: card.sizeKey === "" ? "" : card.refreshKey
                onPicked: key => { root.editing = true; card.refreshKey = key }
            }
            Item {
                visible: !card.modesKnown
                width: parent.width
                implicitHeight: visible ? 38 : 0
                Label {
                    anchors.left: parent.left
                    anchors.right: sizeField.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 12
                    text: "Разрешение"
                    elide: Text.ElideRight
                    lineHeight: 1
                    verticalAlignment: Text.AlignVCenter
                }
                SettingsField {
                    id: sizeField
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190
                    height: 38
                    tokens: root.tokens
                    enabled: !card.locked && service.validateAvailable
                    placeholderText: "1920x1080"
                    onTextEdited: root.editing = true
                }
            }
            Item {
                visible: !card.modesKnown
                width: parent.width
                implicitHeight: visible ? 38 : 0
                Label {
                    anchors.left: parent.left
                    anchors.right: refreshField.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 12
                    text: "Частота"
                    elide: Text.ElideRight
                    lineHeight: 1
                    verticalAlignment: Text.AlignVCenter
                }
                SettingsField {
                    id: refreshField
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 190
                    height: 38
                    tokens: root.tokens
                    enabled: !card.locked && service.validateAvailable
                    placeholderText: "60"
                    onTextEdited: root.editing = true
                }
            }
            Choice {
                title: "Масштаб"
                enabled: !card.locked && service.validateAvailable
                options: root.scaleOptions(card.scaleKey)
                current: card.scaleKey
                onPicked: key => { root.editing = true; card.scaleKey = key }
            }
            Choice {
                title: "Поворот"
                enabled: !card.locked && service.validateAvailable
                options: card.transforms
                current: card.transformKey
                onPicked: key => { root.editing = true; card.transformKey = key }
            }
            Item {
                id: positionRow
                width: parent.width
                implicitHeight: 38
                Label {
                    anchors.left: parent.left
                    anchors.right: positionFields.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 12
                    text: "Положение"
                    elide: Text.ElideRight
                    lineHeight: 1
                    verticalAlignment: Text.AlignVCenter
                }
                Row {
                    id: positionFields
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    component Value: Rectangle {
                        id: box
                        property string value: ""
                        width: 108
                        height: 38
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.width: 1
                        border.color: root.tokens.color.border
                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: box.value
                            color: root.tokens.color.text
                            font.family: root.tokens.type.body.family
                            font.pixelSize: root.tokens.type.small.size
                            font.weight: root.tokens.type.body.weight
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                    }
                    Value {
                        value: "X: " + (root.positionOf(card.modelData.name) ? root.positionOf(card.modelData.name).x : "—")
                    }
                    Value {
                        value: "Y: " + (root.positionOf(card.modelData.name) ? root.positionOf(card.modelData.name).y : "—")
                    }
                }
            }
            Choice {
                title: "Переменная частота"
                enabled: !card.locked && service.validateAvailable
                options: card.vrrOptions
                current: card.vrrKey
                onPicked: key => { root.editing = true; card.vrrKey = key }
            }
            Label {
                width: parent.width
                visible: !!(card.modelData.live && card.modelData.live.vrrSupported === false)
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: "Монитор не сообщил о поддержке переменной частоты"
            }
            SettingsSwitch {
                id: offSwitch
                enabled: !card.locked && service.validateAvailable
                tokens: root.tokens
                text: "Отключение вывода"
                description: "В блоке появляется строка off, и монитор гаснет"
                onClicked: root.editing = true
            }
            Label {
                width: parent.width
                visible: !!(card.modelData.config && card.modelData.config.extra && card.modelData.config.extra.length)
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                text: "В блоке ещё есть строки, Nayori их не меняет: " + ((card.modelData.config && card.modelData.config.extra) ? card.modelData.config.extra.join(", ") : "")
            }
            Label {
                width: parent.width
                visible: card.cardError !== ""
                color: root.tokens.color.secondary
                font.pixelSize: 13
                text: card.cardError
            }
            SettingsButton {
                text: "Применить"
                primary: true
                tokens: root.tokens
                enabled: !card.locked && service.ready && service.validateAvailable && !service.busy && card.modelData.name
                onClicked: card.applyCard()
            }
        }
    }

}
