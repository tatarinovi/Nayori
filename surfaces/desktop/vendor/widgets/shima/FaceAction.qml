import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick



Rectangle {
    readonly property var nayoriFaceAction: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    required property var face
    property string glyph: ""
    property string name: ""
    property color tint: root.face.ink
    property bool danger: false
    signal activated()

    implicitWidth: root.face.dp(32)
    implicitHeight: implicitWidth
    radius: height / 2
    color: hover.hovered ? (root.danger ? nayoriFaceAction.irisStyle.tintFill(root.face.danger) : root.face.fillHover) : root.face.fill
    scale: tap.pressed ? nayoriFaceAction.irisStyle.pressScale(0.94) : 1
    Behavior on color { ColorAnimation { duration: nayoriFaceAction.irisStyle.feedbackDuration; easing.type: nayoriFaceAction.irisStyle.feedbackEasing } }
    Behavior on scale { NumberAnimation { duration: nayoriFaceAction.irisStyle.feedbackDuration; easing.type: nayoriFaceAction.irisStyle.feedbackEasing } }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.glyph
        fill: 1
        iconSize: root.face.px(17)
        color: hover.hovered && root.danger ? root.face.danger : root.tint
    }
    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: root.activated() }
    Accessible.role: Accessible.Button
    Accessible.name: root.name
}
