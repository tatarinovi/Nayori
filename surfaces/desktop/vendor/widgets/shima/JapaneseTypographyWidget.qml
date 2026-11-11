import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.


import QtQuick
import QtQuick.Layouts
import QtQuick.Effects






import "JapaneseTypographyPresets.js" as JapanesePresets

AbstractBackgroundWidget {
    readonly property var nayoriJapaneseTypographyWidget: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    configEntryName: "japaneseTypography"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        preset: "exhibition",
        primaryText: "夏の記憶",
        secondaryText: "潮風と、あの子と、終わらない夏",
        sealText: "特別展",
        footerText: "PACIFIC DRIVE-IN",
        dateText: "7.12 — 8.31",
        showSecondary: true,
        showSeal: true,
        showFooter: true,
        showRule: true,
        fontPreset: "mincho",
        fontFamily: "serif",
        secondaryFontFamily: "",
        latinFontFamily: "",
        primaryWeight: 500,
        secondaryWeight: 400,
        latinWeight: 600,
        primarySize: 72,
        secondarySize: 18,
        footerSize: 14,
        dateSize: 12,
        primaryColumns: 2,
        secondaryColumns: 2,
        columnGap: 14,
        letterSpacing: 2,
        secondaryLetterSpacing: 1,
        mirrorLayout: false,
        rotateLatin: false,
        paletteMode: "adaptive",
        palettePreset: "adaptive",
        primaryColor: "#E7D4B2",
        secondaryColor: "#CDB48D",
        sealColor: "#A64B39",
        detailColor: "#D0B996",
        ruleColor: "#C18A53",
        primaryOpacity: 100,
        secondaryOpacity: 78,
        sealOpacity: 100,
        detailOpacity: 72,
        ruleOpacity: 78,
        sealFillOpacity: 0,
        ruleThickness: 1,
        outlineColor: "#000000",
        outlineOpacity: 0,
        shadowStrength: 35,
        contentWidth: 330,
        contentHeight: 600,
        dim: 10,
        widgetScale: 100,
        widgetOpacity: 100,
        showBackground: false,
        useBlur: false,
        showBorder: false,
        backgroundOpacity: 0,
        borderWidth: 0,
        borderOpacity: 0.12,
        cornerRadius: -1,
        colorMode: "auto",
        x: 56,
        y: 120
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 330) * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 600) * root.scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 320
    resizeMaxWidth: 720
    resizeMaxHeight: 1000
    needsColText: true
    liveColorTracking: true
    // Ryoku hosting draws the slot card, so drop this widget's own plate in
    // Ryoku style — the vertical type sits on the single shared surface.
    readonly property bool _ryokuBare: root.ryokuHosted && root.ryokuStyle

    readonly property string compositionPreset: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.preset", "exhibition")
    readonly property string palettePreset: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.palettePreset", "adaptive")
    readonly property string fontPreset: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.fontPreset", "mincho")

    function applyCompositionPreset(preset: string): void {
        nayoriJapaneseTypographyWidget.config.setNestedValues(JapanesePresets.composition(root._configPath, preset));
    }

    function applyPalettePreset(preset: string): void {
        nayoriJapaneseTypographyWidget.config.setNestedValues(JapanesePresets.palette(root._configPath, preset));
    }

    function applyFontPreset(preset: string): void {
        nayoriJapaneseTypographyWidget.config.setNestedValues(JapanesePresets.font(root._configPath, preset));
    }

    function setCompositionOption(key: string, value: var): void {
        nayoriJapaneseTypographyWidget.config.setNestedValues(JapanesePresets.setValue(root._configPath, key, value, "composition"));
    }



    readonly property string primaryText: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.primaryText", "夏の記憶")
    readonly property string secondaryText: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryText", "潮風と、あの子と、終わらない夏")
    readonly property string sealText: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.sealText", "特別展")
    readonly property string footerText: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.footerText", "PACIFIC DRIVE-IN")
    readonly property string dateText: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.dateText", "7.12 — 8.31")
    readonly property string displayPrimaryText: nayoriJapaneseTypographyWidget.uiPreferences.shippedText(root.primaryText, "夏の記憶", "SUMMER MEMORIES")
    readonly property string displaySecondaryText: nayoriJapaneseTypographyWidget.uiPreferences.shippedText(root.secondaryText, "潮風と、あの子と、終わらない夏", "SEA BREEZE AND ENDLESS SUMMER")
    readonly property string displaySealText: nayoriJapaneseTypographyWidget.uiPreferences.shippedText(root.sealText, "特別展", "SPECIAL")
    readonly property bool showSecondary: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.showSecondary", true)
    readonly property bool showSeal: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.showSeal", true)
    readonly property bool showFooter: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.showFooter", true)
    readonly property bool showRule: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.showRule", true)
    readonly property bool mirrorLayout: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.mirrorLayout", false)
    readonly property bool rotateLatin: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.rotateLatin", false)

    readonly property string fontFamily: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.fontFamily", "serif")
    readonly property string secondaryFontFamily: {
        const configured = nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryFontFamily", "");
        return configured.length > 0 ? configured : root.fontFamily;
    }
    readonly property string latinFontFamily: {
        const configured = nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.latinFontFamily", "");
        return configured.length > 0 ? configured : nayoriJapaneseTypographyWidget.appearance.font.family.main;
    }
    readonly property int primaryWeight: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.primaryWeight", 500)
    readonly property int secondaryWeight: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryWeight", 400)
    readonly property int latinWeight: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.latinWeight", 600)
    readonly property real primarySize: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.primarySize", 72)
    readonly property real secondarySize: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondarySize", 18)
    readonly property real footerSize: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.footerSize", 14)
    readonly property real dateSize: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.dateSize", 12)
    readonly property int primaryColumns: Math.max(1, Math.min(4,
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.primaryColumns", 2)))
    readonly property int secondaryColumns: Math.max(1, Math.min(5,
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryColumns", 2)))
    readonly property real configuredColumnGap: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.columnGap", 14)
    readonly property real configuredLetterSpacing: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.letterSpacing", 2)
    readonly property real configuredSecondaryLetterSpacing: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryLetterSpacing", 1)

    readonly property string paletteMode: nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.paletteMode", "adaptive")
    readonly property bool manualPalette: root.paletteMode === "manual"
    // Manual editorial colors already have dedicated controls; avoid showing a
    // second palette control that would not affect the current rendering.
    semanticPaletteQuickControls: !root.manualPalette
    readonly property real primaryOpacity: root._percent("primaryOpacity", 100)
    readonly property real secondaryOpacity: root._percent("secondaryOpacity", 78)
    readonly property real sealOpacity: root._percent("sealOpacity", 100)
    readonly property real detailOpacity: root._percent("detailOpacity", 72)
    readonly property real ruleOpacity: root._percent("ruleOpacity", 78)
    readonly property real sealFillOpacity: root._percent("sealFillOpacity", 0)
    readonly property real outlineOpacity: root._percent("outlineOpacity", 0)
    readonly property real shadowStrength: root._percent("shadowStrength", 35)
    readonly property int ruleThickness: Math.max(1, Math.min(6,
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.ruleThickness", 1)))

    readonly property real outerPad: Math.round(Math.max(12 * root.scaleFactor, Math.min(root.width, root.height) * 0.035))
    readonly property bool compact: root.width < 270 * root.scaleFactor || root.height < 430 * root.scaleFactor
    readonly property real footerExtent: root.showFooter
        ? Math.round(Math.max(54 * root.scaleFactor, Math.min(98 * root.scaleFactor, root.height * 0.16)))
        : 0
    readonly property real leadPixelSize: Math.max(28 * root.scaleFactor, Math.min(
        root.primarySize * root.scaleFactor,
        Math.max(28 * root.scaleFactor, body.height / 5.2),
        Math.max(28 * root.scaleFactor, body.width * (root.compact ? 0.27 : 0.23))))
    readonly property real notePixelSize: Math.max(11 * root.scaleFactor, Math.min(
        root.secondarySize * root.scaleFactor,
        Math.max(11 * root.scaleFactor, body.height / 16),
        Math.max(11 * root.scaleFactor, body.width * 0.085)))
    readonly property real effectiveColumnGap: Math.max(6 * root.scaleFactor, root.configuredColumnGap * root.scaleFactor)
    readonly property real effectiveLetterSpacing: Math.max(0, root.configuredLetterSpacing * root.scaleFactor)
    readonly property real effectiveSecondaryLetterSpacing: Math.max(0, root.configuredSecondaryLetterSpacing * root.scaleFactor)
    readonly property real leadNaturalWidth: root.leadPixelSize * 1.08 * root.primaryColumns
        + root.effectiveColumnGap * Math.max(0, root.primaryColumns - 1)
    readonly property real noteNaturalWidth: root.notePixelSize * 1.08 * root.secondaryColumns
        + Math.max(5 * root.scaleFactor, root.effectiveColumnGap * 0.65) * Math.max(0, root.secondaryColumns - 1)
    readonly property real leadWidth: Math.min(
        body.width * (root.showSecondary ? (root.compact ? 0.62 : 0.54) : 0.94),
        Math.max(root.leadNaturalWidth, body.width * (root.compact ? 0.48 : 0.38)))
    readonly property real noteWidth: Math.min(body.width * 0.30,
        Math.max(root.noteNaturalWidth, root.notePixelSize * 1.8))

    // Adaptive mode selects only generated semantic tokens. Manual palette mode
    // remains explicit user RGB intent and is intentionally left untouched.
    readonly property color adaptivePrimaryInk: root.widgetSemanticForeground(root.widgetPrimaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveSecondaryInk: root.widgetSemanticForeground(root.widgetSecondaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveDetailInk: root.widgetSemanticForeground(root.widgetTertiaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveRuleInk: root.widgetSemanticForeground(root.widgetTertiaryRole, root.accentBackdrop, 3.0)
    readonly property color adaptiveSealInk: root.widgetSemanticForeground(root.widgetSignalRole, root.accentBackdrop, 3.0)

    readonly property color leadInk: root._roleColor(
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.primaryColor", "#E7D4B2"),
        root.adaptivePrimaryInk, root.primaryOpacity)
    readonly property color noteInk: root._roleColor(
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.secondaryColor", "#CDB48D"),
        root.adaptiveSecondaryInk, root.secondaryOpacity)
    readonly property color sealBase: root.manualPalette
        ? root._safeColor(nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.sealColor", "#A64B39"), root.adaptiveSealInk)
        : root.adaptiveSealInk
    readonly property color sealInk: nayoriJapaneseTypographyWidget.colorUtils.applyAlpha(root.sealBase, root.sealOpacity)
    readonly property color detailInk: root._roleColor(
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.detailColor", "#D0B996"),
        root.adaptiveDetailInk, root.detailOpacity)
    readonly property color ruleInk: root._roleColor(
        nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.ruleColor", "#C18A53"),
        root.adaptiveRuleInk, root.ruleOpacity)
    readonly property color editorialHalo: nayoriJapaneseTypographyWidget.colorUtils.applyAlpha(
        nayoriJapaneseTypographyWidget.colorUtils.relativeLuminance(root.leadInk) >= 0.42
            ? Qt.rgba(0, 0, 0, 1)
            : Qt.rgba(1, 0.97, 0.92, 1),
        0.92)
    readonly property color outlineInk: nayoriJapaneseTypographyWidget.colorUtils.applyAlpha(
        root._safeColor(nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography.outlineColor", "#000000"), root.editorialHalo),
        root.outlineOpacity)
    readonly property int glyphTextStyle: root.outlineOpacity > 0 ? Text.Outline : Text.Normal

    function _percent(key: string, fallback: real): real {
        const value = Number(nayoriJapaneseTypographyWidget.config.getNestedValue("background.widgets.japaneseTypography." + key, fallback));
        return Math.max(0, Math.min(1, (Number.isFinite(value) ? value : fallback) / 100));
    }

    function _safeColor(value: var, fallback: color): color {
        const parsed = Qt.color(String(value ?? ""));
        return parsed.valid ? parsed : fallback;
    }

    function _roleColor(manualValue: var, adaptiveValue: color, opacity: real): color {
        const base = root.manualPalette ? root._safeColor(manualValue, adaptiveValue) : adaptiveValue;
        return nayoriJapaneseTypographyWidget.colorUtils.applyAlpha(base, opacity);
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root._ryokuBare ? 0 : root.backgroundOpacity
        surfaceBorderWidth: root._ryokuBare ? 0 : root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetPlateColor
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.ryokuScreenX
        screenY: root.ryokuScreenY
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root._ryokuBare && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    Item {
        id: editorialComposition
        anchors.fill: parent
        anchors.margins: root.outerPad
        clip: true

        layer.enabled: root.shadowStrength > 0 && !root.widgetHasSurface
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.editorialHalo
            shadowOpacity: root.shadowStrength
                * (nayoriJapaneseTypographyWidget.colorUtils.relativeLuminance(root.leadInk) >= 0.42 ? 1.0 : 0.58)
            shadowBlur: 0.62
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 2
        }

        Item {
            id: body
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: footerBlock.visible ? footerBlock.top : parent.bottom
                bottomMargin: footerBlock.visible ? Math.round(12 * root.scaleFactor) : 0
            }
            clip: true

            VerticalJapaneseText {
                id: leadColumn
                x: root.mirrorLayout ? body.width - width : 0
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                }
                width: root.leadWidth
                text: root.displayPrimaryText
                fontFamily: root.fontFamily
                fontPixelSize: root.leadPixelSize
                fontWeight: root.primaryWeight
                letterSpacing: root.effectiveLetterSpacing
                columnGap: root.effectiveColumnGap
                maxColumns: root.compact ? 1 : root.primaryColumns
                rotateLatin: root.rotateLatin
                color: root.leadInk
                textStyle: root.glyphTextStyle
                styleColor: root.outlineInk
            }

            VerticalJapaneseText {
                id: editorialNote
                visible: root.showSecondary && body.width >= 210 * root.scaleFactor && body.height >= 240 * root.scaleFactor
                x: root.mirrorLayout
                    ? Math.max(0, leadColumn.x - root.effectiveColumnGap - width)
                    : Math.min(body.width - width, leadColumn.x + leadColumn.width + root.effectiveColumnGap)
                anchors {
                    top: parent.top
                    topMargin: Math.round(root.leadPixelSize * 0.18)
                    bottom: parent.bottom
                }
                width: root.noteWidth
                text: root.displaySecondaryText
                fontFamily: root.secondaryFontFamily
                fontPixelSize: root.notePixelSize
                fontWeight: root.secondaryWeight
                letterSpacing: root.effectiveSecondaryLetterSpacing
                columnGap: Math.max(5 * root.scaleFactor, root.effectiveColumnGap * 0.65)
                maxColumns: root.compact ? 1 : root.secondaryColumns
                rotateLatin: root.rotateLatin
                color: root.noteInk
                textStyle: root.glyphTextStyle
                styleColor: root.outlineInk
            }

            Rectangle {
                id: seal
                visible: root.showSeal && body.width >= 220 * root.scaleFactor && body.height >= 260 * root.scaleFactor
                x: root.mirrorLayout ? 0 : body.width - width
                anchors.top: parent.top
                width: Math.max(34 * root.scaleFactor, root.notePixelSize * 2.35)
                height: Math.min(body.height * 0.30,
                    Math.max(74 * root.scaleFactor, Array.from(root.sealText).length * root.notePixelSize * 1.22 + 18 * root.scaleFactor))
                color: nayoriJapaneseTypographyWidget.colorUtils.applyAlpha(root.sealBase, root.sealFillOpacity)
                border.width: Math.max(1, Math.round(root.scaleFactor))
                border.color: root.sealInk
                radius: 0

                VerticalJapaneseText {
                    id: sealTypography
                    readonly property real innerPadding: Math.round(5 * root.scaleFactor)
                    anchors.centerIn: parent
                    width: Math.max(1, Math.min(
                        parent.width - sealTypography.innerPadding * 2,
                        sealTypography.cellSize))
                    height: Math.max(1, Math.min(
                        parent.height - sealTypography.innerPadding * 2,
                        Math.max(sealTypography.cellAdvance,
                            Array.from(root.displaySealText).length * sealTypography.cellAdvance)))
                    text: root.displaySealText
                    fontFamily: root.fontFamily
                    fontPixelSize: Math.max(10 * root.scaleFactor, root.notePixelSize * 0.86)
                    fontWeight: Font.DemiBold
                    letterSpacing: 0
                    columnGap: 0
                    maxColumns: 1
                    rotateLatin: root.rotateLatin
                    color: root.sealInk
                }
            }
        }

        Item {
            id: footerBlock
            visible: root.showFooter && root.footerExtent > 0
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: root.footerExtent

            Rectangle {
                visible: root.showRule
                x: root.mirrorLayout ? parent.width - width : 0
                anchors.top: parent.top
                width: Math.min(parent.width * 0.78, 250 * root.scaleFactor)
                height: Math.max(1, Math.round(root.ruleThickness * root.scaleFactor))
                color: root.ruleInk
            }

            StyledText {
                anchors {
                    left: parent.left
                    top: parent.top
                    topMargin: Math.round(10 * root.scaleFactor)
                    right: parent.right
                }
                text: root.footerText
                color: root.detailInk
                horizontalAlignment: root.mirrorLayout ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                style: root.glyphTextStyle
                styleColor: root.outlineInk
                font {
                    family: root.latinFontFamily
                    pixelSize: Math.max(9 * root.scaleFactor, Math.min(root.footerSize * root.scaleFactor, root.footerExtent * 0.28))
                    weight: root.latinWeight
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor))
                }
            }

            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: root.dateText
                color: root.detailInk
                horizontalAlignment: root.mirrorLayout ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                style: root.glyphTextStyle
                styleColor: root.outlineInk
                font {
                    family: root.latinFontFamily
                    pixelSize: Math.max(9 * root.scaleFactor, Math.min(root.dateSize * root.scaleFactor, root.footerExtent * 0.24))
                    weight: Font.Medium
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor * 0.8))
                }
            }
        }
    }
}
