//@ pragma UseQApplication

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "tokens"
import "services/niri"
import "islands/workspaces"
import "islands/apps"
import "islands/status"

ShellRoot {
    id: root

    Tokens {
        id: tokens
    }

    // Чтение свойства создаёт синглтон и открывает поток событий.
    // FocusWorkspace и FocusWindow отсюда не вызываются.
    readonly property bool niriLive: Niri.available

    // У ShellScreen нет свойства фокуса. Окна остаются на первом экране.
    readonly property var probeScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    component ShellText: Text {
        property var role: tokens.type.body
        color: tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.letterSpacing
        lineHeight: role.lineHeight
        lineHeightMode: Text.ProportionalHeight
        renderType: Text.NativeRendering
        textFormat: Text.PlainText
    }

    // Окно ровно по острову. Второй хром вокруг компонента не рисуется.
    component IslandWindow: PanelWindow {
        id: dock

        required property string ns
        property int side: 0
        property Item island: null

        readonly property int pad: tokens.spacing.small

        screen: root.probeScreen
        visible: root.probeScreen !== null && island !== null
        color: "transparent"
        anchors.top: false
        anchors.bottom: true
        anchors.left: side < 0
        anchors.right: side > 0
        margins.bottom: pad
        margins.left: side < 0 ? tokens.spacing.large : 0
        margins.right: side > 0 ? tokens.spacing.large : 0
        implicitWidth: island ? island.implicitWidth : 0
        implicitHeight: island ? island.implicitHeight : 0
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: ns
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: dock.island
            radius: dock.island ? Math.round(dock.island.radius) : 0
        }
    }

    PanelWindow {
        id: islandWindow
        screen: root.probeScreen
        visible: root.probeScreen !== null
        color: "transparent"
        anchors.top: true
        anchors.bottom: false
        anchors.left: false
        anchors.right: false
        margins.top: tokens.spacing.small
        implicitWidth: capsule.implicitWidth + tokens.spacing.medium * 2
        implicitHeight: capsule.implicitHeight + tokens.spacing.medium
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nayori-probe-island"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Маска совпадает с капсулой: тень и пустые поля клики не забирают.
        mask: Region {
            item: capsule
            radius: Math.round(capsule.radius)
        }

        RectangularShadow {
            anchors.fill: capsule
            radius: capsule.radius
            blur: 16
            spread: 0
            offset: Qt.vector2d(0, 6)
            color: tokens.color.shadow
            z: -1
        }

        Rectangle {
            id: capsule
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: content.implicitWidth + tokens.spacing.medium * 2
            implicitHeight: content.implicitHeight + tokens.spacing.small * 2
            radius: Math.min(height / 2, tokens.radius.capsule)
            color: tokens.color.surfaceAlt
            border.width: 1
            border.color: tokens.color.border
            antialiasing: true

            Row {
                id: content
                anchors.centerIn: parent
                spacing: tokens.spacing.medium

                Item {
                    width: 13
                    height: words.implicitHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        radius: width / 2
                        color: "transparent"
                        border.width: 1
                        border.color: tokens.color.accentSoft
                        antialiasing: true
                    }

                    Rectangle {
                        id: presence
                        anchors.centerIn: parent
                        width: 6
                        height: 6
                        radius: width / 2
                        color: tokens.color.accent
                        antialiasing: true

                        // Присутствие, не ответ на действие. Только прозрачность,
                        // дольше обычного жеста, чтобы точка не мигала.
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true

                            NumberAnimation {
                                from: 0.78
                                to: 1
                                duration: tokens.motion.base * 12
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.77, 0.0, 0.175, 1.0, 1.0, 1.0]
                            }
                            NumberAnimation {
                                from: 1
                                to: 0.78
                                duration: tokens.motion.base * 12
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.77, 0.0, 0.175, 1.0, 1.0, 1.0]
                            }
                        }
                    }
                }

                Item {
                    id: words
                    width: implicitWidth
                    height: implicitHeight
                    implicitWidth: caption.x + caption.implicitWidth
                    implicitHeight: title.implicitHeight

                    ShellText {
                        id: title
                        text: "Nayori"
                        role: tokens.type.display
                        font.variableAxes: ({ "opsz": role.size })
                    }

                    Rectangle {
                        id: rule
                        x: title.implicitWidth + tokens.spacing.small
                        y: (parent.height - height) / 2
                        width: 2
                        height: Math.max(10, Math.round(title.implicitHeight * 0.62))
                        radius: 1
                        color: tokens.color.secondary
                        antialiasing: true
                    }

                    ShellText {
                        id: caption
                        x: rule.x + rule.width + tokens.spacing.small
                        anchors.baseline: title.baseline
                        text: "context layer"
                        role: tokens.type.small
                        color: tokens.color.textMuted
                    }
                }
            }
        }
    }

    IslandWindow {
        id: workspacesWindow
        ns: "nayori-workspaces"
        side: -1
        island: workspaces

        WorkspacesIsland {
            id: workspaces
            tokens: tokens
        }
    }

    IslandWindow {
        id: appsWindow
        ns: "nayori-apps"
        side: 0
        island: apps

        AppsIsland {
            id: apps
            tokens: tokens
        }
    }

    IslandWindow {
        id: statusWindow
        ns: "nayori-status"
        side: 1
        island: status

        StatusIsland {
            id: status
            tokens: tokens
            menuWindow: statusWindow
        }
    }
}
