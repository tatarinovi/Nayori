pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore as Core
import Qt.labs.folderlistmodel
import Quickshell
import "../canvas"

ScrollView {
    id: root
    property bool showHeading: true
    required property var tokens
    required property var manager
    property string output: Quickshell.screens.length ? Quickshell.screens[0].name : ""
    property url draftSource: ""
    property string draftMode: "fill"
    property bool draftShared: true
    property bool draftEnabled: true
    property alias libraryFolder: library.folder
    readonly property int imageCount: images.count
    readonly property var selectedScreen: {
        for (const screen of Quickshell.screens) if (screen.name === output) return screen
        return null
    }
    readonly property string allKey: "*"
    readonly property var monitorModel: {
        const items = [{ key: allKey, label: "Все мониторы" }]
        for (const screen of Quickshell.screens) items.push({ key: screen.name, label: screen.name })
        return items
    }
    // Stretch stays available only while it is the saved mode.
    readonly property var modeModel: {
        const items = [{ key: "fill", label: "Заполнить" }, { key: "fit", label: "Вписать" }]
        if (draftMode === "stretch") items.push({ key: "stretch", label: "Растянуть" })
        items.push({ key: "center", label: "По центру" })
        return items
    }
    readonly property string folderText: {
        let path = decodeURIComponent(String(library.folder).replace(/^file:\/\//, ""))
        const home = Quickshell.env("HOME") || ""
        if (home && (path === home || path.startsWith(home + "/"))) path = "~" + path.slice(home.length)
        return path
    }
    readonly property string countText: {
        const n = images.count
        const last = n % 10
        const word = n % 100 >= 11 && n % 100 <= 14 ? "изображений"
            : last === 1 ? "изображение"
            : last >= 2 && last <= 4 ? "изображения" : "изображений"
        return n + " " + word
    }

    // Normally only the gallery scrolls. The page scrolls only when the window is
    // too short to give the gallery one full row.
    // The host decides the size. Reporting the content size as the implicit one
    // would feed back into availableHeight and loop.
    implicitWidth: 0
    implicitHeight: 0
    clip: true
    contentWidth: availableWidth
    contentHeight: content.height
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    function sharedValue() {
        const value = manager.state.wallpaper
        return { source: value.source || String(manager.defaultSource), mode: value.mode }
    }
    function loadWallpaper() {
        if (!manager) return
        const value = manager.wallpaper(output)
        draftSource = value.source
        draftMode = value.mode
    }
    function load() {
        if (!manager) return
        loadWallpaper()
        draftShared = manager.state.shared
        draftEnabled = manager.state.enabled
    }
    function selectAll() {
        if (!manager) return
        const value = sharedValue()
        draftShared = true
        draftSource = value.source
        draftMode = value.mode
    }
    function selectOutput(name) {
        draftShared = false
        output = name
        loadWallpaper()
    }
    Component.onCompleted: load()
    onOutputChanged: loadWallpaper()
    Connections {
        target: root.manager
        function onReadyChanged() { root.load() }
        function onStateChanged() { root.load() }
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
        font.pixelSize: root.tokens.type.small.size
        font.weight: root.tokens.type.body.weight
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
    }
    // Inline components must live at the top level of the file.
    component Entry: MenuItem {
        id: entry
        background: Rectangle { radius: root.tokens.radius.small; color: entry.highlighted ? root.tokens.color.surfaceAlt : "transparent" }
        contentItem: Caption { text: entry.text; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; wrapMode: Text.NoWrap }
    }
    // Clips arbitrary content to a rounded rectangle.
    component RoundClip: Item {
        id: rounded
        property real radius: 10
        default property alias content: holder.data
        Item {
            id: holder
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }
        }
        Rectangle { id: mask; anchors.fill: parent; radius: rounded.radius; color: "white"; layer.enabled: true; visible: false }
    }
    component Action: Button {
        id: button
        property bool primary: false
        focusPolicy: Qt.StrongFocus
        hoverEnabled: true
        implicitHeight: 40
        implicitWidth: label.implicitWidth + 32
        contentItem: Text {
            id: label
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: button.primary ? root.tokens.color.accentText : root.tokens.color.text
            font.family: root.tokens.type.body.family
            font.pixelSize: root.tokens.type.small.size
            font.weight: button.primary ? Font.DemiBold : root.tokens.type.body.weight
            textFormat: Text.PlainText
        }
        background: Rectangle {
            radius: root.tokens.radius.small + 4
            color: button.primary
                ? (button.down ? root.tokens.color.accentSoft : root.tokens.color.accent)
                : (button.down ? root.tokens.color.surface : button.hovered ? root.tokens.color.surfaceAlt : root.tokens.material.sidebar)
            border.width: button.primary && !button.visualFocus ? 0 : 1
            border.color: button.visualFocus ? root.tokens.color.accent
                : button.hovered ? root.tokens.color.accentSoft : root.tokens.color.border
            opacity: button.enabled ? (button.primary && button.hovered && !button.down ? 0.92 : 1) : 0.5
        }
    }

    Core.Settings {
        id: library
        location: root.manager ? "file://" + root.manager.storageDirectory + "/wallpaper-library.ini" : ""
        property url folder: "file://" + Core.StandardPaths.writableLocation(Core.StandardPaths.PicturesLocation)
    }
    FolderDialog {
        id: folderPicker
        title: "Папка с обоями"
        currentFolder: library.folder
        onAccepted: library.folder = selectedFolder
    }
    FolderListModel {
        id: images
        objectName: "wallpaper-library-model"
        folder: library.folder
        showDirs: false
        showHidden: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        sortField: FolderListModel.Name
    }
    FileDialog {
        id: picker
        title: "Выбрать обои"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Изображения (*.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP)"]
        onAccepted: root.draftSource = selectedFile
    }

    Item {
        id: content
        width: root.availableWidth
        height: Math.max(root.availableHeight, layout.implicitHeight)
        ColumnLayout {
            id: layout
            anchors.fill: parent
            spacing: 16

            Column {
                visible: root.showHeading
                Layout.fillWidth: true
                spacing: 4
                Caption { width: parent.width; text: "Обои"; font.pixelSize: 24; font.family: root.tokens.type.display.family }
                Caption { width: parent.width; text: "Выберите папку и изображение для рабочего стола"; color: root.tokens.color.textMuted }
            }

            SettingsSegmented {
                objectName: "wallpaper-monitors"
                Layout.alignment: Qt.AlignLeft
                tokens: root.tokens
                model: root.monitorModel
                currentKey: root.draftShared ? root.allKey : root.output
                onActivated: key => key === root.allKey ? root.selectAll() : root.selectOutput(key)
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                columns: width >= 640 ? 2 : 1
                columnSpacing: 12; rowSpacing: 12

                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 55
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: previewBox.height
                    Item {
                        id: previewBox
                        width: parent.width
                        // Leave room for the gallery: the preview never takes more than ~40% of the page.
                        height: Math.min(Math.max(150, root.availableHeight * 0.4), width * (root.selectedScreen && root.selectedScreen.width > 0 ? root.selectedScreen.height / root.selectedScreen.width : 9 / 16))
                        RoundClip {
                            anchors.fill: parent
                            radius: root.tokens.radius.medium
                            StaticRenderer {
                                id: preview
                                anchors.fill: parent
                                source: root.draftSource
                                mode: root.draftMode
                                nativeScale: root.selectedScreen ? previewBox.width / root.selectedScreen.width : 1
                                backgroundColor: root.tokens.color.background
                            }
                            Rectangle {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: Math.min(parent.height, 56)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.alpha(root.tokens.color.background, 0.8) }
                                }
                            }
                            Caption {
                                objectName: "wallpaper-preview-name"
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12; bottomMargin: 10 }
                                text: preview.failed ? "Не удалось открыть изображение. Выберите другой файл."
                                    : decodeURIComponent(String(root.draftSource).split("/").pop())
                                elide: Text.ElideMiddle; wrapMode: Text.NoWrap
                                font.pixelSize: 12
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: root.tokens.radius.medium
                            color: "transparent"
                            border.width: 1
                            border.color: root.tokens.color.border
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 45
                    Layout.fillHeight: true
                    implicitHeight: options.implicitHeight + 32
                    radius: root.tokens.radius.medium
                    color: root.tokens.material.sidebar
                    border.width: 1
                    border.color: root.tokens.color.border

                    ColumnLayout {
                        id: options
                        anchors { fill: parent; margins: 16 }
                        spacing: 8
                        Caption { text: "Размещение"; color: root.tokens.color.textMuted; Layout.fillWidth: true }
                        SettingsSegmented {
                            objectName: "wallpaper-modes"
                            Layout.fillWidth: true
                            tokens: root.tokens
                            equalWidth: true
                            model: root.modeModel
                            currentKey: root.draftMode
                            onActivated: key => root.draftMode = key
                        }
                        SettingsSwitch {
                            objectName: "wallpaper-shared"
                            Layout.fillWidth: true
                            tokens: root.tokens
                            text: "Одинаковые обои на всех мониторах"
                            checked: root.draftShared
                            onClicked: root.draftShared = checked
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: root.tokens.color.border }
                        SettingsSwitch {
                            objectName: "wallpaper-enabled"
                            Layout.fillWidth: true
                            tokens: root.tokens
                            text: "Показывать фон"
                            checked: root.draftEnabled
                            onClicked: root.draftEnabled = checked
                        }
                        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                        Action {
                            Layout.fillWidth: true
                            primary: true
                            objectName: "wallpaper-apply"
                            text: "Применить"
                            enabled: root.manager && root.manager.ready && !root.manager.saving
                                && (preview.loaded || !root.draftEnabled) && (root.draftShared || root.selectedScreen !== null)
                            onClicked: root.manager.apply(root.output, String(root.draftSource) === String(root.manager.defaultSource) ? "" : root.draftSource,
                                root.draftMode, root.draftShared, root.draftEnabled)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: 40
                    radius: root.tokens.radius.small + 4
                    color: root.tokens.material.sidebar
                    border.width: 1
                    border.color: root.tokens.color.border
                    SettingsNavGlyph {
                        id: folderGlyph
                        width: 20; height: 20
                        name: "folder"
                        ink: root.tokens.color.textMuted
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    }
                    Caption {
                        objectName: "wallpaper-folder-path"
                        anchors { left: folderGlyph.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        text: root.folderText
                        elide: Text.ElideMiddle; wrapMode: Text.NoWrap
                    }
                }
                Action { text: "Выбрать папку…"; onClicked: folderPicker.open() }
                Rectangle {
                    visible: root.width >= 560
                    implicitWidth: count.implicitWidth + 32
                    implicitHeight: 40
                    radius: root.tokens.radius.small + 4
                    color: "transparent"
                    border.width: 1
                    border.color: root.tokens.color.border
                    Caption {
                        id: count
                        objectName: "wallpaper-count"
                        anchors.centerIn: parent
                        text: root.countText
                        color: root.tokens.color.textMuted
                        wrapMode: Text.NoWrap
                    }
                }
                Action {
                    id: moreButton
                    objectName: "wallpaper-more"
                    text: "⋯"
                    implicitWidth: implicitHeight
                    Accessible.name: "Другие способы выбрать обои"
                    onClicked: moreMenu.open()
                    Menu {
                        id: moreMenu
                        objectName: "wallpaper-more-menu"
                        x: moreButton.width - width
                        y: moreButton.height + 4
                        width: 220
                        padding: 6
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        background: Rectangle { radius: root.tokens.radius.medium; color: root.tokens.color.surface; border.width: 1; border.color: root.tokens.color.border }
                        Entry { text: "Выбрать файл…"; onTriggered: picker.open() }
                        Entry { text: "Стандартный фон"; onTriggered: { root.draftSource = root.manager.defaultSource; root.draftMode = "fill" } }
                    }
                }
            }

            Caption {
                visible: images.count === 0
                Layout.fillWidth: true
                text: images.status === FolderListModel.Loading ? "Загрузка изображений…" : "В папке нет доступных изображений. Выберите другую папку."
                color: root.tokens.color.textMuted
            }
            GridView {
                id: gallery
                objectName: "wallpaper-gallery"
                readonly property int columns: width >= 700 ? 4 : width >= 480 ? 3 : 2
                readonly property int gap: 12
                readonly property int labelHeight: 18
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                Layout.preferredHeight: cellHeight
                cellWidth: width / columns
                cellHeight: (cellWidth - gap) * 9 / 16 + 6 + labelHeight + gap
                model: images
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: AbstractButton {
                    id: thumbnail
                    required property url fileUrl
                    required property string fileName
                    required property int index
                    readonly property bool selected: String(root.draftSource) === String(fileUrl)
                    width: gallery.cellWidth - gallery.gap
                    height: gallery.cellHeight - gallery.gap
                    hoverEnabled: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.name: fileName
                    Accessible.selected: selected
                    onClicked: root.draftSource = fileUrl
                    onActiveFocusChanged: if (activeFocus) {
                        gallery.positionViewAtIndex(index, GridView.Contain)
                    }
                    contentItem: Column {
                        spacing: 6
                        Item {
                            width: thumbnail.width
                            height: width * 9 / 16
                            RoundClip {
                                anchors.fill: parent
                                radius: root.tokens.radius.small + 2
                                Rectangle { anchors.fill: parent; color: root.tokens.color.background }
                                Image {
                                    anchors.fill: parent
                                    source: thumbnail.fileUrl
                                    sourceSize: Qt.size(320, 180)
                                    asynchronous: true
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: root.tokens.radius.small + 2
                                color: "transparent"
                                border.width: thumbnail.selected || thumbnail.visualFocus ? 2 : 1
                                border.color: thumbnail.selected || thumbnail.visualFocus ? root.tokens.color.accent
                                    : thumbnail.hovered ? root.tokens.color.accentSoft : root.tokens.color.border
                            }
                            Rectangle {
                                visible: thumbnail.selected
                                anchors { right: parent.right; top: parent.top; margins: 8 }
                                width: 20; height: 20; radius: 10
                                color: root.tokens.color.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: root.tokens.color.accentText
                                    font.family: root.tokens.type.body.family
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                        Caption {
                            width: parent.width
                            height: gallery.labelHeight
                            text: thumbnail.fileName
                            font.pixelSize: 12
                            color: thumbnail.selected ? root.tokens.color.text : root.tokens.color.textMuted
                            elide: Text.ElideMiddle; wrapMode: Text.NoWrap
                        }
                    }
                }
            }

            Caption {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.manager ? root.manager.message : ""
                color: root.tokens.color.textMuted
                Accessible.role: Accessible.StaticText
            }
            Caption {
                Layout.fillWidth: true
                visible: root.manager && Object.keys(root.manager.renderErrors).length > 0
                text: "Файл обоев недоступен на одном из мониторов. Выберите изображение и примените его заново."
                color: root.tokens.color.textMuted
            }
        }
    }
}
