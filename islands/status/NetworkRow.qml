pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var tokens
    property string detail: ""
    property string glyph: ""
    property string actionText: ""
    property bool selected: false
    property bool actionable: true
    property bool secured: false
    property real strength: 1
    property bool keyboardPress: false
    signal invoked(bool keyboard)
    implicitHeight: detail ? 54 : 40
    implicitWidth: 300
    focusPolicy: actionable ? Qt.StrongFocus : Qt.NoFocus
    hoverEnabled: actionable
    Accessible.role: actionable ? Accessible.Button : Accessible.StaticText
    Accessible.name: text + (detail ? ", " + detail : "") + (actionText ? ", " + actionText : "")
    opacity: enabled ? 1 : 0.5
    scale: actionable && down && !tokens.motion.off && !keyboardPress ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: root.tokens.motion.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: root.tokens.motion.easeOut } }
    Keys.onPressed: event => {
        if (!actionable) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            keyboardPress = true
            invoked(true)
            event.accepted = true
        }
    }
    onClicked: { keyboardPress = false; if (actionable) invoked(false) }
    onActiveFocusChanged: {
        if (!activeFocus) return
        for (let view = parent; view; view = view.parent) {
            if (view.contentY === undefined || !view.contentItem) continue
            const point = root.mapToItem(view.contentItem, 0, 0)
            view.contentY = Math.max(0, Math.min(view.contentHeight - view.height,
                point.y < view.contentY ? point.y : Math.max(view.contentY, point.y + height - view.height)))
            break
        }
    }
    background: Rectangle {
        radius: root.tokens.radius.small
        color: root.actionable && root.down ? root.tokens.color.surfaceAlt : root.selected ? Qt.alpha(root.tokens.color.accent, 0.10)
            : root.hovered ? Qt.alpha(root.tokens.color.text, 0.05) : "transparent"
        border.width: root.visualFocus ? 1 : 0
        border.color: root.tokens.color.accent
        Rectangle {
            visible: root.selected
            x: 0; y: 8; width: 3; height: parent.height - 16; radius: 1.5
            color: root.tokens.color.accent
        }
    }
    contentItem: Item {
        NetworkGlyph {
            id: icon
            visible: root.glyph !== ""
            name: root.glyph
            strength: root.strength
            x: 10; anchors.verticalCenter: parent.verticalCenter
            ink: root.selected ? root.tokens.color.accent : root.tokens.color.textMuted
        }
        Column {
            x: root.glyph ? 42 : 12
            width: Math.max(0, rightCaption.x - x - 10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width
                text: root.text
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.tokens.color.text
                font { family: root.tokens.type.body.family; pixelSize: 13; weight: root.selected ? 600 : 500 }
            }
            Text {
                visible: root.detail !== ""
                width: parent.width
                text: root.detail
                textFormat: Text.PlainText
                elide: Text.ElideRight
                color: root.tokens.color.textMuted
                font { family: root.tokens.type.body.family; pixelSize: 12 }
            }
        }
        Row {
            id: rightCaption
            anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 8
            NetworkGlyph { visible: root.secured; name: "lock"; width: 14; height: 14; ink: root.tokens.color.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text {
                visible: root.actionText !== ""
                text: root.actionText
                textFormat: Text.PlainText
                color: root.tokens.color.accent
                font { family: root.tokens.type.body.family; pixelSize: 11 }
                anchors.verticalCenter: parent.verticalCenter
            }
            NetworkGlyph {
                visible: root.selected && !root.actionText
                name: "check"; width: 16; height: 16; ink: root.tokens.color.accent
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
