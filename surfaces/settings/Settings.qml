pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../../services/system"
import "../panel"

FocusScope {
    id: root
    property var wallpaperManager: null
    property var companionTokens: tokens
    property var bluetoothService: null
    property var settingsService: null
    property var polkitService: null
    property bool widgetsEditing: false
    signal widgetsEditingRequested(bool on)
    required property var tokens
    property var captureSettings: ({})
    signal captureSettingsChangedRequested(var patch)
    property var mixerSources: []
    signal mixerSourcesChangedRequested(var sources)
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    signal hideSecondaryIslandChangedRequested(bool hidden)
    property string fullscreenIslandOutput: ""
    signal fullscreenIslandOutputChangedRequested(string output)
    property var panelReservations: ({})
    property var panelModes: ({})
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    property string userName: ""
    property string avatarSource: ""
    property var frequentKeys: []
    property var recentKeys: []
    signal sectionVisited(string key)
    readonly property url homeWallpaper: {
        if (!wallpaperManager) return ""
        const state = wallpaperManager.state
        const output = Quickshell.screens.length ? Quickshell.screens[0].name : ""
        return wallpaperManager.wallpaper(output).source
    }
    readonly property var frequentSections: frequentKeys.map(key => {
        const item = sections.find(section => section.key === key && key !== "home")
        if (!item) return null
        const category = categories.find(category => category.name === item.group)
        const specific = ["sound", "network", "power", "wallpapers", "panels", "island"]
        return {key: item.key, title: item.title, glyph: item.glyph || (specific.indexOf(item.key) >= 0 ? item.key : category ? category.glyph : "apps")}
    }).filter(item => item !== null).slice(0, 4)
    property string weatherCity: ""
    property int weatherRefreshMinutes: 15
    property bool islandRotationEnabled: true
    property int islandRotationSeconds: 15
    property string startIconStyle: "current"
    signal startIconStyleChangedRequested(string style)
    property var updateService: null
    property string preferredTerminal: "kitty"
    property string preferredFileManager: "io.github.lgse.Strata"
    property var niri: null
    property string colorScheme: "dark"
    signal colorSchemeChangedRequested(string scheme)
    property string surfaceStyle: "solid"
    signal surfaceStyleChangedRequested(string style)
    property string accentMode: "default"
    signal accentModeChangedRequested(string mode)
    property string manualAccent: "#C0AFD1"
    signal manualAccentChangedRequested(string color)
    property string accentStatus: ""
    property string niriAccentError: ""
    property color accentPreview: "#C0AFD1"
    property var accentCandidates: []
    signal accentResetRequested()
    property string companionStyle: "current"
    signal companionStyleChangedRequested(string style)
    property bool companionEnabled: false
    signal companionChangedRequested(bool enabled)
    property bool companionDesktopOnly: false
    signal companionDesktopOnlyChangedRequested(bool enabled)
    property bool companionReactToPointer: true
    signal companionReactToPointerChangedRequested(bool enabled)
    property bool companionSystemLines: true
    signal companionSystemLinesChangedRequested(bool enabled)
    property string fullscreenCompanionOutput: ""
    signal fullscreenCompanionOutputChangedRequested(string output)
    property string companionScreen: "primary"
    signal companionScreenChangedRequested(string screen)
    property string companionSide: "right"
    signal companionSideChangedRequested(string side)
    property var remindCompanion: null
    property bool animationsEnabled: true
    signal animationsChangedRequested(bool enabled)
    property bool notificationsEnabled: true
    signal notificationsEnabledChangedRequested(bool enabled)
    property bool receptionEnabled: false
    property bool receptionAvailable: false
    property string receptionError: ""
    signal receptionChangedRequested(bool enabled)
    property var notificationSources: []
    signal sourceModeRequested(string key, string mode)
    property bool dndManual: false
    property double dndUntil: 0
    signal dndUntilRequested(double until)
    signal dndManualRequested()
    signal dndClearRequested()
    property bool niriColorIntegration: true
    signal niriColorIntegrationChangedRequested(bool enabled)
    property bool strataThemeIntegration: true
    signal strataThemeIntegrationChangedRequested(bool enabled)
    property string strataError: ""
    property string strataNotice: ""
    signal islandRotationEnabledChangedRequested(bool enabled)
    signal islandRotationSecondsChangedRequested(int seconds)
    signal preferredTerminalChangedRequested(string terminalId)
    signal preferredFileManagerChangedRequested(string fileManagerId)
    property string settingsMessage: ""
    property bool canRecover: false
    property bool canRetry: false
    signal recoverRequested()
    signal retryRequested()
    component Label: SettingsLabel { tokens: root.tokens }
    component Action: SettingsAction { tokens: root.tokens }
    component NaomiSection: SettingsScroll {
        id: naomiSection
        property string section: "overview"
        property int activePage: 25
        NaomiPage {
            section: naomiSection.section
            width: parent.width
            tokens: root.tokens
            companionTokens: root.companionTokens
            companionStyle: root.companionStyle
            onCompanionStyleChangedRequested: style => root.companionStyleChangedRequested(style)
            companionEnabled: root.companionEnabled
            animationsEnabled: root.animationsEnabled
            previewActive: root.currentPage === naomiSection.activePage && root.visible
            onCompanionChangedRequested: enabled => root.companionChangedRequested(enabled)
            companionDesktopOnly: root.companionDesktopOnly
            onCompanionDesktopOnlyChangedRequested: enabled => root.companionDesktopOnlyChangedRequested(enabled)
            companionReactToPointer: root.companionReactToPointer
            onCompanionReactToPointerChangedRequested: enabled => root.companionReactToPointerChangedRequested(enabled)
            companionSystemLines: root.companionSystemLines
            onCompanionSystemLinesChangedRequested: enabled => root.companionSystemLinesChangedRequested(enabled)
            fullscreenCompanionOutput: root.fullscreenCompanionOutput
            onFullscreenCompanionOutputChangedRequested: output => root.fullscreenCompanionOutputChangedRequested(output)
            companionScreen: root.companionScreen
            onCompanionScreenChangedRequested: screen => root.companionScreenChangedRequested(screen)
            companionSide: root.companionSide
            onCompanionSideChangedRequested: side => root.companionSideChangedRequested(side)
            remindCompanion: root.remindCompanion
            settingsService: root.settingsService
            onRevealRequested: item => naomiSection.reveal(item)
        }
    }
    property int currentPage: 0
    signal reservationChanged(int top, int bottom)
    signal panelReservationChangedRequested(string output, int top, int bottom)
    signal panelModeChangedRequested(string output, string part, string mode)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal weatherCityChangedRequested(string city)
    signal weatherRefreshMinutesChangedRequested(int minutes)
    signal closeRequested()

    implicitWidth: 1100
    implicitHeight: 760
    readonly property bool compact: width < 960
    readonly property int inset: compact ? 24 : 32
    readonly property int railWidth: compact ? 68 : 76
    readonly property int secondaryWidth: compact ? 184 : 232
    readonly property bool hasSecondary: currentPage !== 0 || searchOpen
    readonly property int sidebarWidth: railWidth + (hasSecondary ? secondaryWidth : 0)
    property int displayedPage: 0
    onDisplayedPageChanged: if (displayedPage === 0)
        Qt.callLater(function() { if (homeScroll.contentItem) homeScroll.contentItem.contentY = 0 })
    property string displayedCategory: "Обзор"
    readonly property var displayedSection: sections.find(item => item.page === displayedPage) || sections[0]
    property bool viewReady: false
    Component.onCompleted: viewReady = true
    onActiveCategoryChanged: if (viewReady) secondaryMotion.reveal()
    onAnimationsEnabledChanged: if (!animationsEnabled) {
        pageMotion.finish()
        secondaryMotion.finish()
        sidebarResize.complete()
        secondaryFade.complete()
        Qt.callLater(function() {
            if (!root.animationsEnabled) {
                sidebarResize.complete()
                secondaryFade.complete()
            }
        })
    }
    // Stable IDs support future sections without exposing page indexes over IPC.
    readonly property var sections: [
        {key: "home", page: 0, title: "Обзор", group: "Обзор", description: "Состояние сети, звука и быстрый переход к разделам"},
        {key: "display", page: 5, title: "Экран", group: "Система", description: "Настройте расположение мониторов, выберите режимы вывода и другие параметры"},
        {key: "sound", page: 6, title: "Звук", group: "Система", description: "Устройства PipeWire, громкость и источники микшера"},
        {key: "notifications", page: 30, title: "Уведомления", group: "Система", glyph: "notifications", description: "Системный приём, режим «Не беспокоить» и показ уведомлений отдельных приложений"},
        {key: "polkit", page: 31, title: "Подтверждение", group: "Система", glyph: "system", description: "Диалог, когда система просит подтвердить действие"},
        {key: "power", page: 7, title: "Питание", group: "Система", description: "Блокировка, завершение сеанса, перезагрузка и выключение"},
        {key: "network", page: 8, title: "Сеть", group: "Система", description: "Wi\u2011Fi, Ethernet и подключения NetworkManager"},
        {key: "localsend", page: 9, title: "LocalSend", group: "Система", description: "Запуск LocalSend, если приложение установлено"},
        {key: "bluetooth", page: 10, title: "Bluetooth", group: "Устройства", description: "Питание адаптера, поиск и подключение устройств"},
        {key: "mouse", page: 11, title: "Мышь", group: "Устройства", description: "Что можно прочитать о мыши в этой сессии niri"},
        {key: "keyboard", page: 12, title: "Клавиатура", group: "Устройства", description: "Раскладка и повтор, которые задаёт niri"},
        {key: "shortcuts", page: 13, title: "Сочетания клавиш", group: "Устройства", description: "Сочетания из конфигурации niri. Запись файла выключена"},
        {key: "appearance", page: 2, title: "Внешний вид", group: "Персонализация", description: "Тема, прозрачность, акцент и анимации интерфейса"},
        {key: "wallpapers", page: 4, title: "Обои", group: "Персонализация", description: "Выберите папку и изображение для рабочего стола"},
        {key: "panels", page: 1, title: "Панель задач", group: "Персонализация", description: "Автоскрытие островов, место для окон у краёв экрана и мониторы"},
        {key: "widgets", page: 32, title: "Виджеты", group: "Персонализация", glyph: "apps", description: "Виджеты на рабочем столе и их расположение"},
        {key: "start", page: 14, title: "Пуск", group: "Персонализация", description: "Значок и приложения кнопки «Пуск»"},
        {key: "island", page: 15, title: "Dynamic Island", group: "Персонализация", description: "Чередование часов и погоды, город и интервал"},
        {key: "lockscreen", page: 16, title: "Экран блокировки", group: "Персонализация", description: "Предпросмотр экрана блокировки с\u00A0обоями и цветами Nayori"},
        {key: "weather", page: 3, title: "Погода", group: "Персонализация", description: "Город для прогноза в Dynamic Island", sidebar: false},
        {key: "windows", page: 17, title: "Окна", group: "Окна и столы", description: "Фокус окон и ограничения конфигурации niri"},
        {key: "alttab", page: 18, title: "Alt+Tab", group: "Окна и столы", description: "Переключение окон в этой сессии niri"},
        {key: "workspaces", page: 19, title: "Рабочие столы", group: "Окна и столы", description: "Столы, которые сейчас сообщает niri"},
        {key: "defaults", page: 20, title: "По умолчанию", group: "Приложения", description: "Приложения по умолчанию через xdg-mime"},
        {key: "autostart", page: 21, title: "Автозапуск", group: "Приложения", description: "Записи автозапуска пользователя и системы"},
        {key: "capture", page: 28, title: "Запись экрана", group: "Приложения", description: "Скриншоты, скринкасты, папки сохранения, цвет разметки, звук и частота кадров"},
        {key: "naomi", page: 25, title: "Обзор", group: "Naomi", description: "Включение Naomi и предпросмотр"},
        {key: "naomi-look", page: 26, title: "Внешний вид", group: "Naomi", description: "Рисунок и цвет с обоев"},
        {key: "naomi-place", page: 27, title: "Отображение", group: "Naomi", description: "Монитор, угол и слой"},
        {key: "naomi-remind", page: 29, title: "Напоминания", group: "Naomi", description: "Вода, глаза и разминка без ожидания"},
        {key: "integrations", page: 24, title: "Интеграции", group: "Приложения", description: "Цвета Nayori в\u00A0niri и тема Strata"},
        {key: "updates", page: 22, title: "Обновления", group: "NayoriOS", description: "Обновление пакетов в терминале, только по кнопке"},
        {key: "about", page: 23, title: "О системе", group: "NayoriOS", description: "Версии Nayori, niri, Quickshell и системы"}
    ]
    readonly property var navigationSections: sections.filter(item => item.sidebar !== false)
    readonly property var section: sections.find(item => item.page === currentPage) || sections[0]
    readonly property bool persistsSettings: {
        const key = section.key
        const naomiSettings = key === "naomi" || key === "naomi-look" || key === "naomi-place"
        return key === "home" || key === "panels" || key === "appearance" || key === "weather" || key === "start" || key === "island" || key === "integrations" || key === "capture" || key === "notifications" || key === "widgets" || naomiSettings
    }
    readonly property var categories: [
        {name: "Обзор", caption: "Обзор", glyph: "home"},
        {name: "Система", caption: "Система", glyph: "system"},
        {name: "Устройства", caption: "Устройства", glyph: "devices"},
        {name: "Персонализация", caption: "Облик", glyph: "appearance"},
        {name: "Naomi", caption: "Naomi", glyph: "naomi"},
        {name: "Окна и столы", caption: "Окна", glyph: "windows"},
        {name: "Приложения", caption: "Приложения", glyph: "apps"},
        {name: "NayoriOS", caption: "NayoriOS", glyph: "about"}
    ]
    property bool searchOpen: false
    property string navQuery: ""
    property string activeCategory: "Обзор"
    readonly property string navQueryFolded: navQuery.trim().toLowerCase()
    readonly property bool navSearching: searchOpen
    readonly property var visibleSections: navSearching
        ? searchSections()
        : navigationSections.filter(item => item.group === displayedCategory)
    readonly property bool navHasMatches: visibleSections.length > 0
    function sectionPath(item) {
        const group = item.group === "Персонализация" ? "Облик" : item.group
        return item.key === "home" ? "Настройки / Обзор" : group + " / " + item.title
    }
    function searchSections() {
        if (!navQueryFolded) {
            return recentKeys.map(key => sections.find(item => item.key === key))
                .filter(item => item && item.key !== "home").slice(0, 7)
        }
        return sections.filter(item => queryHit(item.title) || queryHit(sectionPath(item)) || queryHit(item.description))
            .sort((left, right) => {
                const a = recentKeys.indexOf(left.key)
                const b = recentKeys.indexOf(right.key)
                return (a < 0 ? sections.length : a) - (b < 0 ? sections.length : b)
            }).slice(0, 10)
    }
    function queryHit(text) {
        return String(text || "").toLowerCase().indexOf(navQueryFolded) >= 0
    }
    function openSearch() {
        searchOpen = true
        Qt.callLater(function() { navSearch.forceActiveFocus(Qt.ShortcutFocusReason) })
    }
    function closeSearch(restoreFocus) {
        searchOpen = false
        navSearch.text = ""
        navQuery = ""
        if (restoreFocus) searchToggle.forceActiveFocus(Qt.ShortcutFocusReason)
    }
    function dismissSearch() {
        if (navQuery !== "" || navSearch.text !== "") {
            navSearch.text = ""
            navQuery = ""
            navSearch.forceActiveFocus(Qt.ShortcutFocusReason)
        } else closeSearch(true)
    }
    function openKey(key) {
        const match = sections.find(item => item.key === key)
        if (!match) return
        closeSearch(false)
        activeCategory = match.group
        currentPage = match.page
    }
    function selectCategory(name) {
        closeSearch(false)
        activeCategory = name
        const match = navigationSections.find(item => item.group === name && item.page === currentPage)
            || navigationSections.find(item => item.group === name)
        if (match) currentPage = match.page
    }
    function revealNavigation(item) {
        const flick = navigationScroll.contentItem
        const top = item.mapToItem(navigationColumn, 0, 0).y
        if (top < flick.contentY) flick.contentY = top
        else if (top + item.height > flick.contentY + flick.height)
            flick.contentY = top + item.height - flick.height
    }
    function focusNav(index) {
        if (displayedCategory !== activeCategory) {
            secondaryMotion.finish()
            Qt.callLater(function() { root.focusNav(index) })
            return
        }
        const item = navigation.itemAt(index)
        if (item) item.forceActiveFocus(Qt.TabFocusReason)
    }
    function focusInput() {
        if (searchOpen) { navSearch.forceActiveFocus(Qt.TabFocusReason); return }
        if (displayedCategory !== activeCategory) {
            secondaryMotion.finish()
            Qt.callLater(root.focusInput)
            return
        }
        const index = visibleSections.findIndex(item => item.page === currentPage)
        if (hasSecondary && index >= 0) focusNav(index)
        else {
            const category = categoryNavigation.itemAt(0)
            if (category) category.forceActiveFocus(Qt.TabFocusReason)
        }
    }
    function adjacentNav(from, direction) {
        return (from + direction + visibleSections.length) % visibleSections.length
    }
    onCurrentPageChanged: {
        if (viewReady) pageMotion.reveal()
        const selectedSection = sections.find(item => item.page === currentPage)
        if (selectedSection) {
            activeCategory = selectedSection.group
            if (viewReady && selectedSection.key !== "home") sectionVisited(selectedSection.key)
        }
        Qt.callLater(function() {
            const index = root.visibleSections.findIndex(item => item.page === root.currentPage)
            const item = index >= 0 ? navigation.itemAt(index) : null
            if (item) root.revealNavigation(item)
        })
    }
    Keys.onEscapePressed: function(event) {
        event.accepted = true
        if (root.searchOpen) root.dismissSearch()
        else root.closeRequested()
    }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
            event.accepted = true
            root.openSearch()
        }
    }

    NiriConfigView { id: niriConfig }

    Rectangle { anchors.fill: parent; color: root.tokens.material.dense }
    Rectangle {
        id: sidebar
        objectName: "settings-sidebar"
        width: root.sidebarWidth
        clip: true
        Behavior on width {
            enabled: root.viewReady && root.animationsEnabled && !root.tokens.motion.off
            NumberAnimation {
                id: sidebarResize
                duration: root.animationsEnabled && !root.tokens.motion.off ? root.tokens.motion.base : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.23, 1, 0.32, 1, 1, 1]
            }
        }
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
        color: root.tokens.material.sidebar
        Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: root.tokens.color.border }
        Rectangle {
            id: primaryRail
            width: root.railWidth
            height: parent.height
            color: root.tokens.material.dense
            Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: root.tokens.color.border }
            NayoriMark {
                id: brandMark
                anchors { top: parent.top; topMargin: 22; horizontalCenter: parent.horizontalCenter }
                width: 44; height: 44
                variant: "fox"
                ink: root.tokens.color.accent
            }
            AbstractButton {
                id: searchToggle
                objectName: "settings-search-toggle"
                anchors { top: brandMark.bottom; topMargin: 18; left: parent.left; right: parent.right; margins: 6 }
                height: 44
                hoverEnabled: true
                Accessible.name: "Найти раздел"
                Accessible.description: "Ctrl+F"
                onClicked: root.searchOpen ? root.closeSearch(true) : root.openSearch()
                Keys.onDownPressed: {
                    const item = categoryNavigation.itemAt(0)
                    if (item) item.forceActiveFocus(Qt.TabFocusReason)
                }
                background: Rectangle {
                    radius: root.tokens.radius.small
                    color: root.searchOpen || searchToggle.hovered ? root.tokens.color.surfaceAlt : "transparent"
                    border.width: searchToggle.visualFocus ? 1 : 0
                    border.color: root.tokens.color.accent
                }
                contentItem: Item {
                    Canvas {
                        anchors.centerIn: parent
                        width: 22; height: 22
                        property color ink: root.searchOpen ? root.tokens.color.accent : root.tokens.color.textMuted
                        onInkChanged: requestPaint()
                        onPaint: {
                            const c = getContext("2d")
                            c.reset()
                            c.strokeStyle = ink
                            c.lineWidth = 2
                            c.lineCap = "round"
                            c.beginPath(); c.arc(9, 9, 6, 0, Math.PI * 2); c.stroke()
                            c.beginPath(); c.moveTo(14, 14); c.lineTo(20, 20); c.stroke()
                        }
                    }
                }
            }
            ScrollView {
                id: categoryScroll
                anchors { top: searchToggle.bottom; topMargin: 12; bottom: parent.bottom; bottomMargin: 16; left: parent.left; right: parent.right; margins: 6 }
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                Column {
                    width: categoryScroll.availableWidth
                    spacing: 6
                    Repeater {
                        id: categoryNavigation
                        model: root.categories
                        delegate: AbstractButton {
                            id: categoryButton
                            required property var modelData
                            required property int index
                            objectName: "settings-category-" + modelData.glyph
                            width: parent.width
                            height: 68
                            padding: 0
                            hoverEnabled: true
                            readonly property bool selected: !root.searchOpen && root.activeCategory === modelData.name
                            Accessible.name: modelData.name
                            Accessible.selected: selected
                            onClicked: root.selectCategory(modelData.name)
                            background: Rectangle {
                                radius: root.tokens.radius.small
                                color: categoryButton.selected || categoryButton.hovered ? root.tokens.color.surfaceAlt : "transparent"
                                border.width: categoryButton.visualFocus ? 1 : 0
                                border.color: root.tokens.color.accent
                                Rectangle {
                                    visible: categoryButton.selected
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    width: 2; height: 22; radius: 1
                                    color: root.tokens.color.accent
                                }
                            }
                            contentItem: Item {
                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    spacing: 6
                                    SettingsNavGlyph {
                                        objectName: "settings-category-icon"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 22; height: 22
                                        name: categoryButton.modelData.glyph
                                        ink: categoryButton.selected ? root.tokens.color.accent : root.tokens.color.textMuted
                                    }
                                    Label {
                                        objectName: "settings-category-caption"
                                        width: parent.width
                                        text: categoryButton.modelData.caption
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.NoWrap
                                        color: categoryButton.selected ? root.tokens.color.text : root.tokens.color.textMuted
                                        font.pixelSize: root.compact ? 9 : 10
                                        lineHeight: 1.05
                                    }
                                }
                            }
                            Keys.onDownPressed: {
                                const item = categoryNavigation.itemAt((index + 1) % root.categories.length)
                                if (item) item.forceActiveFocus(Qt.TabFocusReason)
                            }
                            Keys.onUpPressed: {
                                const item = categoryNavigation.itemAt((index - 1 + root.categories.length) % root.categories.length)
                                if (item) item.forceActiveFocus(Qt.TabFocusReason)
                            }
                            Keys.onRightPressed: root.focusNav(0)
                        }
                    }
                }
            }
        }
        Item {
            id: secondary
            objectName: "settings-secondary"
            x: root.railWidth
            width: root.secondaryWidth
            height: parent.height
            visible: root.hasSecondary || (root.animationsEnabled && opacity > 0)
            enabled: root.hasSecondary
            opacity: root.hasSecondary ? 1 : 0
            Behavior on opacity {
                enabled: root.viewReady && root.animationsEnabled && !root.tokens.motion.off
                NumberAnimation { id: secondaryFade; duration: root.animationsEnabled && !root.tokens.motion.off ? root.tokens.motion.base : 0 }
            }
            Item {
                anchors.fill: parent
                opacity: secondaryMotion.progress
            SettingsPageMotion {
                id: secondaryMotion
                enabled: root.animationsEnabled && !root.tokens.motion.off
                duration: root.tokens.motion.base
                onSwapRequested: root.displayedCategory = root.activeCategory
            }
        Column {
            id: identity
            anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 27; leftMargin: 20; rightMargin: 16 }
            spacing: 8
            Label { text: "НАСТРОЙКИ / 設定"; font.pixelSize: 10; font.letterSpacing: 1.2; color: root.tokens.color.accent }
            Label {
                width: parent.width
                text: root.navSearching ? "Поиск" : (root.displayedCategory === "Персонализация" ? "Облик" : root.displayedCategory)
                wrapMode: Text.Wrap
                font.family: root.tokens.type.display.family
                font.pixelSize: root.compact ? 21 : 24
                color: root.tokens.color.text
            }
        }
        SettingsField {
            id: navSearch
            objectName: "settings-search"
            visible: root.searchOpen
            anchors { top: identity.bottom; topMargin: 22; left: parent.left; leftMargin: 12; right: parent.right; rightMargin: 12 }
            tokens: root.tokens
            placeholderText: "Найти раздел"
            Accessible.name: "Найти раздел"
            Accessible.description: "По названию, пути и описанию раздела"
            onTextEdited: root.navQuery = text
            Keys.onDownPressed: root.focusNav(0)
            Keys.onEscapePressed: function(event) {
                event.accepted = true
                root.dismissSearch()
            }
        }
        ScrollView {
            id: navigationScroll
            anchors { top: root.searchOpen ? navSearch.bottom : identity.bottom; topMargin: root.searchOpen ? 16 : 22; bottom: parent.bottom; bottomMargin: 22; left: parent.left; right: parent.right; leftMargin: 10; rightMargin: 10 }
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.active: true
            Column {
                id: navigationColumn
                width: navigationScroll.availableWidth
                spacing: 4
                Label {
                    visible: !root.navHasMatches
                    width: parent.width
                    leftPadding: 10; rightPadding: 10
                    text: root.navQueryFolded ? "Ничего не найдено" : "Недавно открытых разделов пока нет"
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                }
                Repeater {
                    id: navigation
                    model: root.visibleSections
                    delegate: Action {
                        id: navButton
                        required property var modelData
                        required property int index
                        navigation: true
                        objectName: "settings-nav-" + modelData.key
                        width: parent.width
                        text: modelData.title
                        glyph: modelData.key
                        detail: root.navSearching ? root.sectionPath(modelData) : ""
                        selected: root.currentPage === modelData.page
                        Accessible.selected: selected
                        onClicked: root.openKey(modelData.key)
                        onActiveFocusChanged: if (activeFocus) root.revealNavigation(navButton)
                        Keys.onDownPressed: function(event) { event.accepted = true; root.focusNav(root.adjacentNav(index, 1)) }
                        Keys.onUpPressed: function(event) { event.accepted = true; root.focusNav(root.adjacentNav(index, -1)) }
                        Keys.onLeftPressed: {
                            const index = root.categories.findIndex(item => item.name === root.activeCategory)
                            const item = categoryNavigation.itemAt(index)
                            if (item) item.forceActiveFocus(Qt.TabFocusReason)
                        }
                    }
                }
            }
        }
        }
        }
    }

    Item {
        id: main
        objectName: "settings-main"
        opacity: pageMotion.progress
        SettingsPageMotion {
            id: pageMotion
            enabled: root.animationsEnabled && !root.tokens.motion.off
            duration: root.tokens.motion.base
            onSwapRequested: root.displayedPage = root.currentPage
        }
        anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right; margins: root.inset }
        Column {
            id: header
            width: parent.width
            spacing: 10
            Rectangle { width: 40; height: 2; color: root.tokens.color.accent }
            Label { visible: root.displayedSection.group !== root.displayedSection.title; text: root.displayedSection.group.toUpperCase(); font.pixelSize: 11; font.letterSpacing: 1.4; color: root.tokens.color.accent }
            Label { width: parent.width; text: root.displayedSection.title; font.family: root.tokens.type.display.family; font.pixelSize: root.tokens.settings.heading; lineHeight: 1.1 }
            Label { width: parent.width; text: root.displayedSection.description; color: root.tokens.color.textMuted }
        }
        StackLayout {
            id: pages
            anchors { top: header.bottom; topMargin: 28; bottom: footer.top; bottomMargin: 20; left: parent.left; right: parent.right }
            currentIndex: root.displayedPage
            SettingsScroll {
                id: homeScroll
                HomePage {
                    objectName: "settings-overview"
                    width: parent.width
                    tokens: root.tokens
                    userName: root.userName
                    avatarSource: root.avatarSource
                    wallpaperSource: root.homeWallpaper
                    frequentSections: root.frequentSections
                    onSectionRequested: key => root.openKey(key)
                    onRevealRequested: item => homeScroll.reveal(item)
                }
            }

            PanelsPage {
                Layout.maximumWidth: 960
                tokens: root.tokens
                showHeading: false
                wallpapers: root.wallpaperManager
                topReserved: root.topReserved
                bottomReserved: root.bottomReserved
                hideSecondaryIsland: root.hideSecondaryIsland
                fullscreenIslandOutput: root.fullscreenIslandOutput
                panelReservations: root.panelReservations
                panelModes: root.panelModes
                autoHideTop: root.autoHideTop
                autoHideApps: root.autoHideApps
                autoHideWorkspaces: root.autoHideWorkspaces
                autoHideStatus: root.autoHideStatus
                onReservationChanged: (top, bottom) => root.reservationChanged(top, bottom)
                onPanelReservationChangedRequested: (output, top, bottom) => root.panelReservationChangedRequested(output, top, bottom)
                onPanelModeChangedRequested: (output, part, mode) => root.panelModeChangedRequested(output, part, mode)
                onAutoHideChangedRequested: (top, apps, workspaces, status) => root.autoHideChangedRequested(top, apps, workspaces, status)
                onHideSecondaryIslandChangedRequested: hidden => root.hideSecondaryIslandChangedRequested(hidden)
                onFullscreenIslandOutputChangedRequested: output => root.fullscreenIslandOutputChangedRequested(output)
            }
            ScrollView {
                id: appearanceScroll
                objectName: "settingsAppearanceScroll"
                function reveal(item) {
                    const flick = contentItem
                    const point = item.mapToItem(flick.contentItem, 0, 0)
                    if (point.y < flick.contentY) flick.contentY = point.y
                    else if (point.y + item.height > flick.contentY + flick.height)
                        flick.contentY = point.y + item.height - flick.height
                }
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.active: true
                AppearancePage {
                    width: Math.min(960, appearanceScroll.availableWidth - 12)
                    tokens: root.tokens
                    showHeading: false
                    colorScheme: root.colorScheme
                    onColorSchemeChangedRequested: scheme => root.colorSchemeChangedRequested(scheme)
                    surfaceStyle: root.surfaceStyle
                    onRevealRequested: item => appearanceScroll.reveal(item)
                    onSurfaceStyleChangedRequested: style => root.surfaceStyleChangedRequested(style)
                    accentMode: root.accentMode
                    onAccentModeChangedRequested: mode => root.accentModeChangedRequested(mode)
                    manualAccent: root.manualAccent
                    onManualAccentChangedRequested: color => root.manualAccentChangedRequested(color)
                    accentStatus: root.accentStatus
                    accentPreview: root.accentPreview
                    accentCandidates: root.accentCandidates
                    onAccentResetRequested: root.accentResetRequested()
                    animationsEnabled: root.animationsEnabled
                    onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
                }
            }
            ScrollView {
                id: weatherScroll
                function reveal(item) {
                    const flick = contentItem
                    const point = item.mapToItem(flick.contentItem, 0, 0)
                    if (point.y < flick.contentY) flick.contentY = point.y
                    else if (point.y + item.height > flick.contentY + flick.height)
                        flick.contentY = point.y + item.height - flick.height
                }
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.active: true
                WeatherPage {
                    width: Math.min(960, weatherScroll.availableWidth - 12)
                    tokens: root.tokens
                    showHeading: false
                    onRevealRequested: item => weatherScroll.reveal(item)
                    weatherCity: root.weatherCity
                    weatherRefreshMinutes: root.weatherRefreshMinutes
                    onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
                    onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
                }
            }
            WallpaperPage {
                Layout.maximumWidth: 960
                tokens: root.tokens
                showHeading: false
                manager: root.wallpaperManager
            }
            SettingsScroll { DisplayPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll {
                SoundPage {
                    width: parent.width
                    tokens: root.tokens
                    mixerSources: root.mixerSources
                    onMixerSourcesChangedRequested: sources => root.mixerSourcesChangedRequested(sources)
                }
            }
            SettingsScroll { PowerPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { NetworkPage { width: parent.width; tokens: root.tokens; scanning: root.currentPage === 8 } }
            SettingsScroll { LocalSendPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { BluetoothPage { width: parent.width; tokens: root.tokens; bluetoothService: root.bluetoothService; settingsService: root.settingsService } }
            SettingsScroll { MousePage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { KeyboardPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { ShortcutsPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll {
                id: startScroll
                StartPage {
                    onRevealRequested: item => startScroll.reveal(item)
                    width: parent.width
                    tokens: root.tokens
                    startIconStyle: root.startIconStyle
                    onStartIconStyleChangedRequested: style => root.startIconStyleChangedRequested(style)
                    preferredTerminal: root.preferredTerminal
                    preferredFileManager: root.preferredFileManager
                    onPreferredTerminalChangedRequested: terminalId => root.preferredTerminalChangedRequested(terminalId)
                    onPreferredFileManagerChangedRequested: fileManagerId => root.preferredFileManagerChangedRequested(fileManagerId)
                }
            }
            SettingsScroll {
                IslandPage {
                    width: parent.width
                    tokens: root.tokens
                    islandRotationEnabled: root.islandRotationEnabled
                    islandRotationSeconds: root.islandRotationSeconds
                    weatherCity: root.weatherCity
                    weatherRefreshMinutes: root.weatherRefreshMinutes
                    onIslandRotationEnabledChangedRequested: enabled => root.islandRotationEnabledChangedRequested(enabled)
                    onIslandRotationSecondsChangedRequested: seconds => root.islandRotationSecondsChangedRequested(seconds)
                    onWeatherCityChangedRequested: city => root.weatherCityChangedRequested(city)
                    onWeatherRefreshMinutesChangedRequested: minutes => root.weatherRefreshMinutesChangedRequested(minutes)
                }
            }
            SettingsScroll { LockScreenPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll {
                WindowsPage {
                    width: parent.width
                    tokens: root.tokens
                    niri: root.niri
                    niriConfig: niriConfig
                    animationsEnabled: root.animationsEnabled
                    onAnimationsRequested: root.openKey("appearance")
                    onAnimationsChangedRequested: enabled => root.animationsChangedRequested(enabled)
                }
            }
            SettingsScroll { AltTabPage { width: parent.width; tokens: root.tokens; niriConfig: niriConfig } }
            SettingsScroll { WorkspacesPage { width: parent.width; tokens: root.tokens; niri: root.niri } }
            SettingsScroll { DefaultsPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { AutostartPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll { UpdatesPage { width: parent.width; tokens: root.tokens; preferredTerminal: root.preferredTerminal; updateService: root.updateService } }
            SettingsScroll { AboutPage { width: parent.width; tokens: root.tokens } }
            SettingsScroll {
                IntegrationsPage {
                    width: parent.width
                    tokens: root.tokens
                    niriColorIntegration: root.niriColorIntegration
                    niriAccentError: root.niriAccentError
                    strataThemeIntegration: root.strataThemeIntegration
                    strataError: root.strataError
                    strataNotice: root.strataNotice
                    onNiriColorIntegrationChangedRequested: enabled => root.niriColorIntegrationChangedRequested(enabled)
                    onStrataThemeIntegrationChangedRequested: enabled => root.strataThemeIntegrationChangedRequested(enabled)
                }
            }
            NaomiSection { section: "overview"; activePage: 25 }
            NaomiSection { section: "look"; activePage: 26 }
            NaomiSection { section: "place"; activePage: 27 }
            SettingsScroll {
                CapturePage {
                    width: parent.width
                    tokens: root.tokens
                    values: root.captureSettings
                    onChanged: patch => root.captureSettingsChangedRequested(patch)
                }
            }
            NaomiSection { section: "remind"; activePage: 29 }
            SettingsScroll {
                NotificationsPage {
                    width: parent.width
                    tokens: root.tokens
                    notificationsEnabled: root.notificationsEnabled
                    onNotificationsEnabledChangedRequested: enabled => root.notificationsEnabledChangedRequested(enabled)
                    receptionEnabled: root.receptionEnabled
                    receptionAvailable: root.receptionAvailable
                    receptionError: root.receptionError
                    onReceptionChangedRequested: enabled => root.receptionChangedRequested(enabled)
                    sources: root.notificationSources
                    onSourceModeRequested: (key, mode) => root.sourceModeRequested(key, mode)
                    dndManual: root.dndManual
                    dndUntil: root.dndUntil
                    onDndUntilRequested: until => root.dndUntilRequested(until)
                    onDndManualRequested: root.dndManualRequested()
                    onDndClearRequested: root.dndClearRequested()
                }
            }
            SettingsScroll {
                PolkitPage {
                    width: parent.width
                    tokens: root.tokens
                    settings: root.settingsService
                    polkit: root.polkitService
                }
            }
            SettingsScroll {
                WidgetsPage {
                    width: parent.width
                    tokens: root.tokens
                    showHeading: false
                    desktopWidgets: root.settingsService ? root.settingsService.desktopWidgets : ({})
                    screens: Quickshell.screens
                    editing: root.widgetsEditing
                    onLayoutEdited: layout => { if (root.settingsService) root.settingsService.update({ desktopWidgets: layout }) }
                    onEditModeChanged: on => root.widgetsEditingRequested(on)
                }
            }
        }
        Rectangle {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: statusRow.implicitHeight + 24
            color: "transparent"
            Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
            RowLayout {
                id: statusRow
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 16 }
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    text: root.currentPage === 4 ? "Обои сохраняются после применения."
                          : root.settingsMessage ? root.settingsMessage
                          : root.persistsSettings ? "Изменения сохраняются автоматически." : ""
                    color: root.tokens.color.textMuted
                    font.pixelSize: 13
                    Accessible.role: Accessible.StaticText
                }
                Action {
                    visible: root.currentPage !== 4 && (root.canRecover || root.canRetry)
                    text: root.canRecover ? "Восстановить настройки" : "Повторить запись"
                    onClicked: root.canRecover ? root.recoverRequested() : root.retryRequested()
                }
            }
        }
    }
}
