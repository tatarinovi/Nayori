import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell







// Style-aware widget background surface.
// Adapts to the active ii style: blur for aurora/angel, border-only for inir, solid for material.
// Parent widget must set screenX/screenY for correct blur alignment.
Rectangle {
    readonly property var nayoriWidgetSurface: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property bool shown: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        enabled: (root._iris ? nayoriWidgetSurface.irisStyle.motionEnabled : nayoriWidgetSurface.appearance.animationsEnabled) && root.powerActive
        NumberAnimation { duration: root._iris ? nayoriWidgetSurface.irisStyle.revealDuration : nayoriWidgetSurface.appearance.animation.elementMoveFast.duration }
    }

    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080

    // The additive Ryoku skin for this surface, chosen per widget by the host —
    // never the global iris.appearance.frontend. Default off keeps the upstream
    // iRiS plate.
    property bool ryokuStyle: false

    // Widget customization passthrough
    property real surfaceOpacity: 0.06
    property real surfaceBorderWidth: 1
    property real surfaceBorderOpacity: 0.08
    property color surfaceColor: nayoriWidgetSurface.appearance.colors.colOnLayer0
    property color surfaceFill: nayoriWidgetSurface.appearance.colors.colLayer1
    // Auto preserves each global style's native plate. Explicit ink modes
    // force the opposite plate polarity so the selected ink remains visible.
    property string colorMode: "auto"
    // The widget's accent identity (usually root.widgetAccent) — gives the plate
    // an actual color seat instead of a neutral wallpaper-luminance scrim.
    property color surfaceAccent: nayoriWidgetSurface.appearance.colors.colPrimary
    property real surfaceRadius: root._iris ? Math.round(Math.max(0, Math.min(40, nayoriWidgetSurface.config.options?.iris?.widgets?.radius ?? 22)) * nayoriWidgetSurface.irisStyle.density)
        : nayoriWidgetSurface.appearance.zzzEverywhere ? nayoriWidgetSurface.appearance.zzz.controlRadius : nayoriWidgetSurface.appearance.rounding.small
    // Allows per-widget blur override for styles that do not explicitly own
    // their material. Ricelin Island glass follows the shared Island setting.
    property bool surfaceUseBlur: true

    // Follow the owning widget's per-output power state. Standalone surfaces
    // keep the global summary as a compatibility fallback.
    property bool powerActive: parent?.powerActive ?? nayoriWidgetSurface.widgetPower.widgetsActive

    // The glass behind a widget is a screen-sized crop of the wallpaper, and
    // every WidgetSurface keeps its own copy plus its own screen-sized FBO (see
    // the note on blurredWallpaper below). At full resolution that was ~15 MB of
    // GPU memory per widget for something the user only ever sees through a
    // 64px blur. Rendering the source and its layer at half resolution is
    // invisible once blurred — provided the blur radius is scaled by the same
    // factor (blurMax is measured in source pixels, so a half-size texture would
    // otherwise blur twice as wide) and the layer is smoothed on upscale.
    readonly property real _blurScale: 0.5

    property bool irisPresentation: true
    readonly property bool _iris: root.irisPresentation
    readonly property string _surfaceDialect: root._iris ? "iris" : (nayoriWidgetSurface.config.options?.background?.widgets?.style ?? "panel") === "island"
        ? "island" : nayoriWidgetSurface.appearance.globalStyle
    readonly property bool _angel: root._surfaceDialect === "angel"
    readonly property bool _aurora: root._surfaceDialect === "aurora" || root._angel
    readonly property bool _inir: root._surfaceDialect === "inir"
    readonly property bool _zzz: root._surfaceDialect === "zzz"
    readonly property bool _cookie: root._surfaceDialect === "cookie"
    readonly property bool _regalia: root._surfaceDialect === "regalia"
    readonly property bool _editorial: root._surfaceDialect === "editorial"
    readonly property bool _island: root._surfaceDialect === "island"
    readonly property real _surfaceStrength: Math.max(0, Math.min(1, Number(root.surfaceOpacity) || 0))
    readonly property bool _backgroundVisible: root._surfaceStrength > 0.001
    readonly property bool _editorialStack: root._editorial && root._backgroundVisible && nayoriWidgetSurface.appearance.editorial.paperStack
    // Explicit Island style owns its material opacity. A widget's legacy
    // backgroundOpacity controls whether the plate exists, but must not multiply
    // the shared Ricelin opacity again or every widget becomes nearly invisible.
    readonly property real _plateAlpha: root._backgroundVisible
        ? (root._island ? 1 : root._editorial ? (root._glass ? nayoriWidgetSurface.appearance.editorial.glassOpacity : Math.min(1, 0.86 + root._surfaceStrength * 0.14)) : Math.min(0.96, 0.72 + root._surfaceStrength * 0.24)) : 0
    readonly property string _irisMaterialName: String(nayoriWidgetSurface.config.options?.iris?.widgets?.material ?? "glass")
    readonly property bool _irisGlass: root._iris && root._backgroundVisible && root._irisMaterialName === "glass"
    readonly property bool _irisClear: root._iris && root._irisMaterialName === "clear"
    readonly property string _irisOutline: String(nayoriWidgetSurface.config.options?.iris?.widgets?.outline ?? "auto")
    readonly property bool _irisRimHidden: root._iris && !nayoriWidgetSurface.globalStates.widgetEditMode && (root._irisOutline === "none"
        || (root._irisOutline !== "always" && root._irisClear && !Boolean(nayoriWidgetSurface.config.options?.iris?.widgets?.rim ?? false)))
    readonly property real _irisStrength: Math.max(0, Math.min(100, nayoriWidgetSurface.config.options?.iris?.widgets?.opacity ?? 100)) / 100
    readonly property bool _glass: root._irisGlass || !root._iris && !root._island && root._backgroundVisible
        && nayoriWidgetSurface.appearance.blurBackendFor("widgets", nayoriWidgetSurface.appearance.blurTopology.unsupported) === "wallpaper"
        && root.surfaceUseBlur
        && (!root._editorial || nayoriWidgetSurface.appearance.editorial.glassActive)
    readonly property string _wallpaperUrl: nayoriWidgetSurface.wallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)

    // Wallpaper region brightness behind the widget (0-1; -1 = unknown).
    // Parent widgets bind their own regionBrightness so the plate opposes the
    // wallpaper: near-black on bright regions, theme container on dark ones.
    property real regionBrightness: -1
    readonly property bool _regionBright: regionBrightness >= 0
        ? regionBrightness > 0.55
        : !nayoriWidgetSurface.appearance.m3colors.darkmode

    // A widget surface is a Material container, not another wallpaper sample.
    // Keep the generated hue while preserving a predictable surface/on-surface
    // relationship. Accent belongs to active data and icons, not to the whole card.
    readonly property color _plateDark: {
        const p = Qt.color(root.surfaceAccent);
        return Qt.hsla(p.hslHue, Math.min(0.22, p.hslSaturation), 0.11, 1.0);
    }
    readonly property color _plateLight: {
        const p = Qt.color(root.surfaceAccent);
        return Qt.hsla(p.hslHue, Math.min(0.20, p.hslSaturation), 0.93, 1.0);
    }
    // Mirrors AbstractBackgroundWidget.widgetPlateIsDark — dark theme stays black
    // everywhere; light theme gets a paper plate except over a bright wallpaper
    // region, where a light card would read as glare.
    readonly property bool _plateIsDark: root.colorMode === "light" ? true
        : root.colorMode === "dark" ? false
        : nayoriWidgetSurface.colorUtils.relativeLuminance(root.surfaceFill) < 0.38
    readonly property color _plate: root._plateIsDark ? root._plateDark : root._plateLight
    readonly property color _flatFill: nayoriWidgetSurface.colorUtils.applyAlpha(
        root.colorMode === "auto" ? root.surfaceFill : root._plate, root._plateAlpha)
    // iRiS plates are the Island material (optionally carrying the wallpaper's
    // hue); a widget's own semantic fill would bring Material tones back in.
    readonly property color _irisMaterial: root.ryokuStyle ? nayoriWidgetSurface.irisStyle.surface
        : root._irisMaterialName === "tinted"
        ? nayoriWidgetSurface.colorUtils.mix(nayoriWidgetSurface.irisStyle.surface, nayoriWidgetSurface.appearance.colors.colPrimary, 0.82) : nayoriWidgetSurface.irisStyle.surface
    readonly property color _irisFill: root._irisClear || root._irisGlass
        ? nayoriWidgetSurface.colorUtils.applyAlpha(nayoriWidgetSurface.irisStyle.surface, root._irisClear && !Boolean(nayoriWidgetSurface.config.options?.iris?.widgets?.legibleAlways ?? false) ? 0
            : nayoriWidgetSurface.irisStyle.legibleVeil(root._irisMaterialName, root.regionBrightness, 0, 1)
                * (Boolean(nayoriWidgetSurface.config.options?.iris?.widgets?.legibleAlways ?? false) ? 1 : root._irisStrength))
        : nayoriWidgetSurface.colorUtils.applyAlpha(
        root.colorMode === "dark" ? nayoriWidgetSurface.colorUtils.mix(nayoriWidgetSurface.irisStyle.text, nayoriWidgetSurface.irisStyle.accent, 0.98) : root._irisMaterial,
        root._backgroundVisible ? Math.min(1, 0.72 + root._surfaceStrength * 0.28)
            * Math.max(0, Math.min(100, nayoriWidgetSurface.config.options?.iris?.widgets?.opacity ?? 100)) / 100 : 0)
    readonly property color _cookieFillBase: root.colorMode === "auto"
        ? root.surfaceFill : root._plate
    readonly property color _cookieFill: root._backgroundVisible
        ? nayoriWidgetSurface.colorUtils.applyAlpha(root._cookieFillBase, root._plateAlpha)
        : "transparent"
    readonly property color _cookieStrokeBase: root.colorMode === "auto"
        ? nayoriWidgetSurface.appearance.cookie.onColor : nayoriWidgetSurface.colorUtils.contrastColor(root._plate)
    readonly property string surfaceReport: JSON.stringify({
        style: root._iris ? "iris" : root._cookie ? "cookie"
            : root._zzz ? "zzz"
            : root._regalia ? "regalia"
            : root._editorial ? "editorial"
            : root._island ? "island"
            : root._angel ? "angel"
            : root._aurora ? "aurora"
            : root._inir ? "inir" : "material",
        cookie: root._cookie,
        island: root._island,
        glass: root._glass,
        paperStack: root._editorialStack,
        visible: root.visible,
        backgroundOpacity: root.surfaceOpacity,
        backgroundVisible: root._backgroundVisible,
        borderWidth: root.surfaceBorderWidth,
        borderOpacity: root.surfaceBorderOpacity,
        radius: root.radius,
        fill: String(root._iris ? root._irisFill : root._cookie ? root._cookieFill : root._flatFill)
    })

    // iRiS widget plates share one continuous corner, tighter than the Island.
    radius: surfaceRadius
    color: root._iris ? (root._irisGlass ? "transparent" : root._irisFill)
        : _editorialStack ? "transparent"
        : _island ? "transparent"
        : _glass ? "transparent"
        : _zzz ? "transparent"
        : _cookie ? "transparent"
        : _regalia ? "transparent"
        : _inir ? "transparent"
        : root._backgroundVisible ? _flatFill : "transparent"
    border.width: 0
    border.color: "transparent"
    clip: true





    Behavior on radius {
        enabled: (root._iris ? nayoriWidgetSurface.irisStyle.motionEnabled : nayoriWidgetSurface.appearance.animationsEnabled)
        NumberAnimation { duration: root._iris ? nayoriWidgetSurface.irisStyle.revealDuration : nayoriWidgetSurface.appearance.animation.elementMoveFast.duration; easing.type: root._iris ? Easing.BezierSpline : nayoriWidgetSurface.appearance.animation.elementMoveFast.type; easing.bezierCurve: root._iris ? nayoriWidgetSurface.irisStyle.morphCurve : nayoriWidgetSurface.appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on color {
        enabled: (root._iris ? nayoriWidgetSurface.irisStyle.motionEnabled : nayoriWidgetSurface.appearance.animationsEnabled)
        ColorAnimation { duration: root._iris ? nayoriWidgetSurface.irisStyle.revealDuration : nayoriWidgetSurface.appearance.animation.elementMoveFast.duration; easing.type: root._iris ? Easing.BezierSpline : nayoriWidgetSurface.appearance.animation.elementMoveFast.type; easing.bezierCurve: root._iris ? nayoriWidgetSurface.irisStyle.morphCurve : nayoriWidgetSurface.appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.width {
        enabled: (root._iris ? nayoriWidgetSurface.irisStyle.motionEnabled : nayoriWidgetSurface.appearance.animationsEnabled)
        NumberAnimation { duration: root._iris ? nayoriWidgetSurface.irisStyle.revealDuration : nayoriWidgetSurface.appearance.animation.elementMoveFast.duration; easing.type: root._iris ? Easing.BezierSpline : nayoriWidgetSurface.appearance.animation.elementMoveFast.type; easing.bezierCurve: root._iris ? nayoriWidgetSurface.irisStyle.morphCurve : nayoriWidgetSurface.appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on border.color {
        enabled: (root._iris ? nayoriWidgetSurface.irisStyle.motionEnabled : nayoriWidgetSurface.appearance.animationsEnabled)
        ColorAnimation { duration: root._iris ? nayoriWidgetSurface.irisStyle.revealDuration : nayoriWidgetSurface.appearance.animation.elementMoveFast.duration; easing.type: root._iris ? Easing.BezierSpline : nayoriWidgetSurface.appearance.animation.elementMoveFast.type; easing.bezierCurve: root._iris ? nayoriWidgetSurface.irisStyle.morphCurve : nayoriWidgetSurface.appearance.animation.elementMoveFast.bezierCurve }
    }

    // Separate border overlay — avoids Qt's interior bleed when border.width > 0 on a transparent Rectangle
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: !root._editorialStack && !root._zzz && !root._cookie && !root._regalia && !root._island && !root._angel
            && !root._irisRimHidden && root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0
        border.width: root.surfaceBorderWidth
        border.color: root._inir
            ? nayoriWidgetSurface.colorUtils.applyAlpha(nayoriWidgetSurface.appearance.inir.colBorder, root.surfaceBorderOpacity * 3)
            : root._aurora
                ? nayoriWidgetSurface.colorUtils.applyAlpha(nayoriWidgetSurface.appearance.aurora.colTooltipBorder,
                    root.surfaceBorderOpacity)
                : root._editorial
                    ? nayoriWidgetSurface.colorUtils.applyAlpha(nayoriWidgetSurface.appearance.editorial.edge,
                        Math.min(1, root.surfaceBorderOpacity * 2))
                : root._iris ? nayoriWidgetSurface.colorUtils.applyAlpha(root.surfaceColor, root.surfaceBorderOpacity)
                : nayoriWidgetSurface.colorUtils.applyAlpha(
                    nayoriWidgetSurface.colorUtils.ensureReadable(root.surfaceAccent, root._flatFill, 3),
                    Math.min(1, root.surfaceBorderOpacity * 2))
    }


    Rectangle {
        anchors.fill: parent
        visible: root._regalia && root.surfaceBorderWidth > 0
            && root.surfaceBorderOpacity > 0
        radius: root.radius
        color: "transparent"
        border.width: root.surfaceBorderWidth
        border.color: nayoriWidgetSurface.colorUtils.applyAlpha(root.surfaceColor,
            Math.min(0.45, root.surfaceBorderOpacity * 0.6))
    }

    // Removed: the ZZZ accent registration tick. Every fix to keep it inside
    // the rounded/chamfered corner still read as visual clutter across every
    // desktop widget at once — removed outright per explicit request instead
    // of iterating on its geometry again.

    // Blur mask FBO is only useful while the surface can contribute pixels.
    // Keep the decoded wallpaper cached for instant resume, but release the
    // per-widget mask and blur targets during fullscreen/GameMode pauses.
    layer.enabled: root._glass && root.visible && root.powerActive
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        // Don't load/blur when the compositor is already blurring underneath.
        // Each WidgetSurface keeps its own FBO when layer.enabled is true; with
        // many widgets enabled this multiplies fast. See #159.
        visible: root._glass && status === Image.Ready
        source: root._glass ? root._wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: Math.round(root.screenWidth * root._blurScale)
        sourceSize.height: Math.round(root.screenHeight * root._blurScale)

        // OPTIMIZATION: Release FBO when widget is not visible or power is off
        layer.enabled: root._glass && root.visible && root.powerActive
        layer.smooth: true
        layer.textureSize: Qt.size(Math.round(width * root._blurScale),
                                   Math.round(height * root._blurScale))
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root._angel
                ? (nayoriWidgetSurface.appearance.angel.blurSaturation * nayoriWidgetSurface.appearance.angel.colorStrength)
                : 0.15
            blurEnabled: true
            blurMax: Math.max(1, Math.round(64 * root._blurScale))
            blur: root._editorial ? nayoriWidgetSurface.appearance.editorial.glassBlur : root._angel ? nayoriWidgetSurface.appearance.angel.blurIntensity : 0.8
        }
    }

    // Tinted overlay for aurora/angel — island tints with its own gradient below.
    Rectangle {
        anchors.fill: parent
        visible: root._glass && !root._island && !root._editorialStack
        color: root._iris ? root._irisFill
            : root._editorial ? root._flatFill
            : root._angel
            ? nayoriWidgetSurface.colorUtils.transparentize(nayoriWidgetSurface.appearance.colors.colLayer0Base, nayoriWidgetSurface.appearance.angel.overlayOpacity)
            : nayoriWidgetSurface.colorUtils.transparentize(nayoriWidgetSurface.appearance.colors.colLayer0Base, nayoriWidgetSurface.appearance.aurora.popupTransparentize * 1.2)
    }





    // Inset glow — angel only
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: nayoriWidgetSurface.appearance.angel.insetGlowHeight
        visible: root._angel && root._backgroundVisible
        color: nayoriWidgetSurface.appearance.angel.colInsetGlow
    }

    // Partial border — angel only


    // Regalia desktop widgets use the same fitted chassis/content construction
    // as shell panels. The widget remains one visual object, but no longer reads
    // as a generic card with a different fill.


    // Inir subtle fill
    Rectangle {
        anchors.fill: parent
        visible: root._inir && root._backgroundVisible
        radius: root.radius
        color: nayoriWidgetSurface.colorUtils.applyAlpha(root._plate, Math.min(0.96, 0.72 + root.surfaceOpacity * 0.24))
    }
}
