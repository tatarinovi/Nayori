pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var tokens
    property string title
    property string detail
    property string glyph
    property url artwork
    signal revealRequested(var item)
    implicitHeight: 92
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: title + ", " + detail
    onActiveFocusChanged: if (activeFocus) revealRequested(root)
    background: Rectangle {
        radius: root.tokens.radius.medium
        color: root.tokens.material.sidebar
        HomeArtwork { anchors.fill: parent; source: root.artwork; cornerRadius: parent.radius; opacity: 0.12 }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.down || root.hovered ? root.tokens.color.surfaceAlt : "transparent"
            opacity: 0.4
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: root.visualFocus || root.hovered ? root.tokens.color.accent : root.tokens.color.border
        }
    }
    contentItem: Item {
        SettingsNavGlyph {
            id: icon
            width: 27; height: 27
            name: root.glyph
            ink: root.tokens.color.accent
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
        }
        Column {
            anchors { left: icon.right; leftMargin: 14; right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
            spacing: 3
            SettingsLabel {
                tokens: root.tokens; width: parent.width; text: root.title
                font.family: root.tokens.type.display.family; font.pixelSize: 18
                maximumLineCount: 1; elide: Text.ElideRight; wrapMode: Text.NoWrap
            }
            SettingsLabel {
                tokens: root.tokens; width: parent.width; text: root.detail
                color: root.tokens.color.textMuted; font.pixelSize: 12
                maximumLineCount: 2; elide: Text.ElideRight
            }
        }
        SettingsLabel {
            tokens: root.tokens; text: "›"; font.pixelSize: 24; color: root.tokens.color.accent
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
        }
    }
}
