import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick




Rectangle {
    readonly property var nayoriFaceChoice: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    signal clicked()

    implicitWidth: row.implicitWidth + Math.round(20 * nayoriFaceChoice.irisStyle.density)
    implicitHeight: Math.round(34 * nayoriFaceChoice.irisStyle.density)
    radius: height / 2
    color: root.selected ? nayoriFaceChoice.irisStyle.tintFill(nayoriFaceChoice.irisStyle.accent)
        : hover.hovered ? nayoriFaceChoice.irisStyle.fillHover : nayoriFaceChoice.irisStyle.fillQuiet
    border.width: root.selected ? 1 : 0
    border.color: nayoriFaceChoice.irisStyle.tintBorder(nayoriFaceChoice.irisStyle.accent)
    scale: tap.pressed ? nayoriFaceChoice.irisStyle.pressScale(0.97) : 1
    Behavior on color { ColorAnimation { duration: nayoriFaceChoice.irisStyle.feedbackDuration; easing.type: nayoriFaceChoice.irisStyle.feedbackEasing } }
    Behavior on scale { NumberAnimation { duration: nayoriFaceChoice.irisStyle.feedbackDuration; easing.type: nayoriFaceChoice.irisStyle.feedbackEasing } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Math.round(6 * nayoriFaceChoice.irisStyle.density)
        MaterialSymbol {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            fill: root.selected ? 1 : 0
            iconSize: 16 * nayoriFaceChoice.irisStyle.typeScale
            color: root.selected ? nayoriFaceChoice.irisStyle.accent : nayoriFaceChoice.irisStyle.textSecondary
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: nayoriFaceChoice.i18n.tr(root.label)
            color: root.selected ? nayoriFaceChoice.irisStyle.text : nayoriFaceChoice.irisStyle.textSecondary
            font.family: nayoriFaceChoice.irisStyle.fontMain
            font.pixelSize: nayoriFaceChoice.irisStyle.typeLabel
            font.weight: root.selected ? Font.DemiBold : Font.Medium
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: root.clicked() }
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.checked: root.selected
}
