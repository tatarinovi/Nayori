pragma ComponentBehavior: Bound
import QtQuick
import "NaomiPixelArt.js" as Art
import "../../services/companion/NaomiBehavior.js" as Pet

// Approved Hoodie #03, including the corrected nose and smile. Indexed pixels only.
Item {
    id: root
    required property var tokens
    property bool active: true
    property bool animationsEnabled: true
    property bool followPointer: false
    property bool pointerTracking: false
    property real pet: 0
    property real petLean: 0
    property point look: Qt.point(0,0)
    readonly property bool reduced: tokens.motion.off || !animationsEnabled
    readonly property bool moving: active && visible && !reduced
    property int tick: 0
    readonly property real breath: moving ? (1-Math.cos(tick*Math.PI*2/40))/2 : 0
    readonly property int tailAngle: moving ? Math.round(2*Math.sin(tick*Math.PI*2/51)) : 0
    readonly property int fringeOffset: moving ? Math.round(Math.sin(tick*Math.PI*2/43)) : 0
    readonly property int ribbonOffset: moving ? Math.round(Math.sin(tick*Math.PI*2/33)) : 0
    readonly property real eyeOpen: moving && tick % 57 === 39 ? 0 : 1
    readonly property int pixelSize: Math.max(1,Math.floor(Math.min(width/Art.width,height/Art.height)))
    readonly property rect headRect: Qt.rect(drawing.x+Art.headZone.x*pixelSize,drawing.y+Art.headZone.y*pixelSize,Art.headZone.w*pixelSize,Art.headZone.h*pixelSize)
    readonly property point bubbleAnchor: Qt.point(drawing.x+Art.bubblePoint.x*pixelSize,drawing.y+Art.bubblePoint.y*pixelSize)
    readonly property bool pointerInside: pointer.hovered
    readonly property point gaze: {
        if (reduced) return Qt.point(0,0)
        if (pet>0.3) return Qt.point(petLean,0.2)
        if ((followPointer || pointerTracking) && pointer.hovered)
            return Qt.point(Math.max(-1,Math.min(1,(pointer.point.position.x-headRect.x-headRect.width/2)/(headRect.width/2))),
                            Math.max(-1,Math.min(1,(pointer.point.position.y-headRect.y-headRect.height/2)/(headRect.height/2))))
        return look
    }
    readonly property var inks: Art.paletteFor(tokens.color.accent,tokens.color.accentSoft)
    readonly property var cells: Art.render({rise:Math.round(breath),tail:tailAngle,
        fringe:fringeOffset,ribbon:ribbonOffset,blink:eyeOpen<0.5,happy:pet>0.5,look:Math.round(gaze.x)})
    signal pointerMoved(real x,real y)
    implicitWidth: 280
    implicitHeight: 400
    onMovingChanged: if (!moving) tick=0
    onCellsChanged: drawing.requestPaint()
    onInksChanged: drawing.requestPaint()
    onPixelSizeChanged: drawing.requestPaint()
    Timer { interval:125; repeat:true; running:root.moving; onTriggered:root.tick=(root.tick+1)%116280 }
    HoverHandler {
        id: pointer
        enabled: root.followPointer || root.pointerTracking
        onPointChanged: {
            if (!hovered || root.headRect.width<=0) return
            const zone=Pet.zone()
            root.pointerMoved(zone.x+(point.position.x-root.headRect.x)/root.headRect.width*zone.w,
                              zone.y+(point.position.y-root.headRect.y)/root.headRect.height*zone.h)
        }
    }
    Canvas {
        id: drawing
        anchors { horizontalCenter:parent.horizontalCenter; bottom:parent.bottom }
        width: Art.width*root.pixelSize
        height: Art.height*root.pixelSize
        antialiasing:false
        smooth:false
        onPaint: {
            const ctx=getContext("2d"),s=root.pixelSize
            ctx.reset()
            ctx.clearRect(0,0,width,height)
            for(const run of root.cells) {
                ctx.fillStyle=root.inks[run[3]]
                ctx.fillRect(run[0]*s,run[1]*s,run[2]*s,s)
            }
        }
    }
}
