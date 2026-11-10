pragma ComponentBehavior: Bound
import QtQuick
import "../../services/system"

Column {
    id: root
    objectName: "cursorControls"
    required property var tokens
    signal revealRequested(var item)
    property string draftTheme: ""
    property int draftSize: 24
    readonly property var selectedTheme: service.themes.find(item => item.key === root.draftTheme)
    readonly property var preview: {
        const frames = selectedTheme ? selectedTheme.previews || [] : []
        let best = null
        for (const frame of frames)
            if (!best || Math.abs(frame.size - draftSize) < Math.abs(best.size - draftSize)) best = frame
        return best
    }
    spacing: root.tokens.spacing.small
    CursorTheme {
        id: service
        onThemeChanged: root.draftTheme = theme
        onSizeChanged: root.draftSize = size
        onReadyChanged: if (ready) { root.draftTheme = theme; root.draftSize = size }
    }
    SettingsLabel { tokens: root.tokens; text: "Курсор"; font.pixelSize: root.tokens.type.display.size }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        text: "Одна тема для Niri, GTK, Qt и X11. Изменения применяются кнопкой ниже. Некоторые приложения обновят курсор после перезапуска."
        color: root.tokens.color.textMuted
    }
    SettingsSelect {
        objectName: "cursorThemeSelector"
        tokens: root.tokens
        width: Math.min(320, root.width)
        model: service.themes
        currentKey: root.draftTheme
        enabled: service.ready && !service.busy && model.length > 0
        Accessible.name: "Тема курсора"
        onActivated: key => root.draftTheme = key
        onFocusReceived: root.revealRequested(this)
    }
    SettingsLabel { tokens: root.tokens; text: "Размер · " + root.draftSize + " px" }
    SettingsSelect {
        objectName: "cursorSizeSelector"
        tokens: root.tokens
        model: {
            const sizes = [16, 24, 32, 36, 48, 64, 96, 128]
            if (sizes.indexOf(root.draftSize) < 0) sizes.push(root.draftSize)
            return sizes.sort((a, b) => a - b).map(size => ({key: String(size), label: size + " px"}))
        }
        currentKey: String(root.draftSize)
        enabled: service.ready && !service.busy
        Accessible.name: "Размер курсора"
        onActivated: key => root.draftSize = Number(key)
        onFocusReceived: root.revealRequested(this)
    }
    Rectangle {
        objectName: "cursorPreviewCard"
        width: parent.width
        implicitHeight: root.tokens.settings.control * 4
        radius: root.tokens.radius.small
        color: root.tokens.color.surfaceAlt
        border.width: 1
        border.color: root.tokens.color.border
        Image {
            objectName: "cursorPreviewImage"
            anchors.centerIn: parent
            width: root.preview ? root.draftSize * implicitWidth / root.preview.size : 0
            height: root.preview ? root.draftSize * implicitHeight / root.preview.size : 0
            source: root.preview ? root.preview.source : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: root.preview !== null
            Accessible.name: "Превью курсора " + root.draftTheme + ", " + root.draftSize + " px"
        }
        SettingsLabel {
            anchors.centerIn: parent
            tokens: root.tokens
            visible: !root.preview
            text: "Превью недоступно"
            color: root.tokens.color.textMuted
        }
    }
    Row {
        spacing: root.tokens.spacing.small
        SettingsButton {
            objectName: "cursorApply"
            tokens: root.tokens
            text: service.busy ? "Применение…" : "Применить курсор"
            primary: true
            enabled: service.ready && !service.busy && service.themes.some(item => item.key === root.draftTheme)
            onClicked: service.apply(root.draftTheme, root.draftSize)
            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        }
        SettingsButton {
            objectName: "cursorCancel"
            tokens: root.tokens
            text: "Отмена"
            enabled: service.ready && !service.busy
            onClicked: { root.draftTheme = service.theme; root.draftSize = service.size }
            onActiveFocusChanged: if (activeFocus) root.revealRequested(this)
        }
    }
    SettingsLabel {
        tokens: root.tokens
        width: parent.width
        visible: service.message !== "" || (service.ready && service.themes.length === 0)
        text: service.message || "Темы курсора не найдены. Установите тему Xcursor и откройте настройки снова."
        color: root.tokens.color.textMuted
    }
}
