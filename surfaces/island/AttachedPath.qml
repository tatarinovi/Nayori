pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// The body keeps its content coordinates. Only the shoulders extend outwards.
// A single cubic per corner has horizontal/vertical tangents at both ends.
Shape {
    id: root
    property real attachment: 0
    property real cornerRadius: 24
    property color fillColor: "transparent"
    property color strokeColor: "transparent"
    property real strokeWidth: 1
    readonly property real blend: Math.max(0, Math.min(1, attachment))
    readonly property real inset: strokeWidth / 2
    readonly property real r: Math.max(0, Math.min(cornerRadius, width / 2, height / 2) - inset)
    readonly property real shoulder: Math.min(12, width / 4, height / 4) * blend
    readonly property real topStart: r * (1 - blend) - shoulder - inset * blend
    // A concave corner needs a *larger* centreline radius when inset. Its
    // centre stays at (-shoulder, shoulder): inset shifts the horizontal
    // tangent up and the vertical tangent right by the same amount. Thus
    // strokes of any thickness have the same outer edge, entirely inside
    // the silhouette, and meet the screen without a gap or an overhang.
    readonly property real topDepth: r * (1 - blend) + shoulder + inset * blend
    readonly property real topY: inset * (1 - 2 * blend)
    readonly property real shoulderStartX: inset + topStart
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: root.strokeWidth
        strokeColor: root.strokeColor
        fillColor: root.fillColor
        joinStyle: ShapePath.RoundJoin
        capStyle: ShapePath.FlatCap
        startX: root.inset + root.topStart
        startY: root.topY
        PathCubic {
            control1X: root.inset + root.topStart * 0.447715; control1Y: root.topY
            control2X: root.inset; control2Y: root.topY + root.topDepth * 0.447715
            x: root.inset; y: root.topY + root.topDepth
        }
        PathLine { x: root.inset; y: root.height - root.inset - root.r }
        PathCubic {
            control1X: root.inset; control1Y: root.height - root.inset - root.r * 0.447715
            control2X: root.inset + root.r * 0.447715; control2Y: root.height - root.inset
            x: root.inset + root.r; y: root.height - root.inset
        }
        PathLine { x: root.width - root.inset - root.r; y: root.height - root.inset }
        PathCubic {
            control1X: root.width - root.inset - root.r * 0.447715; control1Y: root.height - root.inset
            control2X: root.width - root.inset; control2Y: root.height - root.inset - root.r * 0.447715
            x: root.width - root.inset; y: root.height - root.inset - root.r
        }
        PathLine { x: root.width - root.inset; y: root.topY + root.topDepth }
        PathCubic {
            control1X: root.width - root.inset; control1Y: root.topY + root.topDepth * 0.447715
            control2X: root.width - root.inset - root.topStart * 0.447715; control2Y: root.topY
            x: root.width - root.inset - root.topStart; y: root.topY
        }
        // Filling implicitly closes the contour. In Attached mode the open
        // stroke's outer horizontal tangent touches the screen at y = 0.
    }
    ShapePath {
        strokeWidth: root.strokeWidth
        strokeColor: Qt.alpha(root.strokeColor, root.strokeColor.a * (1 - root.blend))
        fillColor: "transparent"
        capStyle: ShapePath.FlatCap
        startX: root.shoulderStartX
        startY: root.topY
        PathLine { x: root.width - root.shoulderStartX; y: root.topY }
    }
}
