import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.
import QtQuick


// A plate of Light leak film for a surface IrisField does not draw (desktop widgets, IrisSurface): the same light, grain
// and burn as the field's bodies, sampled where the plate sits on its output. Static: it redraws only with its window.
ShaderEffect {
    readonly property var nayoriIrisLeakPlate: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    // Where the plate's top-left sits on its output, and the output's size, in pixels.
    property point at: Qt.point(0, 0)
    property size output: Qt.size(1920, 1080)
    property real radius: 0
    // Top-left, top-right, bottom-right, bottom-left: a notched side has square corners.
    property vector4d corners: Qt.vector4d(root.radius, root.radius, root.radius, root.radius)
    // The plate's own colour: a light one is exposed as photo paper, a dark one as film.
    property color base: nayoriIrisLeakPlate.irisStyle.surface
    // How much of the light this plate catches (desktop widgets: Light leak › Widgets).
    property real strength: 1

    fragmentShader: Qt.resolvedUrl("IrisLeakPlate.frag.qsb")
    readonly property vector4d plate: Qt.vector4d(root.at.x, root.at.y, root.output.width, root.output.height)
    readonly property vector4d body: Qt.vector4d(root.width, root.height, 0, nayoriIrisLeakPlate.irisStyle.leakBody.x)
    readonly property vector4d tone: Qt.vector4d(root.base.r, root.base.g, root.base.b, root.base.a)
    readonly property vector4d leakMix: Qt.vector4d(nayoriIrisLeakPlate.irisStyle.leakMix.x, nayoriIrisLeakPlate.irisStyle.leakMix.y * root.strength, nayoriIrisLeakPlate.irisStyle.leakMix.z, nayoriIrisLeakPlate.irisStyle.leakMix.w)
    readonly property vector4d leakGrain: nayoriIrisLeakPlate.irisStyle.leakFilm
    readonly property vector4d leakStop0: nayoriIrisLeakPlate.irisStyle.leakStop0
    readonly property vector4d leakStop1: nayoriIrisLeakPlate.irisStyle.leakStop1
    readonly property vector4d leakStop2: nayoriIrisLeakPlate.irisStyle.leakStop2
    readonly property vector4d leakStop3: nayoriIrisLeakPlate.irisStyle.leakStop3
    readonly property vector4d leakStop4: nayoriIrisLeakPlate.irisStyle.leakStop4
    readonly property vector4d leakCore: nayoriIrisLeakPlate.irisStyle.leakCore
    readonly property vector4d leakAt0: nayoriIrisLeakPlate.irisStyle.leakAt0
    readonly property vector4d leakAt1: nayoriIrisLeakPlate.irisStyle.leakAt1
    readonly property vector4d leakAt2: nayoriIrisLeakPlate.irisStyle.leakAt2
    readonly property vector4d leakForm0: nayoriIrisLeakPlate.irisStyle.leakForm0
    readonly property vector4d leakForm1: nayoriIrisLeakPlate.irisStyle.leakForm1
    readonly property vector4d leakForm2: nayoriIrisLeakPlate.irisStyle.leakForm2
    readonly property vector4d leakHue0: nayoriIrisLeakPlate.irisStyle.leakHue0
    readonly property vector4d leakHue1: nayoriIrisLeakPlate.irisStyle.leakHue1
    readonly property vector4d leakHue2: nayoriIrisLeakPlate.irisStyle.leakHue2
}
