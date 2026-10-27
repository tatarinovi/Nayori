pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs

Column {
    id: root
    required property var tokens
    property var values: ({})
    property string folderKey: "captureShotDir"
    property string notice: ""
    signal changed(var patch)
    spacing: 16
    function value(key, fallback) { return values[key] === undefined ? fallback : values[key] }
    function set(key, value) { const patch = {}; patch[key] = value; changed(patch) }
    function path(key, text) {
        if (!/^(\/|~\/)/.test(text.trim()) || /[\x00-\x1f]/.test(text)) {
            notice = "Укажите абсолютный путь к папке или путь с ~/."
            return
        }
        notice = ""; set(key, text.trim())
    }
    component Label: SettingsLabel { tokens: root.tokens }
    Label { text: "Файлы"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Repeater {
        model: [{key: "captureShotDir", title: "Папка скриншотов", fallback: "~/Pictures/Screenshots"},
                {key: "captureVideoDir", title: "Папка скринкастов", fallback: "~/Videos/Screencasts"}]
        Column {
            id: pathRow
            required property var modelData
            width: parent.width
            spacing: 8
            Label { text: pathRow.modelData.title }
            Row {
                width: parent.width; spacing: 8
                SettingsField {
                    id: pathField
                    width: Math.max(160, parent.width - browse.width - parent.spacing)
                    tokens: root.tokens
                    text: root.value(pathRow.modelData.key, pathRow.modelData.fallback)
                    Accessible.name: pathRow.modelData.title
                    onEditingFinished: root.path(pathRow.modelData.key, text)
                }
                SettingsButton {
                    id: browse
                    tokens: root.tokens
                    text: "Выбрать…"
                    onClicked: { root.folderKey = pathRow.modelData.key; folder.open() }
                }
            }
        }
    }
    Label { width: parent.width; visible: root.notice !== ""; text: root.notice; color: root.tokens.color.secondary }
    Label { text: "Разметка скриншота"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Row {
        spacing: 12
        Rectangle { width: 38; height: 38; radius: 8; color: root.value("captureColor", "#CAA7AA"); border.width: 1; border.color: root.tokens.color.border }
        SettingsButton { tokens: root.tokens; text: "Цвет по умолчанию…"; onClicked: { colorPicker.selectedColor = root.value("captureColor", "#CAA7AA"); colorPicker.open() } }
    }
    Label { text: "Параметры скринкаста по умолчанию"; font.family: root.tokens.type.display.family; font.pixelSize: 18 }
    Label { text: "Формат" }
    SettingsSegmented {
        tokens: root.tokens
        currentKey: root.value("captureFormat", "mp4")
        model: [{key: "mp4", label: "MP4"}, {key: "webm", label: "WebM"}]
        onActivated: key => root.set("captureFormat", key)
    }
    Label { text: "Частота кадров" }
    SettingsSegmented {
        tokens: root.tokens
        currentKey: String(root.value("captureFps", 30))
        model: [{key: "30", label: "30 fps"}, {key: "60", label: "60 fps"}]
        onActivated: key => root.set("captureFps", Number(key))
    }
    Label { text: "Качество" }
    SettingsSegmented {
        tokens: root.tokens
        currentKey: root.value("captureQuality", "high")
        model: [{key: "high", label: "Стандартное"}, {key: "very_high", label: "Высокое"}]
        onActivated: key => root.set("captureQuality", key)
    }
    Label { text: "Отсчёт перед записью" }
    SettingsSegmented {
        tokens: root.tokens
        currentKey: String(root.value("captureCountdown", 3))
        model: [{key: "0", label: "Без отсчёта"}, {key: "3", label: "3 с"}, {key: "5", label: "5 с"}]
        onActivated: key => root.set("captureCountdown", Number(key))
    }
    SettingsToggle { tokens: root.tokens; text: "Микрофон"; checked: root.value("captureMic", false); onToggled: root.set("captureMic", checked) }
    SettingsToggle { tokens: root.tokens; text: "Звук системы"; checked: root.value("captureSystemAudio", true); onToggled: root.set("captureSystemAudio", checked) }
    SettingsToggle { tokens: root.tokens; text: "Курсор в записи"; checked: root.value("captureCursor", true); onToggled: root.set("captureCursor", checked) }
    Label { width: parent.width; text: "После записи видео сохраняется в папку и копируется в буфер обмена как файл."; color: root.tokens.color.textMuted }
    FolderDialog {
        id: folder
        title: root.folderKey === "captureShotDir" ? "Папка скриншотов" : "Папка скринкастов"
        onAccepted: root.set(root.folderKey, decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, "")))
    }
    ColorDialog {
        id: colorPicker
        title: "Цвет разметки"
        onAccepted: root.set("captureColor", selectedColor.toString())
    }
}
