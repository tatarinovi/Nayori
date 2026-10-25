import QtQuick

// Один набор ролей. Компоненты берут их отсюда и не пишут hex сами.
// Графит с холодным фиолетовым подтоном, пыльная лаванда, пыльная роза,
// тёплый почти-белый текст. Значения посчитаны в oklch и записаны как sRGB.
QtObject {
    id: root
    property bool animationsEnabled: true
    readonly property QtObject color: QtObject {
        readonly property color background: "#121217"   // oklch(0.185 0.010 286) земля панели
        readonly property color surface: "#4F4F57"      // oklch(0.430 0.014 286) поднятые заглушки
        readonly property color surfaceAlt: "#443D4E"   // oklch(0.375 0.030 304) тело капсулы
        readonly property color text: "#F0E9DB"         // oklch(0.935 0.020 82)
        readonly property color textMuted: "#D5CEC4"    // oklch(0.855 0.016 80)
        readonly property color accent: "#C0AFD1"       // oklch(0.780 0.050 308) лаванда
        readonly property color accentSoft: "#80758C"   // oklch(0.580 0.038 308) та же лаванда, тише
        readonly property color secondary: "#CAA7AA"    // oklch(0.760 0.042 12) пыльная роза
        readonly property color border: "#57F0E9DB"     // тёплый текст на 34%
        readonly property color shadow: "#6B05060A"
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
    }
}
