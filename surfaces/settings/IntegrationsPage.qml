pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
    property bool niriColorIntegration: true
    property bool strataThemeIntegration: true
    property string strataError: ""
    property string strataNotice: ""
    property string niriAccentError: ""
    signal niriColorIntegrationChangedRequested(bool enabled)
    signal strataThemeIntegrationChangedRequested(bool enabled)
    spacing: 16

    component Label: SettingsLabel { tokens: root.tokens }

    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        text: "Цвета Nayori уходят в\u00A0niri и в\u00A0тему Strata только когда переключатель включён"
    }
    SettingsToggle {
        objectName: "niriColorIntegration"
        tokens: root.tokens
        text: "Цвета niri"
        description: "Пять цветов акцента в\u00A0nayori-accent.kdl. Файл noctalia.kdl не изменяется"
        checked: root.niriColorIntegration
        onClicked: root.niriColorIntegrationChangedRequested(checked)
    }
    Label {
        objectName: "niriAccentError"
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.niriAccentError !== ""
        text: root.niriAccentError
    }
    SettingsToggle {
        objectName: "strataThemeIntegration"
        tokens: root.tokens
        text: "Тема Strata"
        description: "Фон, поверхности и акцент Nayori в\u00A0файле темы Strata"
        checked: root.strataThemeIntegration
        onClicked: root.strataThemeIntegrationChangedRequested(checked)
    }
    Label {
        width: parent.width
        color: root.tokens.color.textMuted
        font.pixelSize: 13
        visible: root.strataNotice !== "" && root.strataError === ""
        text: root.strataNotice
    }
    Label {
        width: parent.width
        color: root.tokens.color.secondary
        font.pixelSize: 13
        visible: root.strataError !== ""
        text: root.strataError
    }
}
