import QtQuick
import "AccentRoles.js" as AccentRoles

// Один набор ролей. Компоненты берут их отсюда и не пишут hex сами.
// Графит с холодным фиолетовым подтоном, пыльная лаванда, пыльная роза,
// тёплый почти-белый текст. Значения посчитаны в oklch и записаны как sRGB.
QtObject {
    id: root
    property bool animationsEnabled: true
    property string colorScheme: "dark"
    readonly property bool light: colorScheme === "light"
    property string surfaceStyle: "solid"
    // Исходный акцент не переписывается. accentDerived включает расчёт AccentRoles.
    property color accentSource: "#C0AFD1"
    property bool accentDerived: false
    // neutralDerived false — авторский графит. true — фон и поверхности из обоев.
    property color backgroundSource: "#121217"
    property color surfaceSource: "#4F4F57"
    property color surfaceAltSource: "#443D4E"
    property bool neutralDerived: false
    readonly property var accentRoles: AccentRoles.roles(root.accentSource, root.accentDerived, root.light, root.color.surfaceAlt)
    readonly property bool frosted: surfaceStyle === "frosted"
    // Frosted graphite keeps its alpha and takes RGB from color.background.
    function graphite(alphaByte) {
        const value = root.color.background
        function channel(amount) {
            const byte = Math.max(0, Math.min(255, Math.round(amount * 255)))
            const text = byte.toString(16).toUpperCase()
            return text.length === 1 ? "0" + text : text
        }
        return "#" + channel(alphaByte / 255) + channel(value.r) + channel(value.g) + channel(value.b)
    }
    // Material fills only: never apply opacity to the whole surface or its text.
    readonly property QtObject material: QtObject {
        readonly property color panel: root.frosted ? root.graphite(0xB5) : root.color.surfaceAlt
        readonly property color island: root.frosted ? root.graphite(0xCC) : root.color.surfaceAlt
        readonly property color islandExpanded: root.frosted ? root.graphite(0xCC) : root.color.background
        readonly property color dense: root.frosted ? root.graphite(0xEB) : root.color.background
        readonly property color menu: root.frosted ? root.graphite(0xEB) : root.color.surfaceAlt
        readonly property color sidebar: root.frosted ? (root.light ? "#0C000000" : "#0CFFFFFF") : Qt.tint(root.color.background, root.light ? "#08000000" : "#0CFFFFFF")
    }
    readonly property QtObject color: QtObject {
        readonly property color background: root.light ? (root.neutralDerived ? AccentRoles.lightNeutral(root.backgroundSource, 0.965) : "#F6F3F8") : root.neutralDerived ? root.backgroundSource : "#121217"   // oklch(0.185 0.010 286) земля панели
        readonly property color surface: root.light ? (root.neutralDerived ? AccentRoles.lightNeutral(root.surfaceSource, 0.88) : "#DED8E5") : root.neutralDerived ? root.surfaceSource : "#4F4F57"      // oklch(0.430 0.014 286) поднятые заглушки
        readonly property color surfaceAlt: root.light ? (root.neutralDerived ? AccentRoles.lightNeutral(root.surfaceAltSource, 0.93) : "#EBE5F0") : root.neutralDerived ? root.surfaceAltSource : "#443D4E"   // oklch(0.375 0.030 304) тело капсулы
        readonly property color text: root.light ? "#292430" : "#F0E9DB"         // oklch(0.935 0.020 82)
        readonly property color textMuted: root.light ? "#62596C" : "#D5CEC4"    // oklch(0.855 0.016 80)
        // accentDerived false — авторские sRGB. true — роли из accentSource, без сдвига оттенка.
        readonly property color accent: (root.light || root.accentDerived) ? root.accentRoles.accent : "#C0AFD1"       // oklch(0.780 0.050 308) лаванда
        readonly property color accentSoft: (root.light || root.accentDerived) ? root.accentRoles.accentSoft : "#80758C"   // oklch(0.580 0.038 308) та же лаванда, тише
        readonly property color accentHover: (root.light || root.accentDerived) ? root.accentRoles.accentHover : "#80758C"
        readonly property color accentText: (root.light || root.accentDerived) ? root.accentRoles.accentText : "#121217"
        // Чернила на accentSoft. Без расчёта это тот же text: #F0E9DB на #80758C.
        readonly property color accentSoftText: (root.light || root.accentDerived) ? root.accentRoles.accentSoftText : "#F0E9DB"
        readonly property color menuIcon: AccentRoles.accentOnSurface(accent, surfaceAlt)
        readonly property color accentBorder: (root.light || root.accentDerived) ? root.accentRoles.accentBorder : "#C0AFD1"
        readonly property color secondary: root.light ? "#85565E" : "#CAA7AA"    // oklch(0.760 0.042 12) пыльная роза
        readonly property color border: root.light ? "#57292430" : "#57F0E9DB"     // тёплый текст на 34%
        readonly property color shadow: root.light ? "#2605060A" : "#6B05060A"
    }

    // Stable silver fur in both themes; only the tail tip follows the system accent.
    readonly property QtObject fox: QtObject {
        readonly property color body: "#B4BCC9"
        readonly property color light: "#F4F0E8"
        readonly property color shade: "#8D98AB"
        readonly property color dark: "#535B70"
        readonly property color eye: "#292C39"
    }

    readonly property QtObject spacing: QtObject {
        readonly property int small: 8
        readonly property int medium: 16
        readonly property int large: 24
    }

    readonly property QtObject radius: QtObject {
        readonly property int small: 6
        readonly property int medium: 12
        readonly property int capsule: 999
    }

    // Literata — установленный литературный антиквенный набор. Inter — текст панели.
    readonly property QtObject type: QtObject {
        readonly property QtObject display: QtObject {
            readonly property string family: "Literata"
            readonly property int size: 18
            readonly property int weight: 500
            readonly property real letterSpacing: -0.36
            readonly property real lineHeight: 1.1
        }
        readonly property QtObject body: QtObject {
            readonly property string family: "Inter"
            readonly property int size: 14
            readonly property int weight: 500
            readonly property real letterSpacing: 0
            readonly property real lineHeight: 1.4
        }
        readonly property QtObject small: QtObject {
            readonly property string family: "Inter"
            readonly property int size: 13
            readonly property int weight: 500
            readonly property real letterSpacing: 0.45
            readonly property real lineHeight: 1.3
        }
    }

    readonly property QtObject panel: QtObject {
        readonly property int control: 32
        readonly property int height: 48
        readonly property int padding: 8
        readonly property int gap: 4
    }

    // Settings-only density: panel and island typography remains unchanged.
    readonly property QtObject settings: QtObject {
        readonly property int body: 16
        readonly property int heading: 32
        readonly property int control: 44
    }

    readonly property QtObject motion: QtObject {
        // One switch for ornamental motion; state changes remain immediate.
        property bool off: !root.animationsEnabled
        readonly property int fast: 140
        readonly property int base: 220
        readonly property var easeOut: [0.23, 1, 0.32, 1, 1, 1]
    }
}
