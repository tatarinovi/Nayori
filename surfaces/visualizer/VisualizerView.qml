// Modified for Nayori on 2026-11-11: shared audio and existing wallpaper palette.
pragma ComponentBehavior: Bound
import QtQuick
import "vendor"

// Ryoku's GPU view with injected Nayori services. Manual ramps retain the
// original shading; automatic colours use Nayori's existing wallpaper accent
// and token palette instead of Ryoku's spatial luminance sampler.
Item {
    id: root

    // The instance this surface paints. Every per-viz knob is read from here, so
    // one draw path serves the primary and each extra visualiser alike.
    required property VizItem cfg
    required property var sourceAudio
    required property var tokens
    property color paletteAccent: tokens.color.accent
    property int frameRate: 30
    property bool adaptive: true

    // The stable instance id is independent of the roster position. Repeater
    // delegates can move after a delete without inheriting another view's
    // preview, selection, or governor state.
    required property string instanceId
    required property int index

    readonly property string style: root.cfg.styleId
    readonly property bool aura: root.style === "aura"
    readonly property bool polar: field.polar
    readonly property var preview: null

    // What the placement overlay needs: the look's box, and a colour lit for the
    // same wallpaper. The edge field owns the whole screen, like the frame, so
    // its box is the screen itself.
    readonly property rect boxRect: root.aura ? Qt.rect(0, 0, root.width, root.height)
        : field.boxRect
    readonly property color guide: root.ramp.length > 0 ? root.ramp[root.ramp.length - 1] : "white"

    AuraMotion {
        id: auraMotion
        cfg: root.cfg
        sourceAudio: root.sourceAudio
        frameRate: root.frameRate
        adaptive: root.adaptive
        reduceMotion: root.tokens.motion.off
        active: root.visible && !root.tokens.motion.off && root.aura
    }

    Motion {
        id: motion
        cfg: root.cfg
        sourceAudio: root.sourceAudio
        frameRate: root.frameRate
        adaptive: root.adaptive
        reduceMotion: root.tokens.motion.off
        style: root.style
        active: root.visible && !root.tokens.motion.off && !root.aura
    }

    readonly property var ramp: {
        // A two-stop gradient wins: eight stops sweep from the first pinned colour
        // to the second across the spectrum, exactly as chosen, no wallpaper relight.
        if (root.cfg.gradient) {
            var g0 = root.cfg.customColor;
            var g1 = root.cfg.color2Value;
            var grad = [];
            for (var j = 0; j < 8; j++)
                grad.push(Qt.tint(g0, Qt.rgba(g1.r, g1.g, g1.b, j / 7)));
            return grad;
        }
        // A single pinned colour is respected exactly: the same gentle bass->treble
        // walk the wallpaper ramp uses, but no re-lighting against the picture.
        if (root.cfg.hasCustomColor) {
            var base = root.cfg.customColor;
            var pinned = [];
            for (var k = 0; k < 8; k++) {
                var tk = k / 7;
                var fk = 1 + (tk - 0.5) * 0.36;
                pinned.push(fk >= 1 ? Qt.lighter(base, fk) : Qt.darker(base, 1 / fk));
            }
            return pinned;
        }
        return [Qt.darker(root.paletteAccent, 1.15), root.paletteAccent,
                Qt.lighter(root.paletteAccent, 1.25), root.tokens.color.text];
    }

    SpectrumField {
        id: field
        anchors.fill: parent
        visible: !root.aura

        levels: motion.levels
        peaks: motion.peaks
        energy: motion.energy
        fade: motion.fade
        ramp: root.ramp

        style: root.style
        shape: root.cfg.shape
        thickness: root.cfg.thickness
        reflection: root.cfg.reflection
        segments: root.cfg.segments
        // cfg owns the rule, so the bar dims the switch this binding ignores.
        peakCaps: root.cfg.peaks && root.cfg.peaksApply
        glow: root.cfg.bloom
        boxX: root.preview ? root.preview.x : root.cfg.x
        boxY: root.preview ? root.preview.y : root.cfg.y
        boxW: root.cfg.w
        boxH: root.cfg.h
        grow: root.cfg.grow
        angle: root.cfg.angle
        tiltX: root.cfg.tiltX
        tiltY: root.cfg.tiltY
        spin: motion.spinDeg
    }

    // The edge field: one pass over the whole screen, lit by the same wallpaper
    // the bars are, as a triad rather than an eight-stop ramp. A complete
    // pinned triad wins exactly as chosen; one pinned colour is respected the
    // way every other look respects it - the field walks that one hue - and
    // only with nothing pinned does the wallpaper light it.
    readonly property var auraTriad: {
        if (root.cfg.hasAuraTriad)
            return [root.cfg.customColor, root.cfg.auraColor2, root.cfg.auraColor3];
        if (root.cfg.hasCustomColor) {
            var base = root.cfg.customColor;
            return [Qt.darker(base, 1.25), base, Qt.lighter(base, 1.25)];
        }
        return [Qt.darker(root.paletteAccent, 1.15), root.paletteAccent, root.tokens.color.text];
    }

    AuraField {
        id: auraField
        anchors.fill: parent
        visible: root.aura

        bands: auraMotion.bands
        peaks: auraMotion.peaks
        energy: auraMotion.energy
        pulse: auraMotion.pulse
        onset: auraMotion.onset
        phase: auraMotion.phase

        edges: root.cfg.auraEdges
        depth: root.cfg.auraDepth
        span: root.cfg.auraSpan
        taper: root.cfg.auraTaper
        cornerRadius: root.cfg.auraCornerRadius
        join: root.cfg.auraJoin
        cornerBlend: root.cfg.auraCornerBlend
        flow: root.cfg.auraFlow
        material: root.cfg.auraMaterial
        shape: root.cfg.auraShape
        effect: root.cfg.auraEffect
        effectStrength: root.cfg.auraEffectStrength
        colorMode: root.cfg.auraColorMode
        colorSpeed: root.cfg.auraColorSpeed
        bodyOpacity: root.cfg.auraBodyOpacity
        crestStrength: root.cfg.auraCrestStrength
        glow: root.cfg.auraGlow
        glowSpread: root.cfg.auraGlowSpread
        audioRange: root.cfg.auraAudioRange
        thickness: root.cfg.auraThickness
        detail: root.cfg.auraDetail
        bassDrive: root.cfg.auraBassDrive
        trebleDrive: root.cfg.auraTrebleDrive
        transientStrength: root.cfg.auraTransient
        beatGlow: root.cfg.auraBeatGlow
        compression: root.cfg.auraCompression
        sensitivity: root.cfg.auraSensitivity
        idleMotion: root.cfg.auraIdleMotion
        pulseStrength: 0.9
        primaryColor: root.auraTriad[0]
        secondaryColor: root.auraTriad[1]
        tertiaryColor: root.auraTriad[2]
        opacity: root.cfg.auraOpacity
    }
}
