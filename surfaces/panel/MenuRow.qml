pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../islands/shared"

// Текстовая строка меню в том же размере, что и StatusButton.
Button {
    id: root

    required property var tokens
    property string subtitle: ""
    property string glyph: ""
    property bool showChevron: true
    property bool compact: false
    property bool emphasized: false
    property bool tile: false
    property bool iconOnly: false
    property bool frostedTile: false
    property url backdropSource: ""
    property real backgroundProgress: 0
    property real labelSize: tile ? 11 : tokens.type.body.size
    signal escapePressed()

    padding: 0
    implicitWidth: tokens.panel.control
    implicitHeight: iconOnly ? 40 : tile ? 58 : compact ? 34 : glyph ? 64 : tokens.panel.control
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: text
    PanelTooltip {
        tokens: root.tokens
        target: root
        hovered: root.iconOnly && root.visible && root.enabled && (root.hovered || root.visualFocus) && !root.down
        text: root.text
    }
    scale: down && !tokens.motion.off ? 0.96 : 1
    opacity: enabled ? 1 : 0.45
    Behavior on scale {
        NumberAnimation {
            duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast
            easing.type: Easing.OutCubic
        }
    }
    Keys.onEscapePressed: function(event) {
        root.escapePressed()
        event.accepted = true
    }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.down || root.checked ? root.tokens.color.accentSoft
              : root.emphasized ? Qt.alpha(root.tokens.color.accent, root.hovered || root.visualFocus ? 0.20 : 0.10)
              : root.frostedTile ? Qt.alpha(root.tokens.color.accent, root.hovered || root.visualFocus ? 0.26 : 0.14)
              : root.hovered || root.visualFocus ? root.tokens.color.surface : root.tile ? root.tokens.color.surfaceAlt : "transparent"
        border.width: root.visualFocus || root.frostedTile || root.emphasized ? 1 : 0
        border.color: root.visualFocus ? root.tokens.color.accent
            : root.emphasized ? Qt.alpha(root.tokens.color.accent, 0.25) : Qt.alpha(root.tokens.color.text, 0.18)
        Image {
            id: backdrop
            objectName: "menu-wallpaper-preview"
            anchors.fill: parent
            // A tiny decoded thumbnail also provides a soft software fallback.
            source: root.visible ? root.backdropSource : ""
            sourceSize: Qt.size(12, 8)
            asynchronous: true
            smooth: true
            fillMode: Image.PreserveAspectCrop
            visible: status === Image.Ready
            opacity: 0.65
            layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 32
                autoPaddingEnabled: false
                maskEnabled: true
                maskSource: backdropMask
            }
        }
        Rectangle {
            id: backdropMask
            width: backdrop.width; height: backdrop.height
            radius: root.tokens.radius.small
            color: "white"
            visible: false
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: backdrop.status === Image.Ready
            color: Qt.alpha(root.tokens.color.background, 0.32)
        }
        Rectangle {
            objectName: "menu-hold-fill"
            width: parent.width * root.backgroundProgress
            height: parent.height
            radius: parent.radius
            color: Qt.alpha(root.tokens.color.accent, 0.42)
            visible: root.backgroundProgress > 0
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: root.frostedTile
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(root.tokens.color.text, 0.09) }
                GradientStop { position: 1; color: Qt.alpha(root.tokens.color.text, 0.015) }
            }
        }
        Behavior on color { ColorAnimation { duration: root.tokens.motion.off ? 0 : root.tokens.motion.fast } }
    }
    contentItem: Item {
        Rectangle {
            x: root.tile ? (parent.width - width) / 2 : 10
            y: root.tile && !root.iconOnly ? 7 : (parent.height - height) / 2
            width: root.compact || root.tile ? 20 : 42
            height: width
            radius: root.tokens.radius.medium
            color: root.compact || root.tile ? "transparent" : root.tokens.color.surfaceAlt
            visible: root.glyph !== ""
            MenuGlyph {
                anchors.centerIn: parent
                width: root.compact || root.tile ? 18 : 23; height: width
                kind: root.glyph
                ink: root.tokens.color.menuIcon
            }
        }
        Column {
            visible: !root.iconOnly
            x: root.tile ? 2 : root.glyph ? (root.compact ? 38 : 68) : 10
            y: root.tile ? 32 : (parent.height - height) / 2
            width: parent.width - x - (root.tile ? 2 : root.glyph && root.showChevron ? 34 : 10)
            spacing: 4
            Text {
                width: parent.width
                text: root.text
                horizontalAlignment: root.tile ? Text.AlignHCenter : Text.AlignLeft
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.down || root.checked ? root.tokens.color.accentSoftText : root.tokens.color.text
                font.family: root.tokens.type.body.family
                font.pixelSize: root.labelSize
                font.weight: root.tokens.type.body.weight
            }
            Text {
                width: parent.width
                visible: root.subtitle !== ""
                text: root.subtitle
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: root.tokens.color.textMuted
                font.family: root.tokens.type.small.family
                font.pixelSize: root.tokens.type.small.size
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== "" && root.showChevron && !root.tile
            text: "›"
            color: root.tokens.color.accent
            font.pixelSize: 24
        }
    }
}
