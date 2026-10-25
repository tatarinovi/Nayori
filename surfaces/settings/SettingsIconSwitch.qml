pragma ComponentBehavior: Bound

import QtQuick

// Settings row: glyph, title, optional description and a pill switch on the right.
// With showSwitch: false the switch is replaced by a quiet status text (state that has no setting).
Rectangle {
    id: row
    required property var tokens
    property string text: ""
    property string description: ""
    property string glyph: ""
    property bool showSwitch: true
    property string status: ""
    property alias checked: control.checked
    readonly property bool hovered: control.visible && control.hovered
    readonly property bool visualFocus: control.visible && control.visualFocus
    signal clicked()
    signal focusReceived()

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(description.length > 0 ? 56 : 44, labels.implicitHeight + 20)
    radius: tokens.radius.small + 2
    color: Qt.alpha(tokens.color.text, hovered ? 0.08 : 0.05)
    border.width: visualFocus ? 1 : 0
    border.color: tokens.color.accent
    opacity: enabled ? 1 : 0.45

    // Whole row is the hit area; its own text stays empty, labels are drawn below.
    SettingsSwitch {
        id: control
        tokens: row.tokens
        visible: row.showSwitch
        anchors { fill: parent; rightMargin: 14 }
        text: ""
        background: Item {}
        Accessible.name: row.text
        Accessible.description: row.description
        onClicked: row.clicked()
        onFocusReceived: row.focusReceived()
    }

    SettingsNavGlyph {
        id: icon
        visible: row.glyph.length > 0
        name: row.glyph
        width: 20; height: 20
        ink: row.tokens.color.textMuted
        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
    }
    Text {
        id: statusText
        visible: !row.showSwitch && text.length > 0
        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        text: row.status
        color: row.tokens.color.textMuted
        font.family: row.tokens.type.small.family
        font.pixelSize: row.tokens.type.small.size - 1
        textFormat: Text.PlainText
    }
    Column {
        id: labels
        anchors {
            left: icon.visible ? icon.right : parent.left
            leftMargin: icon.visible ? 12 : 14
            right: row.showSwitch ? parent.right : (statusText.visible ? statusText.left : parent.right)
            rightMargin: row.showSwitch ? 14 + 40 + 12 : (statusText.visible ? 12 : 14)
            verticalCenter: parent.verticalCenter
        }
        spacing: 2
        Text {
            width: parent.width
            text: row.text
            color: row.tokens.color.text
            font.family: row.tokens.type.body.family
            font.pixelSize: row.tokens.type.small.size
            font.weight: row.tokens.type.body.weight
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeight: 1.25
        }
        Text {
            visible: row.description.length > 0
            width: parent.width
            text: row.description
            color: row.tokens.color.textMuted
            font.family: row.tokens.type.small.family
            font.pixelSize: row.tokens.type.small.size - 1
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
    }
}
