pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "AttachedGeometry.js" as Geometry

// Wayland regions are integer rectangles, so approximate only the top cubics
// with 32 strips; the body and lower corners retain native rounded regions.
Region {
    id: root
    required property var surface
    property bool shown: surface.visible
    readonly property real blend: surface.attachment
    readonly property real depth: Math.min(surface.radius, surface.height / 2, surface.width / 2) * (1 - blend) + surface.shoulder
    function edge(y) {
        const r = Math.min(surface.radius, surface.height / 2, surface.width / 2)
        return Geometry.topEdge(r * (1 - blend) - surface.shoulder, depth, y)
    }
    x: Math.round(surface.x)
    y: Math.round(surface.y)
    width: shown ? Math.round(surface.width) : 0
    height: shown ? Math.round(surface.height) : 0
    radius: Math.round(surface.radius)
    topLeftRadius: Math.ceil(depth)
    topRightRadius: Math.ceil(depth)
    component Strip: Region {
        required property int index
        readonly property real edge: root.edge(root.depth * (index + 0.5) / 32)
        x: Math.round(root.surface.x + edge)
        y: Math.floor(root.surface.y + root.depth * index / 32)
        width: root.shown && root.blend > 0 ? Math.max(0, Math.round(root.surface.width - 2 * edge)) : 0
        height: Math.ceil(root.depth / 32)
    }
    Strip { index: 0 }
    Strip { index: 1 }
    Strip { index: 2 }
    Strip { index: 3 }
    Strip { index: 4 }
    Strip { index: 5 }
    Strip { index: 6 }
    Strip { index: 7 }
    Strip { index: 8 }
    Strip { index: 9 }
    Strip { index: 10 }
    Strip { index: 11 }
    Strip { index: 12 }
    Strip { index: 13 }
    Strip { index: 14 }
    Strip { index: 15 }
    Strip { index: 16 }
    Strip { index: 17 }
    Strip { index: 18 }
    Strip { index: 19 }
    Strip { index: 20 }
    Strip { index: 21 }
    Strip { index: 22 }
    Strip { index: 23 }
    Strip { index: 24 }
    Strip { index: 25 }
    Strip { index: 26 }
    Strip { index: 27 }
    Strip { index: 28 }
    Strip { index: 29 }
    Strip { index: 30 }
    Strip { index: 31 }
}
