import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.




import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell

// Hidden instances release their blur FBO; decoded wallpaper pixmaps remain shared.
Rectangle {
    readonly property var nayoriGlassBackground: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    
    property color fallbackColor: nayoriGlassBackground.appearance.colors.colLayer1
    property color inirColor: nayoriGlassBackground.appearance.inir.colLayer1
    property color overlayColor: nayoriGlassBackground.appearance.colors.colLayer0Base
    property real auroraTransparency: nayoriGlassBackground.appearance.editorialEverywhere && nayoriGlassBackground.appearance.editorial.glassActive
        ? 1 - nayoriGlassBackground.appearance.editorial.glassOpacity : nayoriGlassBackground.appearance.aurora.popupTransparentize
    property bool wallpaperBackdropEnabled: true
    property string wallpaperUrl: nayoriGlassBackground.wallpaperListener.wallpaperUrlForScreen(root.QsWindow?.window?.screen ?? null)
    
    // Screen-relative position for blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080
    
    readonly property bool angelEverywhere: nayoriGlassBackground.appearance.angelEverywhere
    readonly property bool auroraEverywhere: nayoriGlassBackground.appearance.auroraEverywhere
    readonly property bool inirEverywhere: nayoriGlassBackground.appearance.inirEverywhere
    // Bypasses the style gate, which is what its callers always documented it as
    // doing. It used to be AND-ed inside the backend check, so a surface asking
    // for a backdrop outside aurora — island glass, or a backdrop the user turned
    // on explicitly — silently got nothing. The effects gate still applies.
    property bool forceBackdrop: false
    property bool forceNeutralMaterial: false
    // Blur radius as a fraction of blurMax. 1 is the house default every existing
    // caller inherits; lower values are for surfaces that expose it to the user.
    property real blurStrength: nayoriGlassBackground.appearance.editorialEverywhere && nayoriGlassBackground.appearance.editorial.glassActive
        ? nayoriGlassBackground.appearance.editorial.glassBlur : 1
    property real saturationStrength: nayoriGlassBackground.appearance.editorialEverywhere && nayoriGlassBackground.appearance.editorial.glassActive ? 0.04 : 0.2
    readonly property bool useWallpaperBackdrop: root.forceBackdrop
        ? nayoriGlassBackground.appearance.effectsEnabled
        : (nayoriGlassBackground.appearance.blurBackendFor("panels", nayoriGlassBackground.appearance.blurTopology.unsupported) === "wallpaper"
            && root.wallpaperBackdropEnabled)
    readonly property bool backdropReady: !root.useWallpaperBackdrop
        || blurredWallpaper.status === Image.Ready
    
    // Never expose a raw transparent hole while the wallpaper is loading or
    // unavailable. Consumers can provide a solid style base as fallback; once
    // the backdrop is ready this becomes transparent and the glass stack takes over.
    color: root.useWallpaperBackdrop && root.backdropReady ? "transparent"
        : root.inirEverywhere ? root.inirColor
        : root.fallbackColor
    
    property bool hovered: false

    border.width: 0
    border.color: "transparent"

    clip: true
    
    // Hidden persistent surfaces must not retain their mask FBO. The decoded
    // wallpaper stays in Qt's shared image cache, so remapping remains warm.
    layer.enabled: root.useWallpaperBackdrop && root.visible
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    
    // Blurred wallpaper backdrop for aurora/angel styles.
    // OPTIMIZATION: layer.enabled is only active when the GlassBackground is
    // actually visible, reducing GPU memory when panels are hidden.
    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root.useWallpaperBackdrop && status === Image.Ready
        source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        // All GlassBackground instances share the same wallpaper URL and sourceSize,
        // so Qt's QPixmapCache serves a single decoded pixmap to all of them.
        cache: true
        asynchronous: true
        // Constrain decoded size to screen dimensions — the blur doesn't need more.
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        // CRITICAL: Only enable blur layer when VISIBLE AND enabled.
        // This releases the FBO when the panel is hidden, saving ~16 MiB per instance.
        layer.enabled: nayoriGlassBackground.appearance.effectsEnabled && root.useWallpaperBackdrop && root.visible
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root.angelEverywhere && !root.forceNeutralMaterial
                ? (nayoriGlassBackground.appearance.angel.blurSaturation * nayoriGlassBackground.appearance.angel.colorStrength)
                : (nayoriGlassBackground.appearance.effectsEnabled ? root.saturationStrength : 0)
            blurEnabled: nayoriGlassBackground.appearance.effectsEnabled
            blurMax: 64
            blur: nayoriGlassBackground.appearance.effectsEnabled
                ? (root.angelEverywhere ? nayoriGlassBackground.appearance.angel.blurIntensity : root.blurStrength)
                : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.useWallpaperBackdrop
        color: root.angelEverywhere && !root.forceNeutralMaterial
            ? nayoriGlassBackground.colorUtils.transparentize(nayoriGlassBackground.appearance.colors.colLayer0Base, nayoriGlassBackground.appearance.angel.overlayOpacity)
            : nayoriGlassBackground.colorUtils.transparentize(root.overlayColor, root.auroraTransparency)
    }

    // Inset glow — light-from-above on top edge, angel only
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: nayoriGlassBackground.appearance.angel.insetGlowHeight
        visible: root.angelEverywhere && !root.forceNeutralMaterial
        color: nayoriGlassBackground.appearance.angel.colInsetGlow
    }

    // Partial border — elegant half-borders, angel only
    AngelPartialBorder {
        visible: root.angelEverywhere && !root.forceNeutralMaterial
        targetRadius: root.radius
        hovered: root.hovered
    }
}
