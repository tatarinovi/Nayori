pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.folderlistmodel
import Quickshell
import "../canvas"
import "../../services/palette"

ScrollView {
    id: root
    property bool showHeading: true
    property bool compact: false
    required property var tokens
    required property var manager
    property var settingsService: null
    property string output: Quickshell.screens.length ? Quickshell.screens[0].name : ""
    property url draftSource: ""
    property string draftMode: "fill"
    property bool draftShared: true
    property bool draftEnabled: true
    property url libraryFolder: ""
    property string searchText: ""
    property string appliedSearch: ""
    property bool desktopPreview: true
    property string accentMode: "default"
    signal accentModeChangedRequested(string mode)
    property bool draftDynamic: accentMode === "automatic"
    property bool restoringLibrary: false
    property bool libraryLoaded: false
    property string loadedWallpaperState: ""
    onAccentModeChanged: draftDynamic = accentMode === "automatic"
    function wallpaperStateKey() {
        if (!manager) return ""
        return JSON.stringify([manager.state.wallpaper, manager.state.outputs, manager.state.shared, manager.state.enabled])
    }
    readonly property bool paletteReady: draftPalette.ready && draftPalette.sourcePath === draftPalette.filePath(draftSource)
    function loadLibrary() {
        if (!manager || !manager.ready || libraryLoaded) return
        restoringLibrary = true
        if (String(libraryFolder) === "") libraryFolder = manager.libraryFolder
        restoringLibrary = false
        libraryLoaded = true
    }
    onLibraryFolderChanged: if (!restoringLibrary && libraryLoaded) librarySave.restart()
    onSearchTextChanged: searchDelay.restart()
    onDraftSourceChanged: previewDelay.restart()
    onDraftModeChanged: previewDelay.restart()
    onDraftSharedChanged: previewDelay.restart()
    onDraftEnabledChanged: previewDelay.restart()
    onDesktopPreviewChanged: previewDelay.restart()
    onVisibleChanged: {
        if (!visible && manager) manager.cancelPreview()
        else previewDelay.restart()
    }
    Component.onDestruction: if (manager) manager.cancelPreview()
    Keys.onEscapePressed: event => {
        if (manager && manager.previewing) { cancel(); event.accepted = true }
    }
    function cancel() {
        manager.cancelPreview()
        desktopPreview = false
        load()
    }
    function chooseSource(source) {
        if (compact) desktopPreview = true
        draftSource = source
    }
    function updatePreview() {
        if (!manager) return
        if (!visible || !desktopPreview || !draftEnabled || preview.failed) { manager.cancelPreview(); return }
        // Keep the last paint while the next asynchronous image is loading.
        if (!preview.loaded) return
        const committed = manager.wallpaper(output)
        if (String(committed.source) === String(draftSource) && committed.mode === draftMode
                && manager.state.shared === draftShared) { manager.cancelPreview(); return }
        manager.preview(output, draftSource, draftMode, draftShared)
    }
    function filters() {
        // QDir wildcard character classes keep the query literal.
        const query = appliedSearch.replace(/[\[\]*?]/g, ch => ch === "[" ? "[[]" : ch === "]" ? "[]]" : "[" + ch + "]")
        return ["png", "jpg", "jpeg", "webp"].map(ext => "*" + query + "*." + ext)
    }
    Timer { id: searchDelay; interval: 120; onTriggered: root.appliedSearch = root.searchText.trim() }
    Timer { id: previewDelay; interval: 80; onTriggered: root.updatePreview() }
    Timer {
        id: librarySave; interval: 100; repeat: true
        onTriggered: {
            if (!root.manager || !root.manager.ready || root.manager.saving) return
            stop()
            root.manager.setLibraryFolder(root.libraryFolder)
        }
    }
    AccentExtractor { id: draftPalette; source: root.visible ? root.draftSource : "" }
    readonly property int imageCount: images.count
    readonly property bool canApply: manager && manager.ready && !manager.saving
        && (preview.loaded || !draftEnabled) && (draftShared || selectedScreen !== null)
    function apply() {
        if (!canApply) return
        const mode = draftDynamic ? "automatic" : accentMode === "manual" ? "manual" : "default"
        manager.apply(output, String(draftSource) === String(manager.defaultSource) ? "" : draftSource,
            draftMode, draftShared, draftEnabled, libraryFolder)
        if (!compact && mode !== accentMode) accentModeChangedRequested(mode)
    }
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
        let path = decodeURIComponent(String(root.libraryFolder).replace(/^file:\/\//, ""))
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
        draftShared = compact ? false : manager.state.shared
        draftEnabled = manager.state.enabled
        draftDynamic = accentMode === "automatic"
        loadedWallpaperState = wallpaperStateKey()
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
    Component.onCompleted: { load(); loadLibrary() }
    onOutputChanged: loadWallpaper()
    Connections {
        target: root.manager
        function onReadyChanged() { root.load(); root.loadLibrary() }
        function onStateChanged() {
            // A collection-path save must not discard the selected image.
            if (root.loadedWallpaperState !== root.wallpaperStateKey()) root.load()
        }
        function onLibraryFolderChanged() {
            if (!root.libraryLoaded || librarySave.running) return
            root.restoringLibrary = true
            root.libraryFolder = root.manager.libraryFolder
            root.restoringLibrary = false
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!root.selectedScreen) {
                root.manager.cancelPreview()
                root.output = Quickshell.screens.length ? Quickshell.screens[0].name : ""
            }
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

    FolderDialog {
        id: folderPicker
        title: "Папка с обоями"
        currentFolder: root.libraryFolder
        onAccepted: root.libraryFolder = selectedFolder
    }
    FolderListModel {
        id: images
        objectName: "wallpaper-library-model"
        folder: root.libraryFolder
        showDirs: false
        showHidden: false
        nameFilters: root.filters()
        caseSensitive: false
        sortField: FolderListModel.Name
    }
    FileDialog {
        id: picker
        title: "Выбрать обои"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Изображения (*.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP)"]
        onAccepted: root.chooseSource(selectedFile)
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

            ColumnLayout {
                visible: !root.compact && !!root.settingsService
                Layout.fillWidth: true
                spacing: 4
                Caption { text: "Размытие фона"; font.pixelSize: 18 }
                SettingsSwitch {
                    objectName: "desktop-blur-enabled"
                    Layout.fillWidth: true
                    tokens: root.tokens
                    text: "Размывать обои за окнами"
                    checked: root.settingsService ? root.settingsService.values.desktopBlurEnabled : false
                    onClicked: root.settingsService.update({desktopBlurEnabled: checked})
                }
                Repeater {
                    model: [
                        {key: "desktopBlurIntensity", label: "Размытие", min: 0, max: 100, unit: "%"},
                        {key: "desktopDimIntensity", label: "Затемнение", min: 0, max: 100, unit: "%"},
                        {key: "desktopBlurDuration", label: "Длительность анимации", min: 150, max: 600, unit: " мс"}
                    ]
                    delegate: RowLayout {
                        id: effectRow
                        required property var modelData
                        Layout.fillWidth: true
                        enabled: root.settingsService ? root.settingsService.values.desktopBlurEnabled : false
                        Caption { text: effectRow.modelData.label; Layout.preferredWidth: 190 }
                        SettingsSlider {
                            Layout.fillWidth: true
                            tokens: root.tokens
                            label: effectRow.modelData.label
                            from: effectRow.modelData.min
                            to: effectRow.modelData.max
                            stepSize: 1
                            source: root.settingsService ? root.settingsService.values[effectRow.modelData.key] : from
                            onChanged: value => {
                                const patch = {}
                                patch[effectRow.modelData.key] = value
                                root.settingsService.update(patch)
                            }
                        }
                        Caption {
                            Layout.preferredWidth: 60
                            horizontalAlignment: Text.AlignRight
                            text: (root.settingsService ? root.settingsService.values[effectRow.modelData.key] : 0) + effectRow.modelData.unit
                        }
                    }
                }
            }

            SettingsSegmented {
                objectName: "wallpaper-monitors"
                visible: !root.compact
                Layout.alignment: Qt.AlignLeft
                tokens: root.tokens
                model: root.monitorModel
                currentKey: root.draftShared ? root.allKey : root.output
                onActivated: key => key === root.allKey ? root.selectAll() : root.selectOutput(key)
            }

            GridLayout {
                visible: !root.compact
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
                                onLoadedChanged: previewDelay.restart()
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

                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !root.compact
                SettingsSwitch {
                    visible: !root.compact
                    Layout.fillWidth: true
                    tokens: root.tokens
                    text: "Предпросмотр на рабочем столе"
                    checked: root.desktopPreview
                    onClicked: root.desktopPreview = checked
                }
                Action { visible: !root.compact; text: "Отменить"; enabled: root.manager && root.manager.previewing; onClicked: root.cancel() }
            }
            SettingsSwitch {
                Layout.fillWidth: true
                tokens: root.tokens
                text: "Цвета интерфейса из обоев"
                visible: !root.compact
                checked: root.draftDynamic
                onClicked: root.draftDynamic = checked
            }
            RowLayout {
                Layout.fillWidth: true
                Caption { text: root.paletteReady ? "Палитра изображения" : "Извлечение палитры…"; color: root.tokens.color.textMuted }
                visible: !root.compact
                Repeater {
                    model: root.paletteReady ? [draftPalette.accent, draftPalette.background, draftPalette.surface, draftPalette.surfaceAlt] : []
                    Rectangle {
                        required property var modelData
                        implicitWidth: 24; implicitHeight: 24; radius: 6
                        color: modelData
                        border.width: 1; border.color: root.tokens.color.border
                        Accessible.name: String(modelData)
                    }
                }
                Item { Layout.fillWidth: true }
            }
            Caption {
                Layout.fillWidth: true
                text: "Сейчас: " + decodeURIComponent(String(root.manager ? root.manager.wallpaper(root.output).source : "").split("/").pop())
                elide: Text.ElideMiddle; wrapMode: Text.NoWrap
            }
            SettingsSegmented {
                visible: root.compact
                Layout.fillWidth: true
                tokens: root.tokens
                model: root.modeModel
                equalWidth: true
                currentKey: root.draftMode
                onActivated: key => { root.desktopPreview = true; root.draftMode = key }
            }
            TextField {
                objectName: "wallpaper-search"
                Layout.fillWidth: true
                placeholderText: "Поиск по имени файла"
                text: root.searchText
                onTextEdited: root.searchText = text
                color: root.tokens.color.text
                placeholderTextColor: root.tokens.color.textMuted
                font.family: root.tokens.type.body.family
                font.pixelSize: root.tokens.type.small.size
                background: Rectangle { radius: root.tokens.radius.small; color: root.tokens.material.sidebar; border.width: 1; border.color: root.tokens.color.border }
                leftPadding: 12; rightPadding: 12
                implicitHeight: 40
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: 8
                Rectangle {
                    visible: !root.compact
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
                        Entry { text: "Стандартный фон"; onTriggered: { root.chooseSource(root.manager.defaultSource); root.draftMode = "fill" } }
                    }
                }
            }

            Caption {
                visible: images.count === 0
                Layout.fillWidth: true
                text: images.status === FolderListModel.Loading ? "Загрузка изображений…" : root.appliedSearch ? "Изображения не найдены. Измените запрос." : "В папке нет доступных изображений. Выберите другую папку."
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
                reuseItems: true
                cacheBuffer: cellHeight
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
                    onClicked: root.chooseSource(fileUrl)
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
