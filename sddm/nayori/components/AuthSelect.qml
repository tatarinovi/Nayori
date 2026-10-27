import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    required property var colors
    implicitHeight: 44
    font.family: "Inter"
    font.pixelSize: 14
    focusPolicy: Qt.StrongFocus
    palette.text: colors.text
    palette.buttonText: colors.text
    palette.base: colors.background
    palette.window: colors.background
    palette.highlight: colors.accent
    palette.highlightedText: colors.accentText
    contentItem: Text {
        leftPadding: 14
        rightPadding: 34
        text: root.displayText
        textFormat: Text.PlainText
        font: root.font
        color: root.colors.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: root.width - width - 14
        anchors.verticalCenter: parent.verticalCenter
        text: "⌄"
        color: root.colors.textMuted
        font.pixelSize: 20
    }
    background: Rectangle {
        radius: 10
        color: root.colors.background
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? root.colors.accent : root.colors.border
    }
}
