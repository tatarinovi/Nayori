import QtQuick
Rectangle {
    required property var tokens
    radius: tokens.radius.medium
    color: Qt.alpha(tokens.color.surfaceAlt, 0.35)
}
