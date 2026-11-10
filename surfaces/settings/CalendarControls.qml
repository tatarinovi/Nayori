pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Column {
    id: root
    required property var tokens
    property var service: null
    spacing: 8
    SettingsLabel { tokens: root.tokens; text: "Календарь · CalDAV"; font.pixelSize: 18 }
    SettingsField { id: address; tokens: root.tokens; text: root.service ? root.service.url : ""; placeholderText: "HTTPS-адрес CalDAV"; Accessible.name: "Адрес CalDAV" }
    SettingsField { id: login; tokens: root.tokens; text: root.service ? root.service.user : ""; placeholderText: "Логин"; Accessible.name: "Логин CalDAV" }
    SettingsField { id: password; tokens: root.tokens; echoMode: TextInput.Password; placeholderText: "Пароль приложения (сохранится в хранилище паролей)"; Accessible.name: "Пароль приложения CalDAV" }
    SettingsButton {
        tokens: root.tokens
        text: root.service && root.service.busy ? "Подключаем…" : "Подключить / обновить"
        enabled: !!root.service && !root.service.busy && !!address.text.trim() && !!login.text.trim()
        onClicked: { root.service.connect(address.text, login.text, password.text); password.clear() }
    }
    SettingsButton {
        tokens: root.tokens
        text: "Отключить"
        enabled: !!root.service && !root.service.busy && !!root.service.url
        onClicked: root.service.settings.update({calendarUrl: "", calendarUser: ""})
    }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        wrapMode: Text.WordWrap
        text: root.service && root.service.error ? root.service.error : "Просмотр событий. Обновление каждые 15 минут. Пароль хранится в Secret Service."
    }
}
