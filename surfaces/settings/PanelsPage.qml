pragma ComponentBehavior: Bound

import QtQuick
import "../../services/ui/PanelModes.js" as PanelModes
import QtQuick.Controls
import "../../services/system"

FocusScope {
    id: root
    property bool showHeading: true
    required property var tokens
    property int topReserved: 0
    property int bottomReserved: 0
    property bool hideSecondaryIsland: false
    property string fullscreenIslandOutput: ""
    property var panelReservations: ({})
    property var panelModes: ({})
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
    signal panelReservationChangedRequested(string output, int top, int bottom)
    signal panelModeChangedRequested(string output, string part, string mode)
    signal autoHideChangedRequested(bool top, bool apps, bool workspaces, bool status)
    signal hideSecondaryIslandChangedRequested(bool hidden)
    signal fullscreenIslandOutputChangedRequested(string output)

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
                objectName: "panels-monitors"
                tokens: root.tokens
                title: "Мониторы"
                subtitle: "Выберите режим каждого элемента отдельно для каждого монитора."
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
                            topReserved: PanelModes.reservation(root.panelReservations, modelData.name, "top", root.topReserved)
                            bottomReserved: PanelModes.reservation(root.panelReservations, modelData.name, "bottom", root.bottomReserved)
                            onReservationRequested: (top, bottom) => root.panelReservationChangedRequested(modelData.name, top, bottom)
                            modes: ({
                                top: PanelModes.mode(root.panelModes, modelData.name, "top", root.autoHideTop, !modelData.primary && root.hideSecondaryIsland),
                                apps: PanelModes.mode(root.panelModes, modelData.name, "apps", root.autoHideApps, false),
                                workspaces: PanelModes.mode(root.panelModes, modelData.name, "workspaces", root.autoHideWorkspaces, false),
                                status: PanelModes.mode(root.panelModes, modelData.name, "status", root.autoHideStatus, false)
                            })
                            onModeRequested: (part, mode) => root.panelModeChangedRequested(modelData.name, part, mode)
                            onItemFocused: item => root.reveal(item)
                        }
                    }
                }
                SettingsInfoRow {
                    tokens: root.tokens
                    text: "Авто-скрытие плавно убирает элемент при пересечении с окном. Наведите указатель к краю экрана, чтобы показать его снова. Режим «Не отображать» отключает и показ при наведении."
                }
            }
        }
    }
}
