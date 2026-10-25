pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
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
    SettingsToggle {
        tokens: root.tokens
        text: "Смена страниц острова"
        description: "Остров сам переключает страницы через заданный интервал"
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
        palette.highlightedText: root.tokens.color.background
        Accessible.name: "Интервал смены страниц острова в секундах"
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
