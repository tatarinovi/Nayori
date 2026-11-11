import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick


ShaderEffect {
    readonly property var nayoriFluidWave: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property real radius: 0.0
    property real fillLevel: 0.0
    property real waveAmp: 0.0
    property vector2d itemSize: Qt.vector2d(width, height)
    property real phase: 0.0
    property real vertical: 1.0
    property color color1: nayoriFluidWave.pythonTheme.primary
    property color color2: color1
    property vector4d params: Qt.vector4d(1.0, 0.0, 0.0, 0.0)

    fragmentShader: "file://" + nayoriFluidWave.caching.assetsPath + "/shaders/fluid/fluid_wave.frag.qsb"
}
