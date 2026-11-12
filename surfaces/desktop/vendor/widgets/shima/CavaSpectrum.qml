import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick




Item {
    readonly property var nayoriCavaSpectrum: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property bool active: false
    property var points: []
    property string visualizerType: "bars"
    property real normalizationCeiling: 1000
    property real fillRatio: 0.6
    property real spectrumOpacity: 0.35
    property real sampleStartRatio: 0
    property real sampleEndRatio: 1
    property bool reverseFrequency: false
    property real pixelsPerBar: 12
    property real barSpacing: 2
    property real barRadius: 2
    property real barMinHeight: 1
    property string barsOrigin: "bottom"
    property int smoothing: 2
    property string waveMode: "fill"
    property real lineWidth: 2
    property real edgeInset: 0
    property real leftRadius: 0
    property real rightRadius: 0
    property real topLeftRadius: -1
    property real topRightRadius: -1
    property real bottomLeftRadius: -1
    property real bottomRightRadius: -1
    property real edgeSoftness: 0.28
    property string frequencyProfile: "flat"
    property real accentStrength: 0.7
    property real startOpacity: 1
    property real endOpacity: 1
    property real startTaper: -1
    property real endTaper: -1
    property var clipSegments: []

    // Quickshell resolves static directory imports through qs:, which cannot
    // locate a shared library. Resolve the physical directory at runtime and
    // instantiate the unchanged painter there; all presentation properties stay
    // bound to this per-instance wrapper. No generated absolute path is stored.
    property var nativePainter: null
    Component.onCompleted: {
        const directory = Qt.resolvedUrl("../native").toString()
        const properties = ["points", "visualizerType", "normalizationCeiling", "fillRatio", "spectrumOpacity", "spectrumColor", "spectrumColors", "sampleStartRatio", "sampleEndRatio", "reverseFrequency", "pixelsPerBar", "barSpacing", "barRadius", "barMinHeight", "barsOrigin", "smoothing", "waveMode", "lineWidth", "edgeInset", "leftRadius", "rightRadius", "topLeftRadius", "topRightRadius", "bottomLeftRadius", "bottomRightRadius", "edgeSoftness", "frequencyProfile", "accentStrength", "mirroredStereo", "startOpacity", "endOpacity", "startTaper", "endTaper", "clipSegments"]
        const bindings = properties.map(name => name + ": parent." + name).join("; ")
        nativePainter = Qt.createQmlObject(
            'import QtQuick; import ' + JSON.stringify(directory) + ' as Native; Native.CavaSpectrumPainter { anchors.fill: parent; ' + bindings + ' }', root, "NayoriSpectrumPainter")
    }

    property color spectrumColor: nayoriCavaSpectrum.appearance.colors.colPrimary
    property var spectrumColors: nayoriCavaSpectrum.cavaTheme.visualizerColors
    property bool mirroredStereo: nayoriCavaSpectrum.config.options?.appearance?.cava?.stereo ?? true

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
