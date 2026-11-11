import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io





GroupButton {
    readonly property var nayoriSelectionGroupButton: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    horizontalPadding: SettingsMaterialPreset.unified ? 12
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlPaddingHorizontal : 11
    verticalPadding: SettingsMaterialPreset.unified ? 7
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlPaddingVertical : 6
    bounce: false
    property string buttonIcon
    property string buttonPreviewKind: ""
    property real maxTextWidth: 180
    property bool leftmost: false
    property bool rightmost: false
    readonly property bool showZzzPreview: nayoriSelectionGroupButton.appearance.zzzEverywhere && buttonPreviewKind.length > 0
    leftRadius: SettingsMaterialPreset.unified ? 8
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlRadius
        : nayoriSelectionGroupButton.appearance.zzzEverywhere ? nayoriSelectionGroupButton.appearance.zzz.controlRadius
        : nayoriSelectionGroupButton.appearance.editorialEverywhere
            ? ((toggled || leftmost) ? nayoriSelectionGroupButton.appearance.rounding.small : nayoriSelectionGroupButton.appearance.rounding.unsharpen)
        : (toggled || leftmost) ? (height / 2) : nayoriSelectionGroupButton.appearance.rounding.unsharpenmore
    rightRadius: SettingsMaterialPreset.unified ? 8
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlRadius
        : nayoriSelectionGroupButton.appearance.zzzEverywhere ? nayoriSelectionGroupButton.appearance.zzz.controlRadius
        : nayoriSelectionGroupButton.appearance.editorialEverywhere
            ? ((toggled || rightmost) ? nayoriSelectionGroupButton.appearance.rounding.small : nayoriSelectionGroupButton.appearance.rounding.unsharpen)
        : (toggled || rightmost) ? (height / 2) : nayoriSelectionGroupButton.appearance.rounding.unsharpenmore
    Behavior on leftRadius {
        enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
        animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementResize.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementResize.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementResize.bezierCurve }
    }
    Behavior on rightRadius {
        enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
        animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementResize.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementResize.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementResize.bezierCurve }
    }
    // ZZZ: idle segments are NEUTRAL plate, not bright secondary. Under zzz
    // colSecondaryContainer resolves to zzz.secondary (a signal) — using it for
    // the unselected base/hover made every segment glow and the hover glare.
    // Selected state stays the inherited GroupButton sticker (colBackgroundToggled).
    colBackground: SettingsMaterialPreset.unified ? nayoriSelectionGroupButton.appearance.colors.colLayer1
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlPlate
        : nayoriSelectionGroupButton.appearance.zzzEverywhere ? nayoriSelectionGroupButton.colorUtils.transparentize(nayoriSelectionGroupButton.appearance.colors.colLayer1Hover, 1)
        : nayoriSelectionGroupButton.appearance.angelEverywhere ? nayoriSelectionGroupButton.appearance.angel.colGlassCard
        : nayoriSelectionGroupButton.appearance.auroraEverywhere ? "transparent"
        : nayoriSelectionGroupButton.appearance.editorialEverywhere ? "transparent"
        : nayoriSelectionGroupButton.appearance.colors.colSecondaryContainer
    colBackgroundHover: SettingsMaterialPreset.unified ? nayoriSelectionGroupButton.appearance.colors.colLayer1Hover
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlPlateHover
        : nayoriSelectionGroupButton.appearance.zzzEverywhere ? nayoriSelectionGroupButton.appearance.colors.colLayer1Hover
        : nayoriSelectionGroupButton.appearance.angelEverywhere ? nayoriSelectionGroupButton.appearance.angel.colGlassCardHover
        : nayoriSelectionGroupButton.appearance.auroraEverywhere ? nayoriSelectionGroupButton.appearance.aurora.colSubSurfaceHover
        : nayoriSelectionGroupButton.appearance.editorialEverywhere ? nayoriSelectionGroupButton.appearance.editorial.controlHover
        : nayoriSelectionGroupButton.appearance.colors.colSecondaryContainerHover
    colBackgroundActive: SettingsMaterialPreset.unified ? nayoriSelectionGroupButton.appearance.colors.colLayer1Active
        : nayoriSelectionGroupButton.appearance.regaliaEverywhere ? nayoriSelectionGroupButton.appearance.regalia.controlPlateActive
        : nayoriSelectionGroupButton.appearance.zzzEverywhere ? nayoriSelectionGroupButton.appearance.colors.colLayer1Active
        : nayoriSelectionGroupButton.appearance.angelEverywhere ? nayoriSelectionGroupButton.appearance.angel.colGlassCardActive
        : nayoriSelectionGroupButton.appearance.auroraEverywhere ? nayoriSelectionGroupButton.appearance.aurora.colSubSurfaceActive
        : nayoriSelectionGroupButton.appearance.editorialEverywhere ? nayoriSelectionGroupButton.appearance.editorial.controlPressed
        : nayoriSelectionGroupButton.appearance.colors.colSecondaryContainerActive

    /**
     * Mini screen-top mockup: the tile is a screen, the shape is the bar. Every
     * kind shares one size and one fill (zzz doctrine: separation by fill, no
     * outlines) so only the actual corner geometry differs — hug touches the
     * top edge and rounds downward, float detaches fully rounded, rect bleeds
     * square, card floats narrower with its accent tick.
     */
    component ZzzCornerPreview: Item {
        id: preview
        required property string kind
        implicitWidth: 18
        implicitHeight: 12

        readonly property bool hug: kind === "hug"
        readonly property bool rect: kind === "rect"
        readonly property bool card: kind === "card"
        readonly property color barFill: root.toggled
            ? nayoriSelectionGroupButton.colorUtils.mix(nayoriSelectionGroupButton.appearance.zzz.onSticker, nayoriSelectionGroupButton.appearance.zzz.sticker, 0.75)
            : nayoriSelectionGroupButton.colorUtils.applyAlpha(nayoriSelectionGroupButton.appearance.zzz.ink, 0.5)

        Rectangle {
            id: miniBar
            x: preview.card ? 3 : (preview.hug || preview.rect ? 0 : 2)
            y: preview.hug || preview.rect ? 0 : 2
            width: preview.implicitWidth - 2 * x
            height: 7
            color: preview.barFill
            topLeftRadius: preview.hug || preview.rect ? 0 : 3
            topRightRadius: preview.hug || preview.rect ? 0 : 3
            bottomLeftRadius: preview.rect ? 0 : 3
            bottomRightRadius: preview.rect ? 0 : 3
        }

        Rectangle {
            visible: preview.card
            anchors.horizontalCenter: miniBar.horizontalCenter
            y: miniBar.y + miniBar.height + 2
            width: 8
            height: 1.5
            radius: height / 2
            color: preview.barFill
            opacity: 0.7
        }
    }

    contentItem: RowLayout {
        spacing: (root.showZzzPreview || root.buttonIcon?.length > 0) && root.buttonText?.length > 0 ? 4 : 0

        Behavior on spacing {
            enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
            animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementResize.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementResize.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementResize.bezierCurve }
        }

        Item {
            id: iconReveal
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.showZzzPreview ? cornerPreview.implicitWidth : (root.buttonIcon?.length > 0 ? materialSymbol.implicitWidth : 0)
            implicitHeight: root.showZzzPreview ? cornerPreview.implicitHeight : materialSymbol.implicitHeight
            opacity: root.showZzzPreview || root.buttonIcon?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
                animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementResize.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementResize.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
                animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.bezierCurve }
            }

            Loader {
                id: cornerPreview
                anchors.centerIn: parent
                active: root.showZzzPreview
                sourceComponent: ZzzCornerPreview {
                    kind: root.buttonPreviewKind
                }
            }

            MaterialSymbol {
                id: materialSymbol
                anchors.centerIn: parent
                visible: !root.showZzzPreview
                text: root.buttonIcon
                iconSize: nayoriSelectionGroupButton.appearance.font.pixelSize.normal
                color: nayoriSelectionGroupButton.appearance.regaliaEverywhere
                    ? (root.toggled ? nayoriSelectionGroupButton.appearance.regalia.primaryPlateInk : nayoriSelectionGroupButton.appearance.regalia.onColor)
                    : nayoriSelectionGroupButton.appearance.zzzEverywhere
                        ? (root.toggled ? nayoriSelectionGroupButton.appearance.zzz.onSticker : nayoriSelectionGroupButton.appearance.zzz.ink)
                        : nayoriSelectionGroupButton.appearance.editorialEverywhere
                            ? (root.toggled ? nayoriSelectionGroupButton.appearance.editorial.accentInk : nayoriSelectionGroupButton.appearance.editorial.accent)
                        : (root.toggled ? nayoriSelectionGroupButton.appearance.colors.colOnPrimary : nayoriSelectionGroupButton.appearance.colors.colOnSecondaryContainer)
            }
        }

        Item {
            Layout.minimumWidth: 0
            implicitWidth: root.buttonText?.length > 0
                ? Math.min(textItem.implicitWidth, root.maxTextWidth) : 0
            implicitHeight: textMetrics.height // Force height to that of regular text
            opacity: root.buttonText?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
                animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementResize.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementResize.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: nayoriSelectionGroupButton.appearance.animationsEnabled
                animation: NumberAnimation { duration: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.duration; easing.type: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.type; easing.bezierCurve: nayoriSelectionGroupButton.appearance.animation.elementMoveFast.bezierCurve }
            }

            TextMetrics {
                id: textMetrics
                font.family: nayoriSelectionGroupButton.appearance.font.family.main
                text: "Abc"
            }

            StyledText {
                id: textItem
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                color: nayoriSelectionGroupButton.appearance.regaliaEverywhere
                    ? (root.toggled ? nayoriSelectionGroupButton.appearance.regalia.primaryPlateInk : nayoriSelectionGroupButton.appearance.regalia.onColor)
                    : nayoriSelectionGroupButton.appearance.zzzEverywhere
                        ? (root.toggled ? nayoriSelectionGroupButton.appearance.zzz.onSticker : nayoriSelectionGroupButton.appearance.zzz.ink)
                        : nayoriSelectionGroupButton.appearance.editorialEverywhere
                            ? (root.toggled ? nayoriSelectionGroupButton.appearance.editorial.accentInk : nayoriSelectionGroupButton.appearance.editorial.ink)
                        : (root.toggled ? nayoriSelectionGroupButton.appearance.colors.colOnPrimary : nayoriSelectionGroupButton.appearance.colors.colOnSecondaryContainer)
                text: root.buttonText
            }
        }
    }
}
