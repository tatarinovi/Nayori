pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../services/system"

FocusScope {
    id: root
    property bool showHeading: true
    required property var tokens
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    property bool autoHideTop: false
    property bool autoHideApps: false
    property bool autoHideWorkspaces: false
    property bool autoHideStatus: false
    // Optional WallpaperManager: monitor tiles show the wallpaper of their output when it is given.
    property var wallpapers: null
    // Connected outputs; the first one is the primary, as everywhere else in the shell.
    property var screens: displays.screens
    property string selectedOutput: ""
    signal reservationChanged(int top, int bottom)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal hideSecondaryIslandChangedRequested(bool hidden)

    readonly property bool autoHideAny: autoHideTop || autoHideApps || autoHideWorkspaces || autoHideStatus
    readonly property var monitors: {
        const items = []
        const list = screens || []
        for (let i = 0; i < list.length; ++i) {
            const screen = list[i]
            if (!screen)
                continue
            const size = screen.width + " × " + screen.height
            items.push({
                name: screen.name || "Экран",
                detail: screen.model ? size + " · " + screen.model : size,
                primary: items.length === 0
            })
        }
        return items
    }
    readonly property string activeOutput: {
        for (const monitor of monitors)
            if (monitor.name === selectedOutput)
                return selectedOutput
        return monitors.length > 0 ? monitors[0].name : ""
    }
    readonly property bool wide: width >= 640 + 12

    component Label: SettingsLabel { tokens: root.tokens }
    component ReservationControl: SettingsReservationControl { tokens: root.tokens }

    function reveal(item) {
        if (!item || !item.visible)
            return
        const point = item.mapToItem(panelsColumn, 0, 0)
        const view = panelsFlick
        if (point.y < view.contentY)
            view.contentY = Math.max(0, point.y)
        else if (point.y + item.height > view.contentY + view.height)
            view.contentY = Math.min(Math.max(0, view.contentHeight - view.height), point.y + item.height - view.height)
    }
    function setAutoHide(top, apps, workspaces, status) {
        root.autoHideChangedRequested(top, apps, workspaces, status)
    }

    DisplayList { id: displays }

    // The page fills whatever the host gives it and never reports a size of its own,
    // so content height cannot feed back into the layout. Only this Flickable scrolls.
    Flickable {
        id: panelsFlick
        objectName: "settings-panels-scroll"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: panelsColumn.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 6
            contentItem: Rectangle {
                implicitWidth: 4
                implicitHeight: 32
                radius: 2
                color: root.tokens.color.accentSoft
            }
        }
        Column {
            id: panelsColumn
            width: panelsFlick.width - 12
            spacing: 12
            Label { visible: root.showHeading; text: "Панель задач"; font.family: root.tokens.type.display.family; font.pixelSize: 20 }

            SettingsCard {
                objectName: "panels-general"
                tokens: root.tokens
                title: "Общие параметры"
                subtitle: "Настройте поведение панели задач и расстояние от краёв экрана."

                SettingsIconSwitch {
                    objectName: "panels-autohide"
                    tokens: root.tokens
                    glyph: "autohide"
                    text: "Автоскрытие при пересечении с окном"
                    description: "Остров скрывается, когда окно пересекает его."
                    checked: root.autoHideAny
                    onClicked: root.setAutoHide(checked, checked, checked, checked)
                    onFocusReceived: root.reveal(this)
                }
                Column {
                    width: parent.width
                    leftPadding: 14
                    rightPadding: 14
                    spacing: 8
                    Label {
                        width: parent.width - 28
                        text: "Какие острова скрывать"
                        color: root.tokens.color.textMuted
                        font.pixelSize: root.tokens.type.small.size - 1
                    }
                    Flow {
                        width: parent.width - 28
                        spacing: 8
                        SettingsChip {
                            objectName: "panels-autohide-top"
                            tokens: root.tokens
                            text: "Верхний остров"
                            checked: root.autoHideTop
                            onClicked: root.setAutoHide(checked, root.autoHideApps, root.autoHideWorkspaces, root.autoHideStatus)
                            onFocusReceived: root.reveal(this)
                        }
                        SettingsChip {
                            objectName: "panels-autohide-apps"
                            tokens: root.tokens
                            text: "Док приложений"
                            checked: root.autoHideApps
                            onClicked: root.setAutoHide(root.autoHideTop, checked, root.autoHideWorkspaces, root.autoHideStatus)
                            onFocusReceived: root.reveal(this)
                        }
                        SettingsChip {
                            objectName: "panels-autohide-workspaces"
                            tokens: root.tokens
                            text: "Рабочие столы"
                            checked: root.autoHideWorkspaces
                            onClicked: root.setAutoHide(root.autoHideTop, root.autoHideApps, checked, root.autoHideStatus)
                            onFocusReceived: root.reveal(this)
                        }
                        SettingsChip {
                            objectName: "panels-autohide-status"
                            tokens: root.tokens
                            text: "Системный остров"
                            checked: root.autoHideStatus
                            onClicked: root.setAutoHide(root.autoHideTop, root.autoHideApps, root.autoHideWorkspaces, checked)
                            onFocusReceived: root.reveal(this)
                        }
                    }
                }
                // Revealing a hidden island on pointer approach is part of auto-hide, not a separate setting.
                SettingsIconSwitch {
                    objectName: "panels-hover-reveal"
                    tokens: root.tokens
                    glyph: "pointer"
                    text: "Показывать при наведении к краю"
                    description: "Временно показывать скрытый остров при наведении указателя."
                    showSwitch: false
                    status: "Всегда"
                    opacity: root.autoHideAny ? 1 : 0.55
                }
                SettingsInfoRow {
                    tokens: root.tokens
                    text: "Если Niri не передаёт положение окна, действует обычное автоскрытие."
                }
                Rectangle { width: parent.width; height: 1; color: root.tokens.color.border }
                Column {
                    width: parent.width
                    leftPadding: 14
                    rightPadding: 14
                    spacing: 8
                    ReservationControl { width: parent.width - 28; label: "Сверху"; reserved: root.topReserved; onFocusReceived: root.reveal(this); onAdjusted: function(amount) { root.reservationChanged(amount, root.bottomReserved) } }
                    ReservationControl { width: parent.width - 28; label: "Снизу"; reserved: root.bottomReserved; onFocusReceived: root.reveal(this); onAdjusted: function(amount) { root.reservationChanged(root.topReserved, amount) } }
                    Flow {
                        width: parent.width - 28
                        spacing: 8
                        SettingsButton { tokens: root.tokens; primary: true; text: "По размеру панелей"; onClicked: root.reservationChanged(64, 72); onActiveFocusChanged: if (activeFocus) root.reveal(this) }
                        SettingsButton { tokens: root.tokens; text: "Сбросить"; onClicked: root.reservationChanged(0, 0); onActiveFocusChanged: if (activeFocus) root.reveal(this) }
                    }
                }
            }

            SettingsCard {
                objectName: "panels-monitors"
                tokens: root.tokens
                title: "Мониторы"
                subtitle: "Что показывается на каждом мониторе. Верхний остров на втором экране можно отключить."
                spacing: 12

                Label {
                    visible: root.monitors.length === 0
                    width: parent.width
                    text: "Подключённых экранов нет"
                    color: root.tokens.color.textMuted
                    font.pixelSize: root.tokens.type.small.size
                }
                Item {
                    id: tileArea
                    visible: root.monitors.length > 0
                    width: parent.width
                    height: tileFlow.height
                    readonly property int gap: 12
                    readonly property int columns: Math.max(1, Math.min(root.monitors.length, Math.floor((width + gap) / (150 + gap))))
                    readonly property real tileWidth: Math.min(220, (width - gap * (columns - 1)) / columns)
                    Flow {
                        id: tileFlow
                        spacing: tileArea.gap
                        width: tileArea.columns * tileArea.tileWidth + (tileArea.columns - 1) * tileArea.gap
                        x: Math.max(0, (tileArea.width - width) / 2)
                        Repeater {
                            model: root.monitors
                            delegate: PanelsMonitorTile {
                                id: tile
                                required property var modelData
                                objectName: "panels-tile-" + modelData.name
                                tokens: root.tokens
                                width: tileArea.tileWidth
                                height: Math.round(tileArea.tileWidth * 0.42)
                                outputName: modelData.name
                                primary: modelData.primary
                                selected: modelData.name === root.activeOutput
                                source: root.wallpapers ? root.wallpapers.wallpaper(modelData.name).source : ""
                                onClicked: root.selectedOutput = modelData.name
                                onFocusReceived: root.reveal(this)
                            }
                        }
                    }
                }
                Grid {
                    id: cards
                    visible: root.monitors.length > 0
                    width: parent.width
                    spacing: 12
                    columns: root.wide ? Math.max(1, Math.min(2, root.monitors.length)) : 1
                    Repeater {
                        model: root.monitors
                        delegate: PanelsMonitorCard {
                            id: monitorCard
                            required property var modelData
                            objectName: "panels-monitor-" + modelData.name
                            tokens: root.tokens
                            // Narrow pages show only the monitor chosen in the tiles.
                            visible: root.wide || modelData.name === root.activeOutput
                            width: (cards.width - cards.spacing * (cards.columns - 1)) / cards.columns
                            outputName: modelData.name
                            detail: modelData.detail
                            primary: modelData.primary
                            selected: root.monitors.length > 1 && modelData.name === root.activeOutput
                            topSwitchable: !modelData.primary
                            topShown: modelData.primary || !root.hideSecondaryIsland
                            autoHideTop: root.autoHideTop
                            autoHideApps: root.autoHideApps
                            autoHideWorkspaces: root.autoHideWorkspaces
                            autoHideStatus: root.autoHideStatus
                            onTopShownRequested: shown => root.hideSecondaryIslandChangedRequested(!shown)
                            onItemFocused: item => root.reveal(item)
                        }
                    }
                }
                SettingsInfoRow {
                    tokens: root.tokens
                    text: root.monitors.length > 1
                        ? "Скрыть можно только верхний остров на втором экране. Остальные острова показываются на каждом мониторе, а автоскрытие задаётся в общих параметрах."
                        : "Все острова показываются на подключённом мониторе. Автоскрытие задаётся в общих параметрах."
                }
            }
        }
    }
}
