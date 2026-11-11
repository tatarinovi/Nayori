import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    readonly property var nayoriStyledToolTipContent: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    required property string text
    property bool shown: false
    property string position: "bottom" // "bottom", "top", "left", "right"
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipTextObject.font
    implicitWidth: tooltipTextObject.implicitWidth + 2 * root.horizontalPadding
    implicitHeight: tooltipTextObject.implicitHeight + 2 * root.verticalPadding

    property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle
        // Grow from the edge nearest to the anchor
        x: root.position === "left" ? root.implicitWidth - implicitWidth
         : root.position === "right" ? 0
         : (root.implicitWidth - implicitWidth) / 2
        y: root.position === "top" ? root.implicitHeight - implicitHeight
         : root.position === "bottom" ? 0
         : (root.implicitHeight - implicitHeight) / 2
        color: nayoriStyledToolTipContent.appearance.regaliaEverywhere ? "transparent"
             : nayoriStyledToolTipContent.appearance.angelEverywhere ? nayoriStyledToolTipContent.appearance.angel.colGlassTooltip
             : nayoriStyledToolTipContent.appearance.inirEverywhere ? nayoriStyledToolTipContent.appearance.inir.colLayer2
             : nayoriStyledToolTipContent.appearance.auroraEverywhere ? nayoriStyledToolTipContent.appearance.aurora.colTooltipSurface
             : nayoriStyledToolTipContent.appearance.colors.colLayer3
        radius: nayoriStyledToolTipContent.appearance.regaliaEverywhere ? nayoriStyledToolTipContent.appearance.regalia.roundSmall
             : nayoriStyledToolTipContent.appearance.angelEverywhere ? nayoriStyledToolTipContent.appearance.angel.roundingSmall
             : nayoriStyledToolTipContent.appearance.inirEverywhere ? nayoriStyledToolTipContent.appearance.inir.roundingNormal
             : nayoriStyledToolTipContent.appearance.rounding.verysmall
        border.width: nayoriStyledToolTipContent.appearance.regaliaEverywhere ? 0
             : nayoriStyledToolTipContent.appearance.angelEverywhere ? nayoriStyledToolTipContent.appearance.angel.cardBorderWidth : 1
        border.color: nayoriStyledToolTipContent.appearance.angelEverywhere ? nayoriStyledToolTipContent.appearance.angel.colBorderSubtle
                    : nayoriStyledToolTipContent.appearance.inirEverywhere ? nayoriStyledToolTipContent.appearance.inir.colBorder
                    : nayoriStyledToolTipContent.appearance.auroraEverywhere ? nayoriStyledToolTipContent.appearance.aurora.colTooltipBorder
                    : nayoriStyledToolTipContent.appearance.colors.colLayer3Hover
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.94
        transformOrigin: root.position === "top" ? Item.Bottom
                       : root.position === "left" ? Item.Right
                       : root.position === "right" ? Item.Left
                       : Item.Top
        implicitWidth: shown ? (tooltipTextObject.implicitWidth + 2 * root.horizontalPadding) : 0
        implicitHeight: shown ? (tooltipTextObject.implicitHeight + 2 * root.verticalPadding) : 0
        clip: true

        Behavior on opacity {
            enabled: nayoriStyledToolTipContent.appearance.animationsEnabled
            NumberAnimation { duration: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.duration; easing.type: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on scale {
            enabled: nayoriStyledToolTipContent.appearance.animationsEnabled
            NumberAnimation { duration: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.duration; easing.type: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitWidth {
            enabled: nayoriStyledToolTipContent.appearance.animationsEnabled
            NumberAnimation { duration: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.duration; easing.type: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: nayoriStyledToolTipContent.appearance.animationsEnabled
            NumberAnimation { duration: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.duration; easing.type: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriStyledToolTipContent.appearance.animation.elementMoveFast.bezierCurve }
        }

        RegaliaPlate {
            anchors.fill: parent
            visible: nayoriStyledToolTipContent.appearance.regaliaEverywhere
            fillColor: nayoriStyledToolTipContent.appearance.regalia.bg3
            radius: backgroundRectangle.radius
            inset: nayoriStyledToolTipContent.appearance.regalia.controlInset
            elevated: true
        }

        AngelPartialBorder {
            targetRadius: backgroundRectangle.radius
            coverage: 0.45
        }

        StyledText {
            id: tooltipTextObject
            anchors.centerIn: parent
            text: root.text
            font.pixelSize: nayoriStyledToolTipContent.appearance.font.pixelSize.smaller
            font.hintingPreference: Font.PreferNoHinting // Prevent shaky text
            color: nayoriStyledToolTipContent.appearance.regaliaEverywhere ? nayoriStyledToolTipContent.appearance.regalia.onColor
                : nayoriStyledToolTipContent.appearance.angelEverywhere ? nayoriStyledToolTipContent.appearance.angel.colText
                : nayoriStyledToolTipContent.appearance.inirEverywhere ? nayoriStyledToolTipContent.appearance.inir.colText
                : nayoriStyledToolTipContent.appearance.colors.colOnLayer3
            wrapMode: Text.Wrap
        }
    }   
}

