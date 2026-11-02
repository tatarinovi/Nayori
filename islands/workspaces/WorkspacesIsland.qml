pragma ComponentBehavior: Bound

import QtQuick
import "../../services/niri"

// Quiet workspace track: the current desk expands, occupied desks stay visible.
Rectangle {
    id: root

    required property var tokens
    property string outputName: ""
    property var workspaceService: Niri

    readonly property string chosenOutput: outputName ? outputName : workspaceService.focusedOutput
    readonly property var shown: {
        var source = workspaceService.workspaces
        if (!workspaceService.available || !source || source.length === undefined)
            return []
        return source.filter(function (workspace) {
            return workspace && String(workspace.output || "") === root.chosenOutput
        }).sort(function (a, b) { return a.idx - b.idx })
    }
    readonly property int activeIndex: shown.findIndex(workspace => workspace.active === true)

    function windowCount(id) {
        return workspaceService.windows.filter(function (window) {
            return window.workspaceId === id
        }).length
    }

    function step(direction) {
        for (var i = 0; i < shown.length; ++i) {
            if (shown[i].active === true) {
                var next = i + direction
                if (next >= 0 && next < shown.length)
                    workspaceService.focusWorkspace(shown[next].id)
                return
            }
        }
    }

    implicitWidth: cluster.implicitWidth + 16
    implicitHeight: tokens.panel.height
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + 8
    color: tokens.material.panel
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    WheelHandler {
        onWheel: function (event) {
            var delta = event.angleDelta.y || event.angleDelta.x
            if (delta !== 0)
                root.step(delta < 0 ? 1 : -1)
            event.accepted = true
        }
    }

    Rectangle {
        id: activeMarker
        objectName: "workspace-active-marker"
        x: cluster.x + root.activeIndex * 30 + 2
        y: cluster.y + 12
        width: 24
        height: 8
        radius: 4
        z: 1
        visible: root.activeIndex >= 0
        color: root.tokens.color.accent
        Behavior on x {
            enabled: !root.tokens.motion.off && activeMarker.visible
            NumberAnimation {
                duration: root.tokens.motion.base
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.tokens.motion.easeOut
            }
        }
    }

    Row {
        id: cluster
        anchors.centerIn: parent
        spacing: 2

        Item {
            visible: root.shown.length === 0
            width: 28
            height: 32
            Rectangle {
                anchors.centerIn: parent
                width: 12
                height: 4
                radius: 2
                color: root.tokens.color.accentSoft
            }
        }

        Repeater {
            model: root.shown

            delegate: Item {
                id: desk
                required property var modelData
                readonly property bool current: modelData.active === true
                readonly property bool urgent: modelData.urgent === true
                readonly property int windows: root.windowCount(modelData.id)
                readonly property bool highlighted: pointer.containsMouse || activeFocus
                readonly property string description: "Workspace " + modelData.idx
                    + (modelData.name ? " · " + modelData.name : "")
                    + (current ? " · current" : "")
                    + (urgent ? " · needs attention" : "")
                    + " · " + windows + (windows === 1 ? " window" : " windows")

                width: 28
                height: 32
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: description
                Accessible.onPressAction: root.workspaceService.focusWorkspace(modelData.id)
                Keys.onReturnPressed: root.workspaceService.focusWorkspace(modelData.id)
                Keys.onSpacePressed: root.workspaceService.focusWorkspace(modelData.id)
                Keys.onLeftPressed: root.step(-1)
                Keys.onRightPressed: root.step(1)

                Rectangle {
                    anchors.fill: parent
                    radius: 16
                    color: desk.highlighted ? root.tokens.color.surface : "transparent"
                    border.width: desk.activeFocus ? 1 : 0
                    border.color: root.tokens.color.text
                    scale: pointer.pressed && !root.tokens.motion.off ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: root.tokens.motion.off ? 0 : 100; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !desk.current
                    width: desk.windows > 0 || desk.urgent ? 7 : 5
                    height: width
                    radius: width / 2
                    color: desk.urgent ? root.tokens.color.secondary
                        : desk.windows > 0 ? root.tokens.color.accent : "transparent"
                    border.width: desk.windows === 0 && !desk.urgent ? 1 : 0
                    border.color: root.tokens.color.textMuted
                    antialiasing: true
                }

                Rectangle {
                    visible: desk.urgent && (desk.current || desk.highlighted)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 4
                    height: 4
                    radius: 2
                    color: root.tokens.color.secondary
                }

                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.workspaceService.focusWorkspace(desk.modelData.id)
                }


            }
        }
    }
}
