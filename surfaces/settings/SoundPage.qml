pragma ComponentBehavior: Bound

import QtQuick
import "../../services/status"
import "../../services/status/MixerSources.js" as MixerSources
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }

    Audio { id: audio }
    AudioDevices { id: devices }
    property var mixerSources: []
    property bool mixerListOpen: false
    signal mixerSourcesChangedRequested(var sources)

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: devices.outputCount > 0 || devices.inputCount > 0
              ? "Меняются громкость, беззвучный режим и устройство по умолчанию. Маршруты PipeWire и отдельные каналы здесь не настраиваются"
              : "Список устройств PipeWire недоступен. Ниже только текущий вывод, если PipeWire его уже отдал"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: !devices.ready && !audio.available
        text: "PipeWire не отвечает. Громкость изменить нельзя"
    
    }

    Label {
        visible: devices.outputCount === 0 && audio.available
        text: "Текущий вывод"
        font.family: root.tokens.type.display.family
        font.pixelSize: 18
    }
    SettingsSlider {
        visible: devices.outputCount === 0 && audio.available
        width: parent.width
        tokens: root.tokens
        source: audio.level
        label: "Громкость вывода"
        onChanged: value => audio.setVolume(value)
    }
    SettingsToggle {
        visible: devices.outputCount === 0 && audio.available
        tokens: root.tokens
        text: "Без звука"
        checked: audio.muted
        onClicked: {
            if (audio.muted !== checked)
                audio.toggleMuted()
        }
    }

    Label {
        visible: devices.outputCount > 0
        text: "Вывод"
        font.family: root.tokens.type.display.family
        font.pixelSize: 18
    }
    Repeater {
        model: devices.outputCount > 0 ? devices.nodes : null
        delegate: Column {
            id: outputRow
            required property var modelData
            readonly property bool shown: devices.isOutput(modelData)
            visible: shown
            width: parent.width
            spacing: 8
            Label { width: parent.width; text: modelData.description || modelData.name || "Вывод" }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 visible: devices.defaultSink === modelData; text: "Устройство по умолчанию" 
            }
            SettingsSlider {
                width: parent.width
                tokens: root.tokens
                source: modelData.audio ? modelData.audio.volume : 0
                label: "Громкость " + (modelData.description || modelData.name || "")
                onChanged: value => devices.setVolume(outputRow.modelData, value)
            }
            SettingsToggle {
                tokens: root.tokens
                text: "Без звука"
                checked: modelData.audio ? modelData.audio.muted : false
                onClicked: devices.setMuted(outputRow.modelData, checked)
            }
            Action {
                visible: devices.defaultSink !== outputRow.modelData
                text: "Сделать устройством по умолчанию"
                onClicked: devices.preferSink(outputRow.modelData)
            }
        }
    }

    Label {
        visible: devices.inputCount > 0
        text: "Ввод"
        font.family: root.tokens.type.display.family
        font.pixelSize: 18
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: devices.ready && devices.inputCount === 0
        text: "Отдельных устройств ввода с регулятором громкости PipeWire не показал"
    
    }
    Repeater {
        model: devices.inputCount > 0 ? devices.nodes : null
        delegate: Column {
            id: inputRow
            required property var modelData
            readonly property bool shown: devices.isInput(modelData)
            visible: shown
            width: parent.width
            spacing: 8
            Label { width: parent.width; text: modelData.description || modelData.name || "Ввод" }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 visible: devices.defaultSource === modelData; text: "Устройство по умолчанию" 
            }
            SettingsSlider {
                width: parent.width
                tokens: root.tokens
                source: modelData.audio ? modelData.audio.volume : 0
                label: "Громкость " + (modelData.description || modelData.name || "")
                onChanged: value => devices.setVolume(inputRow.modelData, value)
            }
            SettingsToggle {
                tokens: root.tokens
                text: "Без звука"
                checked: modelData.audio ? modelData.audio.muted : false
                onClicked: devices.setMuted(inputRow.modelData, checked)
            }
            Action {
                visible: devices.defaultSource !== inputRow.modelData
                text: "Сделать устройством по умолчанию"
                onClicked: devices.preferSource(inputRow.modelData)
            }
        }
    }

    Action {
        width: parent.width
        text: "Источники микшера"
        detail: MixerSources.summary(root.mixerSources)
        glyph: "sound"
        selected: root.mixerListOpen
        onClicked: root.mixerListOpen = !root.mixerListOpen
    }
    Label {
        width: parent.width
        visible: root.mixerListOpen
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        wrapMode: Text.Wrap
        text: "Галочка оставляет источник в микшере панели. Новый источник добавляется, когда приложение начинает воспроизведение."
    }
    Repeater {
        model: root.mixerListOpen ? root.mixerSources : []
        delegate: SettingsToggle {
            required property var modelData
            tokens: root.tokens
            text: modelData.title || modelData.key
            checked: modelData.hidden !== true
            onToggled: root.mixerSourcesChangedRequested(MixerSources.setHidden(root.mixerSources, modelData.key, !checked))
        }
    }
}
