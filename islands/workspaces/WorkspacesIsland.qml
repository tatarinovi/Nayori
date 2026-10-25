import QtQuick
import "../../services/niri"

// Тело острова рабочих столов. Окно панели сюда не входит.
// Высота 40 и радиус 14 совпадают с DockIsland в shell.qml: шаг 8 вокруг ячейки 24, радиус 6+8.
Rectangle {
    id: root

    required property var tokens
    property string outputName: ""

    readonly property int pad: tokens.spacing.small
    readonly property string chosenOutput: outputName ? outputName : Niri.focusedOutput
    readonly property var shown: {
        var available = Niri.available
        var source = Niri.workspaces
        var chosen = chosenOutput
        if (!available || !source || source.length === undefined)
            return []
        var list = []
        for (var i = 0; i < source.length; ++i) {
            var workspace = source[i]
            if (!workspace)
                continue
            if (String(workspace.output || "") !== chosen)
                continue
            list.push(workspace)
        }
        list.sort(function (a, b) {
            return a.idx - b.idx
        })
        return list
    }

    implicitWidth: cluster.implicitWidth + pad * 2
    implicitHeight: tokens.spacing.large + pad * 2
    width: implicitWidth
    height: implicitHeight
    radius: tokens.radius.small + pad
    color: tokens.color.surfaceAlt
    border.width: 1
    border.color: tokens.color.border
    antialiasing: true

    Row {
        id: cluster
        anchors.centerIn: parent
        spacing: tokens.spacing.small

        // Нет сокета или на этом выходе нет столов. Не кнопки и не ряд цифр.
        Item {
            visible: root.shown.length === 0
            width: root.tokens.spacing.large
            height: root.tokens.spacing.large

            Rectangle {
                anchors.centerIn: parent
                width: root.tokens.spacing.medium
                height: 4
                radius: 2
                color: root.tokens.color.accentSoft
                antialiasing: true
            }
        }

        Repeater {
            model: root.shown

            delegate: Item {
                required property var modelData

                width: root.tokens.spacing.large
                height: root.tokens.spacing.large

                Rectangle {
                    anchors.fill: parent
                    visible: modelData.active === true
                    radius: root.tokens.radius.small
                    color: root.tokens.color.surface
                    antialiasing: true
                }

                Text {
                    anchors.centerIn: parent
                    text: String(modelData.idx)
                    color: modelData.active === true ? root.tokens.color.text : root.tokens.color.textMuted
                    font.family: root.tokens.type.body.family
                    font.pixelSize: root.tokens.type.body.size
                    font.weight: root.tokens.type.body.weight
                    font.letterSpacing: root.tokens.type.body.letterSpacing
                    font.features: ({ "tnum": 1, "lnum": 1 })
                    lineHeight: root.tokens.type.body.lineHeight
                    lineHeightMode: Text.ProportionalHeight
                    renderType: Text.NativeRendering
                    textFormat: Text.PlainText
                }

                Rectangle {
                    visible: modelData.urgent === true
                    width: 5
                    height: 5
                    radius: width / 2
                    anchors.top: parent.top
                    anchors.right: parent.right
                    color: root.tokens.color.secondary
                    antialiasing: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData)
                            Niri.focusWorkspace(modelData.id)
                    }
                }
            }
        }
    }
}
