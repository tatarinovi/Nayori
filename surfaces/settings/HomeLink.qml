pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var tokens
    property string title: ""
    property string detail: ""
    property string glyph: "appearance"
    property url artwork
    property bool compact: false
    signal revealRequested(var item)
    property int minimumHeight: compact ? 80 : 112
    implicitHeight: compact
        ? Math.max(minimumHeight, padding * 2 + Math.max(icon.height, titleLabel.implicitHeight + (detail ? detailLabel.implicitHeight + 4 : 0)))
        : Math.max(minimumHeight, padding * 2 + icon.height + 8 + titleLabel.implicitHeight)
    padding: compact ? 14 : 18
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.name: title + (detail ? ", " + detail : "")
    onActiveFocusChanged: if (activeFocus) revealRequested(root)
    background: Rectangle {
        radius: root.tokens.radius.medium
        color: root.tokens.material.sidebar
        HomeArtwork { anchors.fill: parent; source: root.artwork; cornerRadius: parent.radius; opacity: 0.4 }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.tokens.color.background
            opacity: root.down ? 0.82 : root.hovered ? 0.45 : 0.65
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
            objectName: "home-link-icon"
            width: 23; height: 23
            ink: root.tokens.color.accent
            name: root.glyph
            anchors { left: parent.left; top: root.compact ? undefined : parent.top; verticalCenter: root.compact ? parent.verticalCenter : undefined }
        }
        SettingsLabel {
            id: titleLabel
            objectName: "home-link-title"
            tokens: root.tokens
            anchors { left: root.compact ? icon.right : parent.left; leftMargin: root.compact ? 12 : 0; right: arrow.left; rightMargin: 8; bottom: root.compact && !root.detail ? undefined : parent.bottom; verticalCenter: root.compact && !root.detail ? parent.verticalCenter : undefined }
            text: root.title
            font.pixelSize: root.compact ? 14 : 15
            wrapMode: Text.WordWrap
        }
        SettingsLabel {
            id: detailLabel
            visible: root.compact && !!root.detail
            tokens: root.tokens
            anchors { left: icon.right; leftMargin: 12; right: arrow.left; top: parent.top }
            text: root.detail
            color: root.tokens.color.accent
            font.pixelSize: 11
        }
        SettingsLabel {
            id: arrow
            objectName: "home-link-arrow"
            tokens: root.tokens
            anchors { right: parent.right; bottom: root.compact ? undefined : parent.bottom; verticalCenter: root.compact ? parent.verticalCenter : undefined }
            text: "›"
            lineHeight: 1
            font.pixelSize: 24
            color: root.tokens.color.accent
        }
    }
}
