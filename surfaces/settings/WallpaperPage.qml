pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Quickshell
import "../canvas"

ScrollView {
    id: root
    required property var tokens
    required property var manager
    property string output: Quickshell.screens.length ? Quickshell.screens[0].name : ""
    property url draftSource: ""
    property string draftMode: "fill"
    property bool draftShared: true
    property bool draftEnabled: true
    readonly property var selectedScreen: {
        for (const screen of Quickshell.screens) if (screen.name === output) return screen
        return null
    }
    clip: true
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    function load() {
        if (!manager) return
        const value = manager.wallpaper(output)
        draftSource = value.source
        draftMode = value.mode
        draftShared = manager.state.shared
        draftEnabled = manager.state.enabled
    }
    Component.onCompleted: load()
    onOutputChanged: load()
    Connections {
        target: root.manager
        function onReadyChanged() { root.load() }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.selectedScreen)
                root.output = Quickshell.screens.length ? Quickshell.screens[0].name : ""
        }
    }
    component Caption: Text {
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
    }
    component Action: Button {
        id: button
        focusPolicy: Qt.StrongFocus
        implicitHeight: 36
        contentItem: Caption { text: button.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle {
            radius: root.tokens.radius.small
            color: button.down || button.hovered ? root.tokens.color.surface : root.tokens.color.surfaceAlt
            border.width: button.visualFocus ? 1 : 0
            border.color: root.tokens.color.accent
            opacity: button.enabled ? 1 : 0.5
        }
    }
    FileDialog {
        id: picker
        title: "Выбрать обои"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Изображения (*.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP)"]
        onAccepted: root.draftSource = selectedFile
    }
    Column {
        width: root.availableWidth - 12
        spacing: 10
        Caption { text: "Обои"; font.pixelSize: 20; font.family: root.tokens.type.display.family }
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: Quickshell.screens
                Action {
                    required property var modelData
                    text: (root.output === modelData.name ? "✓ " : "") + modelData.name
                    onClicked: root.output = modelData.name
                }
            }
        }
        StaticRenderer {
            id: preview
            width: Math.min(parent.width, 320)
            height: width * (root.selectedScreen ? root.selectedScreen.height / root.selectedScreen.width : 9 / 16)
            source: root.draftSource
            mode: root.draftMode
            nativeScale: root.selectedScreen ? width / root.selectedScreen.width : 1
            backgroundColor: root.tokens.color.background
            border.width: 1
            border.color: root.tokens.color.border
        }
        Caption {
            width: parent.width
            text: preview.failed ? "Не удалось открыть изображение. Выберите другой файл."
                : String(root.draftSource).split("/").pop()
            elide: Text.ElideMiddle
            wrapMode: Text.NoWrap
            color: root.tokens.color.textMuted
        }
        Action { text: "Выбрать изображение…"; onClicked: picker.open() }
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: [{key: "fill", label: "Заполнить"}, {key: "fit", label: "Вписать"}, {key: "stretch", label: "Растянуть"}, {key: "center", label: "По центру"}]
                Action {
                    required property var modelData
                    text: (root.draftMode === modelData.key ? "✓ " : "") + modelData.label
                    onClicked: root.draftMode = modelData.key
                }
            }
        }
        SettingsToggle {
            width: parent.width
            tokens: root.tokens
            text: "Одинаковые обои на всех мониторах"
            checked: root.draftShared
            onClicked: root.draftShared = checked
        }
        SettingsToggle {
            width: parent.width
            tokens: root.tokens
            text: "Показывать фон Canvas"
            checked: root.draftEnabled
            onClicked: root.draftEnabled = checked
        }
        Flow {
            width: parent.width
            spacing: 4
            Action {
                text: "Применить"
                enabled: root.manager && root.manager.ready && !root.manager.saving
                    && (preview.loaded || !root.draftEnabled) && (root.draftShared || root.selectedScreen !== null)
                onClicked: root.manager.apply(root.output, String(root.draftSource) === String(root.manager.defaultSource) ? "" : root.draftSource,
                    root.draftMode, root.draftShared, root.draftEnabled)
            }
            Action {
                text: "Стандартный фон"
                onClicked: { root.draftSource = root.manager.defaultSource; root.draftMode = "fill" }
            }
        }
        Caption {
            width: parent.width
            text: root.manager ? root.manager.message : ""
            color: root.tokens.color.textMuted
            Accessible.role: Accessible.StaticText
        }
        Caption {
            width: parent.width
            visible: root.manager && Object.keys(root.manager.renderErrors).length > 0
            text: "Файл обоев недоступен на одном из мониторов. Выберите изображение и примените его заново."
            color: root.tokens.color.textMuted
        }
    }
}
