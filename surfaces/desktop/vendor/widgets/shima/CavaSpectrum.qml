import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import "../native" as Native




Native.CavaSpectrumPainter {
    readonly property var nayoriCavaSpectrum: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property bool active: false

    spectrumColor: nayoriCavaSpectrum.appearance.colors.colPrimary
    spectrumColors: nayoriCavaSpectrum.cavaTheme.visualizerColors
    mirroredStereo: nayoriCavaSpectrum.config.options?.appearance?.cava?.stereo ?? true

    visible: (root.points?.length ?? 0) > 0 && (root.active || root.opacity > 0.001)
    opacity: root.active ? Math.max(0, Math.min(1, root.spectrumOpacity)) : 0

    Behavior on opacity {
        enabled: nayoriCavaSpectrum.appearance.animationsEnabled
        NumberAnimation {
            duration: nayoriCavaSpectrum.appearance.calcEffectiveDuration(root.active ? 180 : 480)
            easing.type: root.active ? Easing.OutCubic : Easing.InOutCubic
        }
    }
}
