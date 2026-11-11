// Parameter catalogue adapted from Ryoku StageVisualizerPage (see NOTICE).
var parameters = [
    {
        "key": "idleWave",
        "label": "Волна в тишине",
        "type": "bool"
    },
    {
        "key": "gain",
        "label": "Чувствительность",
        "type": "number"
    },
    {
        "key": "smoothing",
        "label": "Сглаживание",
        "type": "number"
    },
    {
        "key": "tiltX",
        "label": "Наклон X",
        "type": "number"
    },
    {
        "key": "tiltY",
        "label": "Наклон Y",
        "type": "number"
    },
    {
        "key": "bars",
        "label": "Полосы частот",
        "type": "number"
    },
    {
        "key": "shape",
        "label": "Края",
        "type": "choice",
        "applies": "shapeSet"
    },
    {
        "key": "segments",
        "label": "Сегменты",
        "type": "number",
        "applies": "segSet"
    },
    {
        "key": "thickness",
        "label": "Толщина полос",
        "type": "number",
        "applies": "shapeSet"
    },
    {
        "key": "grow",
        "label": "Направление",
        "type": "choice",
        "applies": "growSet"
    },
    {
        "key": "spin",
        "label": "Скорость вращения",
        "type": "number",
        "applies": "polarSet"
    },
    {
        "key": "reflection",
        "label": "Отражение",
        "type": "number",
        "applies": "reflSet"
    },
    {
        "key": "bloom",
        "label": "Свечение",
        "type": "number",
        "applies": "bloomSet"
    },
    {
        "key": "mirror",
        "label": "Зеркало",
        "type": "bool",
        "applies": "cfg"
    },
    {
        "key": "peaks",
        "label": "Пики",
        "type": "bool",
        "applies": "cfg"
    },
    {
        "key": "auraShape",
        "label": "Движение",
        "type": "choice"
    },
    {
        "key": "auraEffect",
        "label": "Эффект",
        "type": "choice"
    },
    {
        "key": "auraEffectStrength",
        "label": "Сила эффекта",
        "type": "number"
    },
    {
        "key": "auraColorMode",
        "label": "Режим цвета",
        "type": "choice"
    },
    {
        "key": "auraColorSpeed",
        "label": "Скорость цвета",
        "type": "number"
    },
    {
        "key": "auraJoin",
        "label": "Края",
        "type": "choice"
    },
    {
        "key": "auraFlow",
        "label": "Направление потока",
        "type": "choice"
    },
    {
        "key": "auraSpan",
        "label": "Длина края",
        "type": "number"
    },
    {
        "key": "auraTaper",
        "label": "Затухание концов",
        "type": "number"
    },
    {
        "key": "auraCornerRadius",
        "label": "Радиус углов",
        "type": "number"
    },
    {
        "key": "auraCornerBlend",
        "label": "Смешивание углов",
        "type": "number"
    },
    {
        "key": "auraProfile",
        "label": "Частотный профиль",
        "type": "choice"
    },
    {
        "key": "auraAccent",
        "label": "Сила профиля",
        "type": "number"
    },
    {
        "key": "auraOpacity",
        "label": "Непрозрачность поля",
        "type": "number"
    },
    {
        "key": "auraBodyOpacity",
        "label": "Непрозрачность заливки",
        "type": "number"
    },
    {
        "key": "auraCrestStrength",
        "label": "Яркость гребня",
        "type": "number"
    },
    {
        "key": "auraGlow",
        "label": "Свечение",
        "type": "number"
    },
    {
        "key": "auraGlowSpread",
        "label": "Радиус свечения",
        "type": "number"
    },
    {
        "key": "auraAudioRange",
        "label": "Диапазон частот",
        "type": "number"
    },
    {
        "key": "auraThickness",
        "label": "Толщина потока",
        "type": "number"
    },
    {
        "key": "auraDetail",
        "label": "Детализация",
        "type": "number"
    },
    {
        "key": "auraBassDrive",
        "label": "Реакция на бас",
        "type": "number"
    },
    {
        "key": "auraTrebleDrive",
        "label": "Реакция на высокие частоты",
        "type": "number"
    },
    {
        "key": "auraTransient",
        "label": "Реакция на атаки",
        "type": "number"
    },
    {
        "key": "auraBeatGlow",
        "label": "Свечение в такт",
        "type": "number"
    },
    {
        "key": "auraCompression",
        "label": "Компрессия",
        "type": "number"
    },
    {
        "key": "auraSensitivity",
        "label": "Чувствительность поля",
        "type": "number"
    },
    {
        "key": "auraMotionSpeed",
        "label": "Скорость движения",
        "type": "number"
    },
    {
        "key": "auraIdleMotion",
        "label": "Движение в тишине",
        "type": "number"
    },
    {
        "key": "auraAttack",
        "label": "Атака",
        "type": "number"
    },
    {
        "key": "auraRelease",
        "label": "Затухание",
        "type": "number"
    },
    {
        "key": "auraMaterial",
        "label": "Материал",
        "type": "choice"
    },
    {
        "key": "auraDepth",
        "label": "Глубина поля",
        "type": "number"
    }
];

function forTab(tab, item) {
    return parameters.filter(p => {
        const field = p.key.indexOf("aura") === 0;
        if (tab === "Field") return field;
        if (field) return false;
        const motion = ["idleWave", "gain", "smoothing", "tiltX", "tiltY"].indexOf(p.key) >= 0;
        if ((tab === "Motion") !== motion) return false;
        if (tab !== "Motion" && tab !== "Shape") return false;
        if (item.style === "aura") return motion && ["tiltX", "tiltY"].indexOf(p.key) < 0;
        const grow = ["bars", "split", "dots", "segments", "wave", "ribbon", "curtain", "line"].indexOf(item.style) >= 0;
        const shape = ["bars", "split", "dots", "segments", "frame", "radial", "spiral"].indexOf(item.style) >= 0;
        const polar = ["radial", "orb", "spiral"].indexOf(item.style) >= 0;
        const applies = {shapeSet: shape, growSet: grow, polarSet: polar, bloomSet: true, segSet: item.style === "segments", reflSet: grow && item.grow === "up", cfg: true};
        if (p.key === "mirror") return grow;
        if (p.key === "peaks") return ["bars", "segments", "frame"].indexOf(item.style) >= 0;
        if (["tiltX", "tiltY"].indexOf(p.key) >= 0 && item.style === "frame") return false;
        return !p.applies || applies[p.applies];
    });
}
