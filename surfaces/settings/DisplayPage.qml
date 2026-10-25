pragma ComponentBehavior: Bound

import QtQuick
import "../../services/system"

Column {
    id: root
    required property var tokens
    spacing: 16
    component Label: SettingsLabel { tokens: root.tokens }

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

    DisplayList { id: displays }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Nayori не меняет режимы вывода niri. Разрешение, частоту и положение задаёт конфигурация композитора. Файл не записывается: безопасная перезапись с откатом не сделана"
    
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: !displays.screens || displays.screens.length === 0
        text: "Подключённых экранов нет"
    
    }
    Repeater {
        model: displays.screens
        delegate: Column {
            required property var modelData
            width: parent.width
            spacing: 4
            Label {
                width: parent.width
                text: modelData.name || "Экран"
                font.family: root.tokens.type.display.family
                font.pixelSize: 18
            }
            Label {
                width: parent.width
                color: root.tokens.color.textMuted
                font.pixelSize: 13
                 text: root.screenText(modelData) 
            }
        }
    }
}
