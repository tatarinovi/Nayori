import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-11: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets









Item {
    readonly property var nayoriIrisWidgetFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    property var widget: nayoriIrisWidgetFace.shimaWidget
    property color light: "transparent"
    property real padding: root.dp(16)
    default property alias content: body.data
    // Ryoku host mode: skip the face's own plate/shadow/wash so the hosting Ryoku
    // WidgetSlot owns the backing and the colour-mode ink mask reaches the glyphs.
    // Defaults off, so the iRiS desktop frame is unchanged.
    property bool ryokuBare: false

    readonly property string size: root.widget.irisSize
    readonly property bool small: root.size === "small"
    readonly property bool medium: root.size === "medium"
    readonly property bool large: root.size === "large"
    readonly property real k: nayoriIrisWidgetFace.irisStyle.density * root.widget.scaleFactor
    readonly property real t: nayoriIrisWidgetFace.irisStyle.typeScale * root.widget.scaleFactor
    readonly property real radius: root.widget.cornerRadiusOverride >= 0
        ? root.widget.cornerRadiusOverride : Math.round(root.widget.widgetCardRadius * root.widget.scaleFactor)
    readonly property real innerRadius: Math.max(root.dp(6), root.radius - root.padding)
    readonly property real gap: root.dp(10)
    readonly property real contentWidth: root.width - root.padding * 2
    // Under Ryoku hosting the widget instance is a deliberately invisible data
    // source and the slot renders the face, so the host itself is the
    // visibility: without this the face reads live=false forever, the clock
    // drops to minute precision and the second hand freezes.
    readonly property bool live: root.widget.powerActive && (root.widget.visible || root.widget.ryokuHosted)
    // Seen: the desktop under the face is showing. Seconds, positions and ticking data follow this, not `live`:
    // behind windows each tick redraws the whole desktop window for nobody (rules/background.md).
    readonly property bool moving: root.live && root.widget.motionActive

    readonly property string material: root.widget.irisMaterial
    readonly property bool glass: root.material === "glass"
    readonly property bool clear: root.material === "clear"
    readonly property bool opaque: !root.glass && !root.clear
    readonly property real strength: root.widget.irisSurfaceOpacity
    // Glass and transparent faces over a light region turn over: frost and near-black ink instead of
    // a veil darkened until the glass is gone. An opaque plate keeps its own polarity.
    // In the light scheme a plate is light, so its ink is the dark one; a bare widget still follows the wallpaper.
    // A glass face is the shell's material in every scheme, veiled as reading needs: turning it white over a bright region
    // left white cards among a dark shell. Only a transparent face, which has no material, follows the wallpaper.
    readonly property bool lightBackdrop: nayoriIrisWidgetFace.irisStyle.light && !root.clear ? true : root.clear ? root.widget.inkOnLight
        : root.widget.forceDarkInk
    readonly property bool ownInk: root.lightBackdrop || (nayoriIrisWidgetFace.irisStyle.light && root.clear)
    // A paper scheme's face is the shell's paper with the shell's own ink and accents, as the quick-controls sheet is;
    // the light-backdrop path (white frost, accents deepened to 0.3-0.4 lightness) turned orange brown there.
    readonly property bool paper: nayoriIrisWidgetFace.irisStyle.light && !root.clear
    readonly property real textShadow: root.clear ? 1
        : root.glass && !root.widget.legibleAlways ? Math.min(1, (1 - root.strength) * 1.4) : 0
    readonly property real veil: root.opaque ? root.strength
        : root.clear && !root.widget.legibleAlways ? 0
        : (root.paper ? nayoriIrisWidgetFace.irisStyle.legibleVeil(root.readMaterial, root.frostLevel, root.readSpread, 1)
            : root.lightBackdrop ? nayoriIrisWidgetFace.irisStyle.legibleFrost(root.readMaterial, root.frostLevel, root.readSpread, 1)
            : nayoriIrisWidgetFace.irisStyle.legibleVeil(root.readMaterial, root.readLevel, root.readSpread, 1))
            * (root.widget.legibleAlways ? 1 : root.paperGlass ? 0.52 + 0.48 * root.strength : root.strength)
    // On paper, Surface opacity thins a frost; it never turns the face into clear glass lit by the wallpaper's colour.
    readonly property bool paperGlass: root.paper && root.glass
    // Lume on every widget: the veil (light ink) is solved as if the region were bright and busy, the frost
    // (dark ink) as if it were dim and busy.
    readonly property real readLevel: root.widget.legibleAlways ? Math.max(0.72, root.widget.regionBrightness) : root.widget.regionBrightness
    // ...and to the contrast of a reading panel (7:1), so Transparent and Glass both carry a real backing.
    readonly property string readMaterial: root.widget.legibleAlways ? "panel" : root.material
    readonly property real frostLevel: root.widget.legibleAlways ? Math.min(0.5, root.widget.regionBrightness) : root.widget.regionBrightness
    readonly property real readSpread: root.widget.legibleAlways ? Math.max(0.24, root.widget.regionBrightnessSpread) : root.widget.regionBrightnessSpread

    // One palette: the widget's data colours and the shell's status colours. Only a face that is not paper and sits over a
    // light region (a transparent face, or forced dark ink) solves them again, against what Lume read behind it.
    readonly property bool resolvesMarks: root.lightBackdrop && !root.paper
    readonly property real seenLevel: root.clear ? root.widget.regionBrightness
        : root.widget.regionBrightness * (1 - root.veil) + Math.pow(nayoriIrisWidgetFace.colorUtils.relativeLuminance(nayoriIrisWidgetFace.irisStyle.frost), 1 / 2.2) * root.veil
    function mark(seed: color): color {
        return root.resolvesMarks ? Lume.mark(seed, root.seenLevel, root.clear ? root.readSpread : 0, true, 3) : seed
    }
    readonly property color accent: root.mark(root.widget.irisAccent)
    readonly property color highlight: root.mark(root.widget.irisAccent3)
    readonly property color accent2: root.mark(root.widget.irisAccent2)
    readonly property color warm: root.mark(nayoriIrisWidgetFace.irisStyle.secondaryAccent)
    readonly property color danger: root.mark(nayoriIrisWidgetFace.irisStyle.danger)
    readonly property color ink: root.widget.ryokuInkOverride !== undefined && root.widget.ryokuInkOverride.a > 0
        ? root.widget.ryokuInkOverride : (root.paper ? nayoriIrisWidgetFace.irisStyle.text : root.lightBackdrop ? nayoriIrisWidgetFace.irisStyle.inkOnLight : nayoriIrisWidgetFace.irisStyle.light ? nayoriIrisWidgetFace.irisStyle.inkOnDark : nayoriIrisWidgetFace.irisStyle.text)
    readonly property color inkSecondary: nayoriIrisWidgetFace.irisStyle.secondaryOf(root.ink)
    readonly property color inkTertiary: nayoriIrisWidgetFace.irisStyle.tertiaryOf(root.ink)
    readonly property color fillQuiet: root.ownInk ? nayoriIrisWidgetFace.irisStyle.fillQuietOf(root.ink) : nayoriIrisWidgetFace.irisStyle.fillQuiet
    readonly property color fill: root.ownInk ? nayoriIrisWidgetFace.irisStyle.fillOf(root.ink) : nayoriIrisWidgetFace.irisStyle.fill
    readonly property color fillHover: root.ownInk ? nayoriIrisWidgetFace.irisStyle.fillHoverOf(root.ink) : nayoriIrisWidgetFace.irisStyle.fillHover
    readonly property color fillActive: root.ownInk ? nayoriIrisWidgetFace.irisStyle.fillActiveOf(root.ink) : nayoriIrisWidgetFace.irisStyle.fillActive
    readonly property color hairline: root.ownInk ? nayoriIrisWidgetFace.irisStyle.hairlineOf(root.ink) : nayoriIrisWidgetFace.irisStyle.hairline
    // Ink on a filled accent: light on the deep accents of a light face, the Island's dark otherwise.
    function onFill(tint: color): color { return nayoriIrisWidgetFace.irisStyle.onTintFor(tint) }
    readonly property int figureWeight: root.widget.widgetTitleWeight
    readonly property string fontMain: nayoriIrisWidgetFace.irisStyle.fontMain
    readonly property string fontNumbers: nayoriIrisWidgetFace.irisStyle.fontNumbers
    // Outline: Auto follows the shell's outline and leaves Transparent bare; while arranging it always shows.
    readonly property bool rimShown: nayoriIrisWidgetFace.globalStates.widgetEditMode || root.widget.irisOutline === "always"
        || (root.widget.irisOutline === "auto" && (!root.clear || root.widget.irisRim))
    readonly property bool glassEdge: (root.glass || nayoriIrisWidgetFace.irisStyle.edgeLit) && !root.lightBackdrop
        && (nayoriIrisWidgetFace.irisStyle.glassEdgeLight > 0 || nayoriIrisWidgetFace.irisStyle.glassEdgeLine > 0)
    readonly property bool flatRim: root.rimShown && !root.glassEdge
        && !(root.glass && !root.lightBackdrop && root.widget.irisOutline === "auto" && !nayoriIrisWidgetFace.globalStates.widgetEditMode)
    readonly property color plateColor: nayoriIrisWidgetFace.colorUtils.applyAlpha(root.opaque ? root.widget.irisPlate
        : root.lightBackdrop && !root.paper ? nayoriIrisWidgetFace.irisStyle.frost : nayoriIrisWidgetFace.irisStyle.surface, root.veil)
    readonly property color knockout: root.opaque ? root.plateColor : root.lightBackdrop && !root.paper ? nayoriIrisWidgetFace.irisStyle.frost : nayoriIrisWidgetFace.irisStyle.surface

    // In a stack the plate stays and the pages' contents slide over it (DesktopWidgetStacks).
    readonly property bool stacked: root.widget.stacked
    readonly property real slide: root.widget.stackPos
    readonly property bool plated: !root.stacked || root.widget.stackShown

    function dp(value: real): real { return Math.round(value * root.k) }
    function px(value: real): real { return Math.round(value * root.t) }

    // A shadow under glass shows through it: the body darkens toward its middle and its top edge reads as a glow.
    RectangularShadow {
        anchors.fill: parent
        visible: !root.clear && !root.ryokuBare && root.plated
        radius: root.radius
        blur: root.dp(28)
        spread: -root.dp(4)
        offset.y: root.dp(8)
        color: root.glass ? nayoriIrisWidgetFace.irisStyle.glassShadow : nayoriIrisWidgetFace.irisStyle.plateShadow
    }

    Loader {
        anchors.fill: parent
        active: root.glass && !root.ryokuBare
        visible: root.plated
        sourceComponent: ClippingRectangle {
            id: glassPane
            // The desktop's own wallpaper layer, parallax included, no second decoder. It is copied again only when
            // the layer or this widget moved: copying it every frame the desktop redraws (music playing, a clock)
            // cost the shell 17 % CPU with Afterglow against 6 % for solid widgets.
            readonly property var host: root.QsWindow?.window ?? null
            readonly property Item desktopLayer: glassPane.host?.wallpaperLayer ?? null
            readonly property int layerRevision: glassPane.host?.wallpaperLayerRevision ?? 0
            readonly property bool moving: settling.running || nayoriIrisWidgetFace.globalStates.widgetEditMode
                || Boolean(glassPane.host?.wallpaperLayerAnimating)
            readonly property point at: {
                void (root.widget.ryokuScreenX + root.widget.ryokuScreenY + (root.widget.parent?.x ?? 0) + (root.widget.parent?.y ?? 0))
                return glassPane.desktopLayer ? root.mapToItem(glassPane.desktopLayer, 0, 0) : Qt.point(root.widget.ryokuScreenX, root.widget.ryokuScreenY)
            }
            // Parallax and Afterglow's fade run up to about a second after the bump that announced them.
            Timer { id: settling; interval: 1500 }
            onLayerRevisionChanged: settling.restart()
            onAtChanged: crop.scheduleUpdate()
            onWidthChanged: crop.scheduleUpdate()
            onHeightChanged: crop.scheduleUpdate()
            visible: glassPane.desktopLayer !== null || wallpaper.status === Image.Ready
            radius: root.radius
            color: "transparent"
            readonly property real margin: root.dp(24)

            Image {
                id: wallpaper
                visible: false
                width: root.widget.screenWidth
                height: root.widget.screenHeight
                source: glassPane.desktopLayer ? "" : nayoriIrisWidgetFace.wallpaperSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: Math.round(root.widget.screenWidth / 2)
                sourceSize.height: Math.round(root.widget.screenHeight / 2)
                onStatusChanged: crop.scheduleUpdate()
            }

            ShaderEffectSource {
                id: crop
                x: -glassPane.margin
                y: -glassPane.margin
                width: root.width + glassPane.margin * 2
                height: root.height + glassPane.margin * 2
                sourceItem: glassPane.desktopLayer ?? wallpaper
                live: glassPane.moving
                sourceRect: Qt.rect(glassPane.at.x - glassPane.margin, glassPane.at.y - glassPane.margin, crop.width, crop.height)
                textureSize: Qt.size(Math.max(1, Math.round(crop.width / 2)), Math.max(1, Math.round(crop.height / 2)))
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: nayoriIrisWidgetFace.irisStyle.glassBlurAmount
                    blurMax: nayoriIrisWidgetFace.irisStyle.glassBlurMax
                    saturation: nayoriIrisWidgetFace.irisStyle.widgetGlassSaturation
                }
            }
        }
    }

    Rectangle {
        visible: !root.ryokuBare && root.plated
        anchors.fill: parent
        radius: root.radius
        color: root.plateColor
        border.width: root.flatRim ? 1 : 0
        border.color: root.lightBackdrop ? root.hairline : root.clear || nayoriIrisWidgetFace.irisStyle.rim.a === 0 ? nayoriIrisWidgetFace.irisStyle.clearRim : nayoriIrisWidgetFace.irisStyle.rim
        Behavior on color { ColorAnimation { duration: nayoriIrisWidgetFace.irisStyle.revealDuration; easing.type: nayoriIrisWidgetFace.irisStyle.feedbackEasing } }
        Behavior on border.width { NumberAnimation { duration: nayoriIrisWidgetFace.irisStyle.revealDuration; easing.type: nayoriIrisWidgetFace.irisStyle.feedbackEasing } }
    }

    // Light leak: the plate is film exposed by the shell's one light, as the field's bodies are. It replaces the plate's
    // flat colour (and its outline: an edge the light reaches burns instead) and keeps its opacity.
    Loader {
        anchors.fill: parent
        active: nayoriIrisWidgetFace.irisStyle.leak && root.plated && !root.clear
        sourceComponent: IrisLeakPlate {
            strength: nayoriIrisWidgetFace.irisStyle.leakWidgets
            at: {
                void (root.widget.x + root.widget.y + (root.widget.parent?.x ?? 0) + (root.widget.parent?.y ?? 0) + root.width + root.height)
                return root.mapToItem(null, 0, 0)
            }
            output: Qt.size(root.widget.screenWidth, root.widget.screenHeight)
            radius: root.radius
            base: root.plateColor
        }
    }

    IrisGlassEdge {
        anchors.fill: parent
        visible: root.glassEdge && root.rimShown && root.plated
        radius: root.radius
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: !root.clear && root.light.a > 0 && !root.ryokuBare
        opacity: (root.glass ? nayoriIrisWidgetFace.irisStyle.glassWash : 1) * (1 - Math.min(1, Math.abs(root.slide)))
        radius: Math.max(0, root.radius - 1)
        gradient: Gradient {
            GradientStop { position: 0; color: nayoriIrisWidgetFace.irisStyle.skyWash(root.light) }
            GradientStop { position: 1; color: nayoriIrisWidgetFace.irisStyle.skyWashFade(root.light) }
        }
    }

    // Pages slide inside the plate's box and are cut at its edge while they move.
    Item {
        id: viewport
        anchors.fill: parent
        clip: root.stacked && root.slide !== 0

        Item {
            id: slider
            width: viewport.width
            height: viewport.height
            // The page travels half its height while it fades, so two pages cross instead of one pushing the other out.
            y: Math.round(root.slide * root.height * 0.5)
            opacity: 1 - Math.pow(Math.min(1, Math.abs(root.slide)), 1.5)

            ShaderEffectSource {
                id: bodyCopy
                anchors.fill: body
                sourceItem: root.textShadow > 0.05 ? body : null
                hideSource: false
                visible: false
            }
            // The shadow comes from a copy behind the body: a layered body would resample its text.
            MultiEffect {
                x: body.x
                y: body.y + 1
                width: body.width
                height: body.height
                visible: root.textShadow > 0.05
                source: bodyCopy
                brightness: root.lightBackdrop ? 1 : -1
                colorization: nayoriIrisWidgetFace.irisStyle.glow > 0 && !root.lightBackdrop ? 1 : 0
                colorizationColor: Qt.rgba(nayoriIrisWidgetFace.irisStyle.plateShadow.r, nayoriIrisWidgetFace.irisStyle.plateShadow.g, nayoriIrisWidgetFace.irisStyle.plateShadow.b, 1)
                blurEnabled: true
                blur: 0.5
                autoPaddingEnabled: true
                opacity: (root.lightBackdrop ? nayoriIrisWidgetFace.irisStyle.frostShadow : nayoriIrisWidgetFace.irisStyle.plateShadow.a) * root.textShadow
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: root.padding
            }
        }
    }

    // Carried over by another widget: this is where it will land.
    Rectangle {
        z: 140
        anchors.fill: parent
        radius: root.radius
        visible: opacity > 0
        opacity: root.widget.stackDropHint ? 1 : 0
        color: nayoriIrisWidgetFace.irisStyle.tintFill(root.accent)
        border.width: 2
        border.color: root.accent
        Behavior on opacity { NumberAnimation { duration: nayoriIrisWidgetFace.irisStyle.feedbackDuration; easing.type: nayoriIrisWidgetFace.irisStyle.feedbackEasing } }

        Rectangle {
            anchors.centerIn: parent
            width: root.dp(44)
            height: width
            radius: nayoriIrisWidgetFace.irisStyle.iconRadius(width)
            scale: root.widget.stackDropHint ? 1 : 0.8
            Behavior on scale { NumberAnimation { duration: nayoriIrisWidgetFace.irisStyle.feedbackDuration; easing.type: nayoriIrisWidgetFace.irisStyle.feedbackEasing } }
            gradient: Gradient {
                GradientStop { position: 0; color: nayoriIrisWidgetFace.irisStyle.tileTop(root.accent) }
                GradientStop { position: 1; color: root.accent }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: "stacks"
                fill: 1
                iconSize: root.dp(24)
                color: root.onFill(root.accent)
            }
        }
    }

    Loader {
        active: root.stacked
        z: 150
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: active && root.widget.stackShown
        sourceComponent: IrisStackDots { face: root }
    }

    // Wheel over a stack turns its page, one per gesture: a touchpad's tail is held off until the page has settled.
    property real _wheel: 0
    Timer { id: wheelHold; interval: 360 }
    Timer { id: wheelReset; interval: 260; onTriggered: root._wheel = 0 }
    WheelHandler {
        enabled: root.stacked && root.widget.stackShown
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelHold.running)
                return
            root._wheel += event.angleDelta.y
            wheelReset.restart()
            if (Math.abs(root._wheel) < 120)
                return
            const forward = root._wheel < 0
            root._wheel = 0
            wheelHold.restart()
            DesktopWidgetStacks.step(root.widget.outputName, root.widget.stack.id, forward ? 1 : -1)
        }
    }

    // A stack holds its page while the pointer is on it or the widget is being carried.
    HoverHandler {
        id: stackHover
        enabled: root.stacked
    }
    readonly property bool _holding: root.stacked && root.widget.stackShown && (stackHover.hovered || root.widget.containsPress)
    on_HoldingChanged: if (root.stacked) DesktopWidgetStacks.setHovered(root.widget.stack.id, root._holding)
}
