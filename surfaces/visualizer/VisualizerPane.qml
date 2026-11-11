pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "vendor"
import "../settings"
import "../../services/visualizer/VisualizerConfig.js" as Config
import "../../services/visualizer/VisualizerParameters.js" as Parameters

Flickable {
    id: root
    required property var tokens
    required property var service
    required property string output
    property real aspect: 16 / 9
    property var sourceAudio: null
    property color paletteAccent: tokens.color.accent
    property string tab: "Look"
    property real tabOpacity: 1
    onTabChanged: {
        if (tokens.motion.off) tabOpacity = 1
        else tabFade.restart()
    }
    NumberAnimation {
        id: tabFade
        target: root
        property: "tabOpacity"
        from: 0.55; to: 1
        duration: root.tokens.motion.fast
        easing.type: Easing.OutCubic
    }
    signal escapeRequested()
    Keys.onEscapePressed: event => { escapeRequested(); event.accepted = true }
    readonly property var item: service && service.selected && service.selected.output === output ? service.selected : null
    readonly property string parameterRoster: JSON.stringify(item ? Parameters.forTab(tab, item) : [])
    readonly property var parameterModel: JSON.parse(parameterRoster)
    readonly property bool fullFrame: item && (item.style === "aura" || item.style === "frame")
    function edit(key, value) {
        if (!item) return
        const change = {}
        if (item.style === "aura" && ["color", "auraColor2", "auraColor3"].indexOf(key) >= 0) {
            change.color = item.color || hex(paletteAccent)
            change.auraColor2 = item.auraColor2 || hex(tokens.color.text)
            change.auraColor3 = item.auraColor3 || hex(tokens.color.secondary)
        }
        change[key] = value
        service.patch(item.id, change)
    }
    function hex(color) { return "#" + [color.r,color.g,color.b].map(v => Math.round(v*255).toString(16).padStart(2,"0")).join("") }
    onItemChanged: if ((!item || item.style !== "aura") && tab === "Field") tab = "Look"
    Component.onCompleted: {
        const list = service.onOutput(output)
        if (!item && list.length) service.select(list[0].id)
    }
    clip: true
    contentWidth: width
    contentHeight: content.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    Column {
        id: content
        opacity: root.tokens.motion.off ? 1 : root.tabOpacity
        width: root.width
        spacing: 12
        SettingsLabel { tokens: root.tokens; text: "Визуализаторы"; font.pixelSize: 20 }
        SettingsLabel { tokens: root.tokens; width: parent.width; text: "Выберите стиль. На рабочем столе перетащите рамку, угол или маркер вращения." }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.service.onOutput(root.output)
                delegate: SettingsButton {
                    required property var modelData
                    required property int index
                    tokens: root.tokens
                    text: String(index + 1) + (modelData.enabled ? "" : " · скрыт")
                    primary: root.service.selectedId === modelData.id
                    onClicked: root.service.select(modelData.id)
                }
            }
            SettingsButton { tokens: root.tokens; text: "Добавить"; onClicked: root.service.add(root.output) }
        }
        SettingsSwitch {
            visible: !!root.item
            tokens: root.tokens; text: "Показывать"
            checked: root.item ? root.item.enabled : false
            onToggled: root.edit("enabled", checked)
        }
        SettingsButton { visible: !!root.item; tokens: root.tokens; text: "Удалить экземпляр"; onClicked: root.service.remove(root.item.id) }
        SettingsLabel {
            visible: !!root.item && (!root.sourceAudio || !root.sourceAudio.available)
            width: parent.width; tokens: root.tokens
            text: root.tokens.motion.off ? "Анимации отключены в настройках Nayori" : "Ожидание звука. Для захвата нужны cava, parec и PipeWire Pulse."
        }
        Flow {
            visible: !!root.item
            width: parent.width; spacing: 4
            Repeater {
                model: root.item && root.item.style === "aura" ? ["Look", "Place", "Colour", "Motion", "Field"] : ["Look", "Place", "Colour", "Motion", "Shape"]
                delegate: SettingsButton {
                    required property string modelData
                    tokens: root.tokens; text: modelData; primary: root.tab === modelData
                    onClicked: root.tab = modelData
                }
            }
        }
        Grid {
            visible: !!root.item && root.tab === "Look"
            width: parent.width
            columns: 2; spacing: 6
            Repeater {
                model: Config.choices.style
                delegate: Button {
                    id: tile
                    required property string modelData
                    width: (content.width - 6) / 2; height: 92
                    Accessible.name: modelData
                    onClicked: root.edit("style", modelData)
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: tile.hovered ? root.tokens.color.surface : root.tokens.color.background
                        border.color: root.item && root.item.style === tile.modelData ? root.tokens.color.accent : root.tokens.color.border
                        border.width: root.item && root.item.style === tile.modelData ? 2 : 1
                    }
                    contentItem: Item {
                        SpectrumField {
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: caption.top; margins: 8 }
                            visible: tile.modelData !== "aura"
                            style: tile.modelData
                            levels: Array.from({length: 32}, (_, i) => tile.modelData === "line" ? 0.5 + 0.3 * Math.sin(i * 0.5) : 0.18 + 0.6 * Math.abs(Math.sin(i * 0.7)))
                            energy: 0.6; boxX: 0; boxY: 0; boxW: 1; boxH: 1
                            ramp: [root.paletteAccent, root.tokens.color.text]
                        }
                        AuraField {
                            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: caption.top; margins: 8 }
                            visible: tile.modelData === "aura"
                            depth: 20; bands: [0.3,0.5,0.7,0.4,0.6,0.8,0.3,0.6,0.4,0.7,0.5,0.4]
                            energy: 0.6; phase: 0.3
                            primaryColor: root.paletteAccent; secondaryColor: root.tokens.color.text; tertiaryColor: root.tokens.color.secondary
                        }
                        SettingsLabel { id: caption; anchors { left: parent.left; bottom: parent.bottom; margins: 6 } tokens: root.tokens; text: tile.modelData }
                    }
                }
            }
        }
        Column {
            visible: !!root.item && root.tab === "Place"
            width: parent.width; spacing: 8
            SettingsLabel { visible: root.fullFrame; tokens: root.tokens; width: parent.width; text: "Этот стиль следует краям экрана. Размещение задаётся выбранным монитором." }
            Repeater {
                model: root.fullFrame ? [] : [{key:"w",label:"Ширина"},{key:"h",label:"Высота"},{key:"across",label:"По горизонтали"},{key:"down",label:"По вертикали"},{key:"angle",label:"Поворот"}]
                delegate: Column {
                    id: placeRow
                    required property var modelData
                    width: parent.width
                    SettingsLabel {
                        tokens: root.tokens
                        text: placeRow.modelData.label + "  " + Math.round(placeSlider.source * (placeRow.modelData.key === "angle" ? 1 : 100)) + (placeRow.modelData.key === "angle" ? "°" : "%")
                    }
                    SettingsSlider {
                        id: placeSlider
                        tokens: root.tokens; width: parent.width; label: placeRow.modelData.label
                        from: ["w","h"].indexOf(placeRow.modelData.key) >= 0 ? 0.05 : 0
                        to: placeRow.modelData.key === "angle" ? 360 : 1
                        source: !root.item ? 0 : placeRow.modelData.key === "across" ? root.item.x + root.item.w / 2 : placeRow.modelData.key === "down" ? root.item.y + root.item.h / 2 : root.item[placeRow.modelData.key]
                        onChanged: value => {
                            if (!root.item) return
                            if (placeRow.modelData.key === "across") root.edit("x", value - root.item.w / 2)
                            else if (placeRow.modelData.key === "down") root.edit("y", value - root.item.h / 2)
                            else if (placeRow.modelData.key === "w" || placeRow.modelData.key === "h") {
                                const k = placeRow.modelData.key, pos = k === "w" ? "x" : "y", changes = {}
                                changes[k] = value; changes[pos] = root.item[pos] + (root.item[k] - value) / 2
                                root.service.patch(root.item.id, changes)
                            } else root.edit(placeRow.modelData.key, value)
                        }
                    }
                }
            }
            Flow {
                visible: !root.fullFrame
                width: parent.width; spacing: 4
                Repeater {
                    model: ["По центру", "Без поворота", "Во всю ширину", "Сверху", "Посередине", "Снизу"]
                    delegate: SettingsButton {
                        required property string modelData
                        required property int index
                        tokens: root.tokens; text: modelData
                        onClicked: {
                            const v = root.item
                            if (index === 0) root.service.patch(v.id, {x: 0.5-v.w/2, y: 0.5-v.h/2})
                            else if (index === 1) root.edit("angle", 0)
                            else if (index === 2) root.service.patch(v.id, {w: 1, x: 0})
                            else root.edit("y", index === 3 ? 0 : index === 4 ? 0.5-v.h/2 : 1-v.h)
                        }
                    }
                }
            }
            SettingsLabel { tokens: root.tokens; text: "Монитор" }
            Flow {
                width: parent.width; spacing: 4
                Repeater {
                    model: Quickshell.screens
                    delegate: SettingsButton {
                        required property var modelData
                        tokens: root.tokens; text: modelData.name
                        primary: root.item && root.item.output === modelData.name
                        onClicked: root.edit("output", modelData.name)
                    }
                }
            }
        }
        Column {
            visible: !!root.item && root.tab === "Colour"
            width: parent.width; spacing: 8
            SettingsSwitch {
                visible: root.item && root.item.style !== "aura"
                tokens: root.tokens; text: "Градиент"
                checked: root.item ? root.item.gradient : false
                onToggled: {
                    const changes = {gradient: checked}
                    if (checked) { changes.color = root.item.color || root.hex(root.paletteAccent); changes.color2 = root.item.color2 || root.hex(root.tokens.color.text) }
                    root.service.patch(root.item.id, changes)
                }
            }
            SettingsButton { tokens: root.tokens; text: "Цвета из обоев"; onClicked: root.service.patch(root.item.id, {color:"",color2:"",auraColor2:"",auraColor3:"",gradient:false}) }
            Repeater {
                model: root.item && root.item.style === "aura" ? ["color","auraColor2","auraColor3"] : ["color","color2"]
                delegate: Column {
                    id: colorRow
                    required property string modelData
                    required property int index
                    width: parent.width; spacing: 4
                    SettingsLabel { tokens: root.tokens; text: colorRow.index === 0 ? "Основной цвет" : colorRow.index === 1 ? "Второй цвет" : "Третий цвет" }
                    Row {
                        spacing: 6
                        Rectangle { width: 32; height: 32; radius: 6; color: root.item && root.item[colorRow.modelData] || root.paletteAccent }
                        SettingsField {
                            tokens: root.tokens; width: Math.max(80, content.width - 42)
                            text: root.item ? root.item[colorRow.modelData] : ""
                            placeholderText: "#RRGGBB"
                            validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                            onEditingFinished: if (acceptableInput) root.edit(colorRow.modelData, text)
                        }
                    }
                    Flow {
                        width: parent.width; spacing: 4
                        Repeater {
                            model: [root.paletteAccent,root.tokens.color.text,root.tokens.color.secondary,root.tokens.color.background]
                            delegate: Button {
                                required property color modelData
                                width: 36; height: 32
                                Accessible.name: root.hex(modelData)
                                background: Rectangle { radius: 6; color: parent.modelData; border.color: root.tokens.color.border }
                                onClicked: root.edit(colorRow.modelData, root.hex(modelData))
                            }
                        }
                    }
                }
            }
        }
        Column {
            visible: !!root.item && root.tab === "Motion"
            width: parent.width; spacing: 8
            SettingsLabel { tokens: root.tokens; text: "Общая частота кадров" }
            Flow {
                spacing: 4
                Repeater {
                    model: [30,45,60]
                    delegate: SettingsButton {
                        required property int modelData
                        tokens: root.tokens; text: String(modelData)
                        primary: root.service.config.fps === modelData
                        onClicked: root.service.budget("fps", modelData)
                    }
                }
            }
            SettingsSwitch {
                tokens: root.tokens; text: "Снижать FPS под нагрузкой"
                checked: root.service.config.adaptive
                onToggled: root.service.budget("adaptive", checked)
            }
            SettingsButton { visible: !root.fullFrame; tokens: root.tokens; text: "Сбросить наклон"; onClicked: root.service.patch(root.item.id, {tiltX:0,tiltY:0}) }
        }
        Flow {
            visible: !!root.item && root.tab === "Field"
            width: parent.width; spacing: 4
            Repeater {
                model: ["top","right","bottom","left"]
                delegate: SettingsButton {
                    required property string modelData
                    tokens: root.tokens; text: modelData
                    primary: root.item && root.item.auraEdges.indexOf(modelData) >= 0
                    onClicked: {
                        const edges = root.item.auraEdges.slice(), i = edges.indexOf(modelData)
                        if (i < 0) edges.push(modelData); else edges.splice(i,1)
                        root.edit("auraEdges", edges)
                    }
                }
            }
        }
        Repeater {
            model: root.parameterModel
            delegate: VisualizerParameter {
                required property var modelData
                width: content.width
                tokens: root.tokens; spec: modelData; item: root.item || Config.defaults
                onEdited: (key, value) => root.edit(key, value)
            }
        }
        SettingsButton { visible: !!root.item && (root.tab === "Shape" || root.tab === "Field"); tokens: root.tokens; text: "Развернуть направление"; onClicked: root.service.flip(root.item.id) }
    }
}
