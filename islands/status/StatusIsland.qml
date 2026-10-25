import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../../services/status"

// Содержимое правого острова. Окна слоя здесь нет.
// Высота 40 и радиус 14: шаг 8 вокруг строки 24, радиус 6+8.
Rectangle {
    id: root

    required property var tokens
    property var menuWindow: null

    readonly property int pad: tokens.spacing.small

    implicitWidth: cluster.implicitWidth + pad * 2
    implicitHeight: tokens.spacing.large + pad * 2
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + pad
    color: tokens.color.surfaceAlt
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    Audio {
        id: audio
    }

    Network {
        id: network
    }

    Tray {
        id: tray
    }

    function openTrayMenu(entry, anchor) {
        if (!entry || entry.hasMenu !== true)
            return
        var win = menuWindow
        var x = 0
        var y = 0
        if (!win && anchor && anchor.Window)
            win = anchor.Window.window
        if (!win)
            return
        if (win.contentItem && anchor) {
            var point = anchor.mapToItem(win.contentItem, 0, 0)
            if (point) {
                x = Math.round(point.x)
                y = Math.round(point.y)
            }
        }
        entry.display(win, x, y)
    }

    SystemClock {
        id: clock
        enabled: true
        precision: SystemClock.Minutes
    }

    component StatusText: Text {
        property var role: root.tokens.type.body
        color: root.tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.letterSpacing
        lineHeight: role.lineHeight
        lineHeightMode: Text.ProportionalHeight
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }

    // Слоты сами стоят в ряд. Скрытый индикатор не оставляет зазор.
    Item {
        id: cluster
        anchors.centerIn: parent
        implicitWidth: clockSlot.x + clockSlot.width
        implicitHeight: tokens.spacing.large
        width: implicitWidth
        height: implicitHeight

        readonly property real gap: tokens.spacing.medium

        Item {
            id: traySlot
            visible: tray.available && trayIcons.count > 0
            width: visible ? trayRow.implicitWidth : 0
            height: tokens.spacing.large

            Row {
                id: trayRow
                height: parent.height
                spacing: root.tokens.spacing.small

                Repeater {
                    id: trayIcons
                    model: tray.available ? SystemTray.items : null

                    delegate: Item {
                        id: trayIcon

                        required property var modelData

                        readonly property string iconSource: modelData && modelData.icon ? String(modelData.icon) : ""
                        readonly property string iconName: {
                            var title = modelData ? (modelData.title || modelData.id || "") : ""
                            var text = String(title).trim()
                            return text.length > 0 ? text.charAt(0).toUpperCase() : ""
                        }
                        readonly property bool needsAttention: !!(modelData && modelData.status === Status.NeedsAttention)

                        width: root.tokens.spacing.large
                        height: root.tokens.spacing.large

                        Accessible.role: Accessible.Button
                        Accessible.name: modelData
                                          ? String(modelData.title || modelData.tooltipTitle || modelData.id || "")
                                          : ""

                        Rectangle {
                            anchors.fill: parent
                            visible: trayIcon.needsAttention
                            radius: root.tokens.radius.small
                            color: "transparent"
                            border.width: 1
                            border.color: root.tokens.color.secondary
                            antialiasing: true
                        }

                        IconImage {
                            id: trayImage
                            anchors.centerIn: parent
                            implicitSize: root.tokens.spacing.medium
                            width: implicitSize
                            height: implicitSize
                            visible: trayIcon.iconSource !== "" && status !== Image.Error
                            source: trayIcon.iconSource
                            asynchronous: true
                            mipmap: true
                        }

                        StatusText {
                            visible: !trayImage.visible && trayIcon.iconName !== ""
                            anchors.centerIn: parent
                            text: trayIcon.iconName
                            color: root.tokens.color.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                var entry = trayIcon.modelData
                                if (!entry)
                                    return
                                if (mouse.button === Qt.MiddleButton) {
                                    entry.secondaryActivate()
                                    return
                                }
                                if (mouse.button === Qt.RightButton) {
                                    if (entry.hasMenu)
                                        root.openTrayMenu(entry, trayIcon)
                                    else
                                        entry.secondaryActivate()
                                    return
                                }
                                if (entry.onlyMenu)
                                    root.openTrayMenu(entry, trayIcon)
                                else
                                    entry.activate()
                            }
                            onWheel: function (wheel) {
                                var entry = trayIcon.modelData
                                if (!entry)
                                    return
                                if (wheel.angleDelta.y !== 0)
                                    entry.scroll(wheel.angleDelta.y, false)
                                else if (wheel.angleDelta.x !== 0)
                                    entry.scroll(wheel.angleDelta.x, true)
                            }
                        }
                    }
                }
            }
        }

        Loader {
            id: networkSlot
            x: traySlot.visible ? traySlot.width + cluster.gap : 0
            active: network.available && network.label !== ""
            visible: item !== null
            width: item ? item.width : 0
            height: item ? item.height : 0
            sourceComponent: networkMark
        }

        Loader {
            id: audioSlot
            x: networkSlot.visible
               ? networkSlot.x + networkSlot.width + cluster.gap
               : (traySlot.visible ? traySlot.width + cluster.gap : 0)
            active: audio.available && audio.label !== ""
            visible: item !== null
            width: item ? item.width : 0
            height: item ? item.height : 0
            sourceComponent: audioMark
        }

        Item {
            id: clockSlot
            x: audioSlot.visible
               ? audioSlot.x + audioSlot.width + cluster.gap
               : (networkSlot.visible
                  ? networkSlot.x + networkSlot.width + cluster.gap
                  : (traySlot.visible ? traySlot.width + cluster.gap : 0))
            width: clockText.implicitWidth
            height: tokens.spacing.large

            StatusText {
                id: clockText
                anchors.centerIn: parent
                text: Qt.formatTime(clock.date, "HH:mm")
                font.features: ({ "tnum": 1, "lnum": 1 })
            }
        }
    }

    Component {
        id: networkMark

        Item {
            width: networkText.implicitWidth
            height: root.tokens.spacing.large

            StatusText {
                id: networkText
                anchors.centerIn: parent
                text: network.label
                color: network.degraded
                      ? root.tokens.color.secondary
                      : (network.linked ? root.tokens.color.text : root.tokens.color.textMuted)
            }
        }
    }

    Component {
        id: audioMark

        Item {
            width: Math.max(audioText.implicitWidth, root.tokens.spacing.large)
            height: root.tokens.spacing.large

            StatusText {
                id: audioText
                anchors.centerIn: parent
                text: audio.label
                color: audio.muted ? root.tokens.color.secondary : root.tokens.color.text
                font.features: ({ "tnum": 1, "lnum": 1 })
            }

            MouseArea {
                anchors.fill: parent
                enabled: audio.available
                cursorShape: Qt.PointingHandCursor
                onClicked: audio.toggleMuted()
            }
        }
    }
}
