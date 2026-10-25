pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Облачко с репликой Naomi: компактное, по размеру текста, с маленьким хвостиком вниз к голове,
// лёгкой тенью и обводкой лавандой. Начало координат — левый верхний угол тела облачка;
// хвост выходит вниз за его нижний край. Родитель ставит облачко над головой и задаёт tailX —
// где на нижнем крае растёт хвост — и maxWidth. Перенос строк только когда реплика не влезает в maxWidth.
// Элемент ничего не принимает от мыши: окно и так маскирует всё, кроме головы.
Item {
    id: root
    required property var tokens
    property string text: ""
    property bool shown: false
    property bool animationsEnabled: true
    // Предел ширины облачка. Короткая реплика занимает ровно свою ширину.
    property real maxWidth: 250
    // Больше строк облачко не показывает: остальное обрезается многоточием.
    property int maxLines: 5
    // Где на нижнем краю растёт хвост (от левого края облачка). Родитель подстраивает под голову.
    property real tailX: width / 2
    readonly property real radius: Math.min(height / 2, 14)
    // Фактическое место хвоста: не ближе радиуса и отступа к углам.
    readonly property real tailAt: Math.max(radius + 8, Math.min(width - radius - 8, tailX))
    readonly property real tailLength: 10
    readonly property bool reduced: tokens.motion.off || !animationsEnabled

    readonly property real padX: 11
    readonly property real padY: 6
    // +2 к естественной ширине, чтобы округление не переносило последнее слово.
    readonly property real textWidth: Math.max(24, Math.min(maxWidth - 2 * padX, Math.ceil(natural.implicitWidth) + 2))
    width: Math.ceil(textWidth + 2 * padX)
    height: Math.ceil(label.implicitHeight + 2 * padY)
    // Фактическая ширина выложенного текста: нужна проверке, что облачко не шире текста.
    readonly property real contentWidth: label.contentWidth
    // Кончик хвоста в координатах облачка: для расчёта положения родителем.
    readonly property point tip: Qt.point(tailAt + 1, height + tailLength)

    // 0 — скрыто, 1 — показано. Вход чуть упругий, выход быстрый и тише.
    property real pop: shown ? 1 : 0
    Behavior on pop {
        enabled: !root.reduced
        NumberAnimation {
            duration: root.shown ? root.tokens.motion.base : root.tokens.motion.fast
            easing.type: root.shown ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.2
        }
    }
    opacity: Math.max(0, Math.min(1, pop * 1.35))
    visible: pop > 0.001
    readonly property real scaleNow: reduced ? 1 : 0.84 + 0.16 * pop
    transform: Scale {
        origin.x: root.tailAt + 1
        origin.y: root.height + root.tailLength
        xScale: root.scaleNow
        yScale: root.scaleNow
    }

    // Контур облачка: скруглённый прямоугольник с небольшим хвостом-каплей вниз на нижнем краю.
    // Один и тот же путь рисует тень, заливку и обводку.
    component CloudPath: ShapePath {
        id: path
        property real shift: 0
        readonly property real w: root.width
        readonly property real h: root.height
        readonly property real r: root.radius
        readonly property real tx: root.tailAt
        startX: path.r
        startY: path.shift
        PathLine { x: path.w - path.r; y: path.shift }
        PathArc { x: path.w; y: path.r + path.shift; radiusX: path.r; radiusY: path.r }
        PathLine { x: path.w; y: path.h - path.r + path.shift }
        PathArc { x: path.w - path.r; y: path.h + path.shift; radiusX: path.r; radiusY: path.r }
        PathLine { x: path.tx + 6; y: path.h + path.shift }
        // Хвост: от правого основания к кончику чуть вправо-вниз и обратно к левому основанию.
        PathQuad { x: path.tx + 1; y: path.h + root.tailLength + path.shift; controlX: path.tx + 4; controlY: path.h + 3 + path.shift }
        PathQuad { x: path.tx - 6; y: path.h + path.shift; controlX: path.tx - 3; controlY: path.h + 4 + path.shift }
        PathLine { x: path.r; y: path.h + path.shift }
        PathArc { x: 0; y: path.h - path.r + path.shift; radiusX: path.r; radiusY: path.r }
        PathLine { x: 0; y: path.r + path.shift }
        PathArc { x: path.r; y: path.shift; radiusX: path.r; radiusY: path.r }
    }

    // Тень: два смещённых слоя цветом shadow с убывающей непрозрачностью.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.55
        CloudPath { shift: 3; fillColor: root.tokens.color.shadow; strokeColor: "transparent" }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.8
        CloudPath { shift: 2; fillColor: root.tokens.color.shadow; strokeColor: "transparent" }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        CloudPath {
            fillColor: root.tokens.material.menu
            strokeColor: root.tokens.color.accentSoft
            strokeWidth: 1.5
            joinStyle: ShapePath.RoundJoin
        }
    }

    // Искорка-«заколка» на углу облачка: розовый акцент, намёк на кицунэ и полумесяц у Naomi.
    Shape {
        x: -3
        y: -4
        width: 10
        height: 10
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.tokens.color.secondary
            strokeColor: "transparent"
            startX: 5
            startY: 0
            PathQuad { x: 10; y: 5; controlX: 5.6; controlY: 4.4 }
            PathQuad { x: 5; y: 10; controlX: 5.6; controlY: 5.6 }
            PathQuad { x: 0; y: 5; controlX: 4.4; controlY: 5.6 }
            PathQuad { x: 5; y: 0; controlX: 4.4; controlY: 4.4 }
        }
    }

    // Невидимая линейка: естественная ширина текста без переноса.
    Text {
        id: natural
        visible: false
        text: root.text
        font.family: root.tokens.type.display.family
        font.pixelSize: 14
        font.weight: root.tokens.type.display.weight
    }
    Text {
        id: label
        x: root.padX
        y: root.padY
        width: root.textWidth
        text: root.text
        wrapMode: Text.WordWrap
        color: root.tokens.color.text
        font.family: root.tokens.type.display.family
        font.pixelSize: 14
        font.weight: root.tokens.type.display.weight
        lineHeight: 1.0
        maximumLineCount: root.maxLines
        elide: Text.ElideRight
    }
}
