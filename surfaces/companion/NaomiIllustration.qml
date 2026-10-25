pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "NaomiLayers.js" as Atlas
import "../../services/companion/NaomiBehavior.js" as Pet

// Анимированная Naomi (вариант C) из слоёв assets/naomi/layers.
// Слои вырезаны скриптом scripts/naomi-make-layers.py из оригинальной иллюстрации,
// координаты слоёв — в системе источника 864 × 1152, она же система сцены stage.
// Используется на рабочем столе (CompanionWindow) и в предпросмотре страницы Naomi.
// Поза поглаживания: свойство pet (0…1) плавно закрывает глаза «довольной» дугой, добавляет румянец
// и улыбку, наклоняет голову к руке (petLean), опускает ушки и усиливает покачивание волос.
// Саму поглаживание распознаёт NaomiController по сигналу pointerMoved.
Item {
    id: root
    required property var tokens
    property bool active: true
    property bool animationsEnabled: true
    // Включает отдельные движения. Амплитуда 1 — как задумано, 0 — выключено.
    property real breathAmount: 1
    property real hairSway: 1
    property real scarfFlutter: 1
    property bool blinking: true
    property bool earTwitching: true
    property int blinkMinMs: 3000
    property int blinkMaxMs: 7000
    // Поворот головы и взгляда: от -1 до 1 по каждой оси. Можно задать снаружи.
    property point look: Qt.point(0, 0)
    // Следить за курсором, пока он над компонентом.
    property bool followPointer: false
    // Сообщать о движении курсора (pointerMoved) и слегка поворачивать голову к нему над головой.
    property bool pointerTracking: false
    // Поза поглаживания: 0 — обычная, 1 — полностью довольная. Задаёт NaomiController.
    property real pet: 0
    // К какой руке наклоняться: от -1 (слева) до 1 (справа).
    property real petLean: 0
    // Курсор сейчас над компонентом, и положение курсора в системе сцены (864 × 1152).
    readonly property bool pointerInside: hover.hovered
    property point pointerStage: Qt.point(0, 0)
    signal pointerMoved(real x, real y)

    readonly property bool reduced: tokens.motion.off || !animationsEnabled
    readonly property bool moving: active && visible && !reduced
    // Плавно гасит движение при остановке; при reducedMotion мгновенно возвращает статичный кадр.
    property real activity: moving ? 1 : 0
    Behavior on activity {
        enabled: !root.reduced
        NumberAnimation { duration: root.tokens.motion.base * 2; easing.type: Easing.InOutSine }
    }
    property real breathPhase: 0
    property real swayPhase: 0
    property real flutterPhase: 0
    property real eyeOpen: 1
    property real earLeftAngle: 0
    property real earRightAngle: 0
    property real lookX: 0
    property real lookY: 0

    property real petPhase: 0

    readonly property real breath: activity * breathAmount * (1 - Math.cos(breathPhase)) / 2
    // Поглаживание усиливает качание: волосы и шарф живее реагируют на руку.
    readonly property real sway: activity * hairSway * (1 + 0.9 * pet)
    readonly property real flutter: activity * scarfFlutter * (1 + 0.5 * pet)
    // Ушки опускаются к голове (слева — против часовой, справа — по часовой) и слегка подрагивают.
    readonly property real petEarLeft: pet * (-7 + 1.6 * activity * Math.sin(flutterPhase * 3))
    readonly property real petEarRight: pet * (7 - 1.6 * activity * Math.sin(flutterPhase * 3 + 0.7))

    // Граница кадра в системе источника: от кончиков волос слева до кончика шарфа справа.
    readonly property real cropX: 205
    readonly property real cropY: 55
    readonly property real cropWidth: 545
    readonly property real cropHeight: 1040
    readonly property real fit: Math.min(width / cropWidth, height / cropHeight)
    // Зона головы и волос в координатах этого компонента: по ней окно строит маску наведения.
    readonly property var headZone: Pet.zone()
    readonly property rect headRect: Qt.rect(stage.x + headZone.x * fit, stage.y + headZone.y * fit,
                                             headZone.w * fit, headZone.h * fit)
    // Куда направлять хвост облачка с репликой: между ушами, на уровне их кончиков, сверху.
    readonly property point bubbleAnchor: Qt.point(stage.x + 407 * fit, stage.y + 64 * fit)
    implicitWidth: 280
    implicitHeight: 534

    HoverHandler {
        id: hover
        enabled: root.followPointer || root.pointerTracking
        onPointChanged: {
            if (!hovered || root.fit <= 0)
                return
            const x = (point.position.x - stage.x) / root.fit
            const y = (point.position.y - stage.y) / root.fit
            root.pointerStage = Qt.point(x, y)
            root.pointerMoved(x, y)
        }
    }
    // Над головой при поглаживании голова идёт за рукой; иначе — за курсором или заданным look.
    readonly property point target: {
        if (root.pet > 0.3)
            return Qt.point(0.9 * root.petLean, 0.25)
        if (root.followPointer && hover.hovered)
            return Qt.point(Math.max(-1, Math.min(1, (hover.point.position.x / Math.max(1, root.width) - 0.5) * 2)),
                            Math.max(-1, Math.min(1, (hover.point.position.y / Math.max(1, root.height) - 0.5) * 2)))
        if (root.pointerTracking && hover.hovered)
            return Qt.point(0.8 * Math.max(-1, Math.min(1, (root.pointerStage.x - (headZone.x + headZone.w / 2)) / (headZone.w / 2))),
                            0.8 * Math.max(-1, Math.min(1, (root.pointerStage.y - (headZone.y + headZone.h / 2)) / (headZone.h / 2))))
        return root.look
    }
    onTargetChanged: {
        lookX = target.x * activity
        lookY = target.y * activity
    }
    Behavior on lookX { enabled: !root.reduced; NumberAnimation { duration: root.tokens.motion.base * 2; easing.type: Easing.OutCubic } }
    Behavior on lookY { enabled: !root.reduced; NumberAnimation { duration: root.tokens.motion.base * 2; easing.type: Easing.OutCubic } }
    onActivityChanged: {
        lookX = target.x * activity
        lookY = target.y * activity
    }

    NumberAnimation on breathPhase {
        running: root.moving
        from: 0; to: Math.PI * 2
        duration: root.tokens.motion.base * 22
        loops: Animation.Infinite
    }
    NumberAnimation on swayPhase {
        running: root.moving
        from: 0; to: Math.PI * 2
        duration: root.tokens.motion.base * 29
        loops: Animation.Infinite
    }
    NumberAnimation on flutterPhase {
        running: root.moving
        from: 0; to: Math.PI * 2
        duration: root.tokens.motion.base * 17
        loops: Animation.Infinite
    }

    // Моргание: быстро закрыть, чуть задержать, открыть. Интервал случайный.
    SequentialAnimation {
        id: blinkAnimation
        NumberAnimation { target: root; property: "eyeOpen"; to: 0.04; duration: Math.round(root.tokens.motion.fast / 2); easing.type: Easing.InQuad }
        PauseAnimation { duration: Math.round(root.tokens.motion.fast / 3) }
        NumberAnimation { target: root; property: "eyeOpen"; to: 1; duration: root.tokens.motion.fast; easing.type: Easing.OutQuad }
    }
    // Фаза искорок поглаживания: 0…1 по кругу, идёт только пока поза включена.
    NumberAnimation on petPhase {
        running: root.moving && root.pet > 0.02
        from: 0; to: 1
        duration: root.tokens.motion.base * 9
        loops: Animation.Infinite
    }
    Timer {
        id: blinkTimer
        running: root.moving && root.blinking && root.pet < 0.05
        repeat: true
        interval: root.blinkMinMs + Math.random() * Math.max(0, root.blinkMaxMs - root.blinkMinMs)
        onTriggered: {
            blinkAnimation.restart()
            interval = root.blinkMinMs + Math.random() * Math.max(0, root.blinkMaxMs - root.blinkMinMs)
        }
    }
    // Ухо иногда вздрагивает: быстрый наклон и мягкое возвращение.
    SequentialAnimation {
        id: earLeftTwitch
        NumberAnimation { target: root; property: "earLeftAngle"; to: -9; duration: Math.round(root.tokens.motion.fast / 2); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "earLeftAngle"; to: 3; duration: Math.round(root.tokens.motion.fast / 2); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "earLeftAngle"; to: 0; duration: root.tokens.motion.base; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: earRightTwitch
        NumberAnimation { target: root; property: "earRightAngle"; to: 9; duration: Math.round(root.tokens.motion.fast / 2); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "earRightAngle"; to: -3; duration: Math.round(root.tokens.motion.fast / 2); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "earRightAngle"; to: 0; duration: root.tokens.motion.base; easing.type: Easing.OutCubic }
    }
    Timer {
        running: root.moving && root.earTwitching
        repeat: true
        interval: 6000 + Math.random() * 7000
        onTriggered: {
            const both = Math.random() < 0.3
            if (both || Math.random() < 0.5) earLeftTwitch.restart()
            if (both || Math.random() >= 0.5) earRightTwitch.restart()
            interval = 6000 + Math.random() * 7000
        }
    }
    onMovingChanged: {
        if (!moving) {
            blinkAnimation.stop()
            earLeftTwitch.stop()
            earRightTwitch.stop()
            eyeOpen = 1
            earLeftAngle = 0
            earRightAngle = 0
        }
    }

    // Слой-картинка из атласа. Положение берётся из манифеста.
    component Layer: Image {
        required property string atlasName
        readonly property var info: Atlas.layers[atlasName]
        x: info.x
        y: info.y
        width: info.w
        height: info.h
        source: Qt.resolvedUrl("../../assets/naomi/layers/" + info.file)
        smooth: true
        mipmap: true
    }
    // Слой, перекрашенный цветом из токенов: яркость рисунка сохраняется.
    component TintedLayer: Item {
        id: tinted
        required property string atlasName
        required property color tint
        Layer {
            id: mask
            atlasName: tinted.atlasName
            visible: false
        }
        MultiEffect {
            x: mask.x
            y: mask.y
            width: mask.width
            height: mask.height
            source: mask
            colorization: 1
            colorizationColor: tinted.tint
        }
    }
    // Искорка: четырёхлучевая звёздочка с вогнутыми гранями.
    component Sparkle: Shape {
        id: spark
        required property real cx
        required property real cy
        required property real size
        required property color tint
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: spark.tint
            strokeColor: "transparent"
            startX: spark.cx
            startY: spark.cy - spark.size
            PathQuad { x: spark.cx + spark.size; y: spark.cy; controlX: spark.cx + spark.size * 0.12; controlY: spark.cy - spark.size * 0.12 }
            PathQuad { x: spark.cx; y: spark.cy + spark.size; controlX: spark.cx + spark.size * 0.12; controlY: spark.cy + spark.size * 0.12 }
            PathQuad { x: spark.cx - spark.size; y: spark.cy; controlX: spark.cx - spark.size * 0.12; controlY: spark.cy + spark.size * 0.12 }
            PathQuad { x: spark.cx; y: spark.cy - spark.size; controlX: spark.cx - spark.size * 0.12; controlY: spark.cy - spark.size * 0.12 }
        }
    }
    // Закрытое веко: тёмная дуга на месте глаза.
    component Lid: Shape {
        id: lid
        required property real cx
        required property real cy
        required property real tilt
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.tokens.color.background
            strokeWidth: 3.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: lid.cx - 16
            startY: lid.cy - lid.tilt
            PathQuad {
                x: lid.cx + 16
                y: lid.cy + lid.tilt
                controlX: lid.cx
                controlY: lid.cy + 7
            }
        }
    }

    Item {
        id: stage
        width: Atlas.width
        height: Atlas.height
        transformOrigin: Item.TopLeft
        scale: root.fit
        x: (root.width - root.cropWidth * root.fit) / 2 - root.cropX * root.fit
        y: (root.height - root.cropHeight * root.fit) / 2 - root.cropY * root.fit

        Layer { atlasName: "body_lower" }

        // Плечи и верх тела дышат вместе с волосами и шарфом, прикреплёнными к ним.
        Item {
            id: upper
            y: -3 * root.breath + 1.5 * root.pet
            Layer { atlasName: "body_torso" }

            // Волосы слева: цепочка из трёх звеньев, каждое качается вокруг верха своего звена.
            Item {
                transform: Rotation { origin.x: 360; origin.y: 225; angle: 1.2 * root.sway * Math.sin(root.swayPhase) }
                Layer { atlasName: "hair_left_1" }
                Item {
                    transform: Rotation { origin.x: 338; origin.y: 351; angle: 2.0 * root.sway * Math.sin(root.swayPhase - 0.8) }
                    Layer { atlasName: "hair_left_2" }
                    Item {
                        transform: Rotation { origin.x: 309; origin.y: 430; angle: 3.0 * root.sway * Math.sin(root.swayPhase - 1.6) }
                        Layer { atlasName: "hair_left_3" }
                    }
                }
            }
            // Волосы справа.
            Item {
                transform: Rotation { origin.x: 512; origin.y: 253; angle: 1.1 * root.sway * Math.sin(root.swayPhase + 0.6) }
                Layer { atlasName: "hair_right_1" }
                Item {
                    transform: Rotation { origin.x: 540; origin.y: 374; angle: 2.2 * root.sway * Math.sin(root.swayPhase - 0.4) }
                    Layer { atlasName: "hair_right_2" }
                }
            }
            // Шарф: три звена вдоль ленты, хвост трепещет сильнее.
            Item {
                transform: Rotation { origin.x: 478; origin.y: 284; angle: 1.5 * root.flutter * Math.sin(root.flutterPhase) }
                TintedLayer { atlasName: "scarf_1"; tint: root.tokens.color.secondary }
                Item {
                    transform: Rotation { origin.x: 562; origin.y: 428; angle: 3.8 * root.flutter * Math.sin(root.flutterPhase - 0.9) }
                    TintedLayer { atlasName: "scarf_2"; tint: root.tokens.color.secondary }
                    Item {
                        transform: Rotation { origin.x: 666; origin.y: 472; angle: 5.5 * root.flutter * Math.sin(root.flutterPhase - 1.8) }
                        TintedLayer { atlasName: "scarf_3"; tint: root.tokens.color.secondary }
                    }
                }
            }
        }

        // Голова поднимается выше плеч, чуть наклоняется и поворачивается к взгляду.
        Item {
            id: headGroup
            x: 3 * root.lookX
            y: -5 * root.breath + 1.5 * root.lookY + 2.2 * root.pet
            transform: Rotation {
                origin.x: 414
                origin.y: 287
                // Наклон к руке: чуть вправо всегда и сильнее в сторону, где курсор.
                angle: 1.8 * root.lookX + 0.5 * root.sway * Math.sin(root.swayPhase + 1.2)
                    + root.pet * (1.0 + 2.8 * root.petLean)
            }
            Layer { atlasName: "head" }
            TintedLayer { atlasName: "scarf_neck"; tint: root.tokens.color.secondary }
            TintedLayer { atlasName: "pin_moon"; tint: root.tokens.color.secondary }

            Item {
                transform: Rotation { origin.x: 375; origin.y: 155; angle: root.earLeftAngle + root.petEarLeft }
                Layer { atlasName: "ear_left" }
            }
            Item {
                transform: Rotation { origin.x: 448; origin.y: 133; angle: root.earRightAngle + root.petEarRight }
                Layer { atlasName: "ear_right" }
            }
            // Подвеска заколки качается как маятник.
            Item {
                transform: Rotation { origin.x: 458; origin.y: 177; angle: 5 * root.sway * Math.sin(root.swayPhase * 2 + 0.5) + 2 * root.lookX }
                TintedLayer { atlasName: "pin_dangle"; tint: root.tokens.color.secondary }
            }
            // Моргание и довольный прищур: поверх открытых глаз появляется кожа века.
            Item {
                x: 2.5 * root.lookX
                y: 1.5 * root.lookY
                opacity: Math.max(1 - root.eyeOpen, root.pet)
                Layer { atlasName: "lid_left" }
                Layer { atlasName: "lid_right" }
            }
            // Моргание: тёмная дуга ресниц на закрытом веке. При поглаживании её заменяют «довольные» глаза.
            Lid { cx: 402; cy: 211; tilt: 1; opacity: (1 - root.eyeOpen) * (1 - root.pet); x: 2.5 * root.lookX; y: 1.5 * root.lookY }
            Lid { cx: 443; cy: 200; tilt: 0.5; opacity: (1 - root.eyeOpen) * (1 - root.pet); x: 2.5 * root.lookX; y: 1.5 * root.lookY }
            // Поза поглаживания: румянец цветом secondary, прикрытые улыбкой глаза и мягкая улыбка.
            Item {
                visible: root.pet > 0.001
                opacity: root.pet
                TintedLayer { atlasName: "blush_left"; tint: root.tokens.color.secondary }
                TintedLayer { atlasName: "blush_right"; tint: root.tokens.color.secondary }
                Item {
                    x: 2.5 * root.lookX
                    y: 1.5 * root.lookY
                    Layer { atlasName: "eye_happy_left" }
                    Layer { atlasName: "eye_happy_right" }
                }
                Item {
                    x: 1.2 * root.lookX
                    y: 0.8 * root.lookY
                    Layer { atlasName: "mouth_smile" }
                }
            }
        }

        // Искорки над головой, пока гладят: плывут вверх и гаснут. Без анимаций их нет.
        Repeater {
            model: [
                { sx: 316, sy: 150, size: 11, offset: 0.0, rise: 26 },
                { sx: 566, sy: 168, size: 9, offset: 0.37, rise: 22 },
                { sx: 509, sy: 78, size: 7, offset: 0.7, rise: 18 }
            ]
            delegate: Sparkle {
                id: spark
                required property var modelData
                readonly property real progress: (root.petPhase + modelData.offset) % 1
                cx: modelData.sx
                cy: modelData.sy - modelData.rise * progress
                size: modelData.size * (0.55 + 0.6 * Math.sin(Math.PI * progress))
                tint: root.tokens.color.accent
                opacity: root.moving ? root.pet * Math.max(0, Math.sin(Math.PI * progress)) * 0.9 : 0
                visible: opacity > 0.01
            }
        }
    }
}
