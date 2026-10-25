pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    required property var tokens
    property string weatherCity: ""
    signal weatherCityChangedRequested(string city)
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 16
            Label { text: "Погода"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
            Column {
                width: parent.width
                spacing: 8
                Label { text: "Город" }
                TextField {
                    id: weatherCityInput
                    objectName: "weatherCityInput"
                    width: parent.width
                    height: 44
                    text: root.weatherCity
                    placeholderText: "Например, Москва"
                    Accessible.name: "Город для прогноза погоды"
                    selectByMouse: true
                    color: root.tokens.color.text
                    placeholderTextColor: root.tokens.color.textMuted
                    selectionColor: root.tokens.color.accent
                    selectedTextColor: root.tokens.color.background
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    leftPadding: 12
                    rightPadding: 12
                    background: Rectangle {
                        radius: root.tokens.radius.small
                        color: root.tokens.color.surfaceAlt
                        border.width: 1
                        border.color: weatherCityInput.activeFocus ? root.tokens.color.accent : root.tokens.color.border
                    }
                }
            }
            Label {
                width: parent.width
                text: "Погода загружается с wttr.in для выбранного города."
                color: root.tokens.color.textMuted
                font.pixelSize: 13
            }
            Action {
                text: "Применить"
                selected: true
                onClicked: {
                    const city = weatherCityInput.text.trim()
                    root.weatherCityChangedRequested(city)
                }
            }
        }
