pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
    property string islandPlacement: "floating"
    signal islandPlacementChangedRequested(string placement)
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property string weatherCity: ""
    property int weatherRefreshMinutes: 15
    signal islandRotationEnabledChangedRequested(bool enabled)
    signal islandRotationSecondsChangedRequested(int seconds)
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }

    function reveal(item) {
        let node = parent
        while (node) {
            if (node.reveal) {
                node.reveal(item)
                return
            }
            node = node.parent
        }
    }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Остров и кнопка «Пуск» читают эти значения из настроек Nayori" 
    }
    Label { text: "Расположение острова" }
    SettingsSegmented {
        objectName: "islandPlacementSelector"
        tokens: root.tokens
        width: Math.min(parent.width, 360)
        equalWidth: true
        model: [{key: "floating", label: "Floating — плавающий"}, {key: "attached", label: "Attached — у края"}]
        currentKey: root.islandPlacement
        onActivated: key => root.islandPlacementChangedRequested(key)
        onFocusReceived: root.reveal(this)
    }
    Label {
        width: parent.width
        font.pixelSize: 13
        color: root.tokens.color.textMuted
        text: root.islandPlacement === "attached"
            ? "Остров и боковые капсулы соединяются с верхним краем экрана. Остров раскрывается вниз"
            : "Капсулы со скруглёнными углами располагаются с отступом от верхнего края экрана"
    }
    SettingsToggle {
        objectName: "islandRotationToggle"
        tokens: root.tokens
        text: "Чередовать часы и погоду"
        description: root.islandRotationEnabled
            ? "Чередуются часы и погода, если город задан и ответ пришёл без ошибки. Музыка, громкость, уведомление, лаунчер и раскрытый остров останавливают чередование"
            : "На острове остаются часы. Погода не сменяет их сама"
        checked: root.islandRotationEnabled
        onClicked: root.islandRotationEnabledChangedRequested(checked)
    }
    Label { text: "Интервал, сек" }
    SpinBox {
        objectName: "islandRotationSecondsInput"
        from: 5
        to: 120
        value: root.islandRotationSeconds
        editable: true
        implicitHeight: root.tokens.settings.control
        palette.text: root.tokens.color.text
        palette.buttonText: root.tokens.color.text
        palette.base: root.tokens.color.surfaceAlt
        palette.button: root.tokens.color.surfaceAlt
        palette.highlight: root.tokens.color.accent
        palette.highlightedText: root.tokens.color.accentText
        Accessible.name: "Интервал чередования часов и погоды, секунды"
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.settings.body
        onValueModified: root.islandRotationSecondsChangedRequested(value)
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
         text: "Допустимы значения от 5 до 120 секунд" 
    }
    Label { text: "Погода"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    WeatherPage {
        width: parent.width
        tokens: root.tokens
        showHeading: false
        weatherCity: root.weatherCity
        weatherRefreshMinutes: root.weatherRefreshMinutes
        onRevealRequested: item => root.reveal(item)
        onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
        onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
    }
}
