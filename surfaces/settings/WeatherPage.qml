pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    property bool showHeading: true
    required property var tokens
    property string weatherCity: ""
    property int weatherRefreshMinutes: 15
    signal revealRequested(var item)
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    id: root
            spacing: 16
            Label { visible: root.showHeading; text: "Погода"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }
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
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    color: root.tokens.color.text
                    placeholderTextColor: root.tokens.color.textMuted
                    selectionColor: root.tokens.color.accent
                    selectedTextColor: root.tokens.color.accentText
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.settings.body
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
                objectName: "weatherApplyButton"
                onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                text: "Применить"
                selected: true
                onClicked: {
                    const city = weatherCityInput.text.trim()
                    root.weatherCityChangedRequested(city)
                }
            }
            Column {
                width: parent.width
                spacing: 8
                Label { text: "Интервал обновления, мин" }
                SpinBox {
                    objectName: "weatherRefreshMinutesInput"
                    from: 1
                    to: 180
                    value: root.weatherRefreshMinutes
                    editable: true
                    implicitHeight: root.tokens.settings.control
                    onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
                    palette.text: root.tokens.color.text
                    palette.buttonText: root.tokens.color.text
                    palette.base: root.tokens.color.surfaceAlt
                    palette.button: root.tokens.color.surfaceAlt
                    palette.highlight: root.tokens.color.accent
                    palette.highlightedText: root.tokens.color.accentText
                    Accessible.name: "Интервал обновления погоды в минутах"
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.settings.body
                    onValueModified: root.weatherRefreshMinutesChangedRequested(value)
                }
                Label {
                    width: parent.width
                    text: "Погода обновляется в фоне, даже когда остров закрыт."
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                }
            }
        }
