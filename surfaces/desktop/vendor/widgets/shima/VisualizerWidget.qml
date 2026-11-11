import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets








AbstractBackgroundWidget {
    readonly property var nayoriVisualizerWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "visualizer"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", vizType: "bars", waveOpacity: -1,
        paletteMode: "cava", barsOrigin: "bottom", waveMode: "fill",
        frequencyProfile: "flat", smoothing: 2, fillRatio: 90, barOpacity: 100,
        organicSensitivity: 25, organicPulse: 150, organicMotionSpeed: 250, organicIdleMotion: 18,
        organicOpacity: 100, organicGlow: 100, organicCoverSize: 51, organicRange: 20,
        organicCompression: 0,
        barCount: 48, barSpacing: 2, barRadius: 2, barMinHeight: 1,
        lineWidth: 2, edgeInset: 0, edgeSoftness: 28, accentStrength: 70,
        contentWidth: 304, contentHeight: 104, dim: 0,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto",
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2,
        cornerRadius: -1, x: 100, y: 100
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 304) * scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 104) * scaleFactor)

    visibleWhenLocked: false
    needsColText: true
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 120
    resizeMinHeight: 48

    // Ryoku hosting draws the slot card, so drop this widget's own card in Ryoku
    // style — the bars/organic art sit on the single shared surface.
    readonly property bool _ryokuBare: root.ryokuHosted && root.ryokuStyle
    property real ryokuSlotRadius: -1

    readonly property string vizType: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.vizType", "bars")
    readonly property int waveOpacity: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.waveOpacity", -1)
    readonly property string paletteMode: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.paletteMode", "cava")
    // Album is artwork-owned, so the shared semantic palette editor is only
    // relevant for the widget semantic color modes.
    semanticPaletteQuickControls: root.paletteMode === "accent"
        || root.paletteMode === "primary"
    readonly property var spectrumPalette: {
        // iRiS draws its widgets from one solved palette; Cava's colours are Material's.
        if (root.paletteMode === "accent" || (root.widgetIris && root.paletteMode === "cava"))
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        if (root.paletteMode === "primary")
            return [root.widgetAccent]
        if (root.paletteMode === "album") {
            const colors = albumArtworkQuantizer?.colors ?? []
            if (colors.length > 0)
                return colors
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        }
        return nayoriVisualizerWidget.cavaTheme.visualizerColors
    }
    readonly property int smoothing: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.smoothing", 2)
    readonly property string frequencyProfile: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.frequencyProfile", "flat")
    readonly property real accentStrength: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.accentStrength", 70) / 100
    readonly property real organicSensitivitySetting: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicSensitivity", 25) / 100
    // Keep the useful low end almost linear, then progressively compress the
    // upper half. The raw 25-200 slider used to multiply deformation linearly,
    // making 100-200 jump far more than the visual control implied.
    readonly property real organicSensitivity: root.organicSensitivitySetting <= 0.4
        ? root.organicSensitivitySetting
        : 0.4 + 0.85 * (1 - Math.exp(-(root.organicSensitivitySetting - 0.4) * 1.4))
    readonly property real organicPulse: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicPulse", 150) / 100
    readonly property real organicCompression: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicCompression", 0) / 100
    readonly property real organicMotionSpeed: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicMotionSpeed", 250) / 100
    readonly property real organicIdleMotion: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicIdleMotion", 18) / 100
    readonly property real organicOpacity: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicOpacity", 100) / 100
    readonly property real organicGlow: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicGlow", 100) / 100
    readonly property real organicCoverSize: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicCoverSize", 51) / 100
    readonly property real organicRange: nayoriVisualizerWidget.config.getNestedValue(
        "background.widgets.visualizer.organicRange", 20) / 100
    // The Organic texture renders larger than the widget so peaks have room.
    // Compensate that overscan when cutting the centre hole: the inner edge
    // should track the artwork itself, not an arbitrary shader-space radius.
    readonly property real organicRenderOverscan: 1.34
    // The original Organic kept roughly 0.075-0.08 radial units of body between
    // the artwork edge and the resting outer contour. Derive the resting radius
    // from the actual cover instead of letting a fixed blob radius make smaller
    // covers look disproportionately thick.
    readonly property real organicBaseRadius: Math.min(0.78,
        root.organicCoverSize / root.organicRenderOverscan + 0.078)
    // Let the Organic body continue underneath the artwork. Matching two
    // antialiased edges exactly leaves a wallpaper-colored seam; underlapping
    // the halo means the cover is always the visual owner of the centre edge.
    readonly property real organicCoverUnderlap: 0.055
    readonly property real organicHollowAmount: Math.max(0, Math.min(1,
        ((root.organicCoverSize - root.organicCoverUnderlap)
            / root.organicRenderOverscan) / 0.565))



    readonly property bool _active: root.visible
        && root.motionActive && nayoriVisualizerWidget.mpris.isPlaying
    readonly property var _activePlayer: nayoriVisualizerWidget.mpris.activePlayer
    readonly property bool _organicPresent: root.visible && root.powerActive
        && root.vizType === "organic" && root._activePlayer !== null
    readonly property string _activeArt: organicArtworkResolver.displaySource
    property string _organicDisplayedArt: ""
    property string _organicDisplayedArtIdentity: ""
    property string _organicPendingArt: ""
    property string _organicPendingArtIdentity: ""
    property real _organicReveal: 1
    readonly property var _organicSilentPoints: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    function _organicArtIdentity(source: string): string {
        const value = source ?? ""
        let marker = value.indexOf("?inir_art=")
        if (marker < 0)
            marker = value.indexOf("&inir_art=")
        return marker >= 0 ? value.slice(0, marker) : value
    }
    readonly property color _organicPrimary: {
        const palette = root.spectrumPalette ?? []
        return palette.length > 0 ? palette[0] : root.widgetAccentVisible
    }
    readonly property color _organicSecondary: {
        const palette = root.spectrumPalette ?? []
        if (palette.length > 2)
            return palette[Math.floor((palette.length - 1) / 2)]
        if (palette.length > 1)
            return palette[1]
        return root._organicPrimary
    }
    readonly property color _organicTertiary: {
        const palette = root.spectrumPalette ?? []
        if (palette.length > 2)
            return palette[palette.length - 1]
        return root._organicSecondary
    }

    MediaArtworkResolver {
        id: organicArtworkResolver
        sourceUrl: (root.vizType === "organic" || root.paletteMode === "album")
            ? nayoriVisualizerWidget.mpris.effectiveArtUrl(root._activePlayer) : ""
        title: nayoriVisualizerWidget.mpris.titleOf(root._activePlayer) ?? ""
        artist: nayoriVisualizerWidget.mpris.artistOf(root._activePlayer) ?? ""
        album: root._activePlayer?.trackAlbum ?? ""
    }

    ColorQuantizer {
        id: albumArtworkQuantizer
        source: root.paletteMode === "album" ? organicArtworkResolver.displaySource : ""
        depth: 2
        rescaleSize: 24
    }

    on_ActiveArtChanged: {
        const next = root._activeArt
        if (next.length === 0)
            return
        const identity = root._organicArtIdentity(next)
        if (root._organicDisplayedArt.length === 0) {
            root._organicDisplayedArt = next
            root._organicDisplayedArtIdentity = identity
            return
        }
        if (identity === root._organicDisplayedArtIdentity) {
            root._organicDisplayedArt = next
            return
        }
        if (organicArtTransition.running
                && identity === root._organicPendingArtIdentity) {
            root._organicPendingArt = next
            return
        }
        root._organicPendingArt = next
        root._organicPendingArtIdentity = identity
        organicArtTransition.restart()
    }

    SequentialAnimation {
        id: organicArtTransition
        NumberAnimation {
            target: root
            property: "_organicReveal"
            to: 0
            duration: nayoriVisualizerWidget.appearance.calcEffectiveDuration(170)
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root._organicDisplayedArt = root._organicPendingArt
                root._organicDisplayedArtIdentity = root._organicPendingArtIdentity
            }
        }
        NumberAnimation {
            target: root
            property: "_organicReveal"
            to: 1
            duration: nayoriVisualizerWidget.appearance.calcEffectiveDuration(300)
            easing.type: Easing.OutBack
            easing.overshoot: 1.08
        }
    }

    // ── Style tokens ───────────────────────────────────────────
    readonly property real cardRadius: root.widgetCardRadius

    CavaProcess {
        id: cavaProcess
        active: root._active
        sampleCount: Math.max(50,
            nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barCount", 48))
    }

    // ── Card background ────────────────────────────────────────
    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        id: cardBg
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root._ryokuBare ? 0 : root.backgroundOpacity
        surfaceBorderWidth: root._ryokuBare ? 0 : root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetSurfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.ryokuScreenX
        screenY: root.ryokuScreenY
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root._ryokuBare && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    // ── Visualizer rendering ─────────────────────────────────────
    // The field and the artwork on top of it move out together (LiveLayer): in their own surface, in their own
    // order, so a still widget does not repaint the whole desktop every frame. The card stays in the host, below.
    LiveLayer {
        anchors.fill: parent
        live: root.motionActive && (root.vizType === "organic"
            ? root._organicPresent
            : root._active && cavaProcess.audioSignalActive)
        content: vizContent
    }

    Component {
        id: vizContent
        Item {
            id: vizDrawn
            property bool drawing: false

            AudioVisualizerLayer {
                id: visualizerLayer
                anchors.fill: parent
                anchors.margins: nayoriVisualizerWidget.appearance.angelEverywhere || nayoriVisualizerWidget.appearance.inirEverywhere ? 4 : 0
                points: root.vizType === "organic"
                    ? (root._active && cavaProcess.audioSignalActive
                        ? cavaProcess.points : root._organicSilentPoints)
                    : cavaProcess.points
                active: root.vizType === "organic"
                    ? root._organicPresent
                    : root._active && cavaProcess.audioSignalActive
                animate: root.motionActive && vizDrawn.drawing
                visualizerType: root.vizType
                normalizationCeiling: cavaProcess.normalizationCeiling
                topLeftRadius: Math.max(0, (root._ryokuBare && root.ryokuSlotRadius >= 0
                    ? root.ryokuSlotRadius : cardBg.radius) - anchors.margins)
                topRightRadius: topLeftRadius
                bottomLeftRadius: topLeftRadius
                bottomRightRadius: topLeftRadius
                spectrumColors: root.spectrumPalette
                spectrumColor: root.widgetAccentVisible
                spectrumOpacity: (root.vizType === "wave"
                    ? (root.waveOpacity >= 0 ? root.waveOpacity
                        : (nayoriVisualizerWidget.config.options?.appearance?.cava?.waveOpacity ?? 30))
                    : nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barOpacity", 100)) / 100
                fillRatio: root.vizType === "organic" ? root.organicRange
                    : nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.fillRatio", 90) / 100
                barCount: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barCount", 48)
                barSpacing: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barSpacing", 2)
                barMinHeight: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barMinHeight", 1)
                barRadius: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barRadius", 2)
                barsOrigin: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.barsOrigin", "bottom")
                smoothing: root.smoothing
                waveMode: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.waveMode", "fill")
                lineWidth: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.lineWidth", 2)
                edgeInset: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.edgeInset", 0)
                edgeSoftness: nayoriVisualizerWidget.config.getNestedValue("background.widgets.visualizer.edgeSoftness", 28) / 100
                frequencyProfile: root.frequencyProfile
                accentStrength: root.accentStrength
                organicSensitivity: root.organicSensitivity
                organicPulse: root.organicPulse
                organicCompression: root.organicCompression
                organicMotionSpeed: root.organicMotionSpeed
                organicIdleMotion: root.organicIdleMotion
                organicOpacity: root.organicOpacity
                organicGlow: root.organicGlow
                organicOverscan: root.organicRenderOverscan
                organicBaseRadius: root.organicBaseRadius
                organicHollowAmount: root.organicHollowAmount
            }

            Item {
                id: organicCluster
                anchors.fill: parent
                anchors.margins: Math.round(4 * root.scaleFactor)
                visible: root.vizType === "organic"

                ClippingRectangle {
                    id: organicArtwork
                    readonly property real span: Math.min(organicCluster.width, organicCluster.height)

                    width: Math.round(span * root.organicCoverSize)
                    height: width
                    anchors.centerIn: parent
                    visible: root._organicPresent
                    scale: 0.70 + root._organicReveal * 0.30
                    opacity: 0.18 + root._organicReveal * 0.82
                    radius: width * 0.36
                    color: root.widgetSemanticContainer(root.widgetSurfaceRole)
                    border.width: Math.max(1, Math.round(root.scaleFactor))
                    border.color: nayoriVisualizerWidget.colorUtils.applyAlpha(root._organicPrimary, 0.34)

                    Image {
                        anchors.fill: parent
                        source: root._organicDisplayedArt
                        sourceSize: Qt.size(Math.max(128, Math.ceil(width * 2)),
                            Math.max(128, Math.ceil(height * 2)))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        retainWhileLoading: true
                        cache: true
                        smooth: true
                        mipmap: true
                        visible: status === Image.Ready
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: root._organicDisplayedArt.length === 0
                        text: "music_note"
                        fill: 1
                        iconSize: Math.round(organicArtwork.width * 0.34)
                        color: root.widgetSemanticOnContainer(root.widgetSurfaceRole)
                    }
                }
            }
        }
    }
}
