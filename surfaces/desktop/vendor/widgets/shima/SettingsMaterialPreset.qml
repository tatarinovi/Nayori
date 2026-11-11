import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
pragma Singleton


import QtQuick



QtObject {
    readonly property var nayoriSettingsMaterialPreset: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root

    readonly property bool unified:
        (nayoriSettingsMaterialPreset.config.options?.settingsUi?.overlayStyle ?? "rail") === "unified"

    // ── Page layout ──
    readonly property int pageSpacing: unified ? Math.round(12 * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
        : Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.tileGap
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 14 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 12) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)

    // ── Card (SettingsCardSection) ──
    readonly property int cardRadius: unified ? Math.round(12 * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere ? nayoriSettingsMaterialPreset.appearance.angel.roundingNormal
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.roundNormal
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.cornerRadius + 1
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.roundingNormal
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.radius : nayoriSettingsMaterialPreset.appearance.rounding.normal
    readonly property int cardPadding: unified ? Math.round(14 * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
        : Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.tilePadding
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 16 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 14) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)

    // ── Card header ──
    readonly property int headerRadius: unified ? Math.round(8 * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere ? nayoriSettingsMaterialPreset.appearance.angel.roundingSmall
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.controlRadius
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.cornerRadius
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.roundingSmall
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? Math.max(4, Math.round(nayoriSettingsMaterialPreset.appearance.editorial.radius * 0.7)) : nayoriSettingsMaterialPreset.appearance.rounding.small
    readonly property int headerPaddingX: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.controlPaddingHorizontal
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 14 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 12) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
    readonly property int headerPaddingY: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.controlPaddingVertical
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 8 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 7) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)

    // ── Group (SettingsGroup) ──
    readonly property int groupRadius: unified ? Math.round(8 * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere ? nayoriSettingsMaterialPreset.appearance.angel.roundingSmall
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.roundSmall
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.cornerRadius
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.roundingSmall
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? Math.max(4, Math.round(nayoriSettingsMaterialPreset.appearance.editorial.radius * 0.7)) : nayoriSettingsMaterialPreset.appearance.rounding.small
    readonly property int groupPadding: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.tilePadding
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 14 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 12) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
    readonly property int groupSpacing: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.tileGap
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 8 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 7) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)

    // ── Colors ──
    // In angel/aurora, cards are more transparent to let the content area's
    // GlassBackground blur show through (like Overlay widgets do).
    readonly property color cardColor: unified ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.colors.colLayer1Base, nayoriSettingsMaterialPreset.appearance.angel.cardTransparentize * 0.7)
        // bg3 (not tile): the content field sits at bg2 now, so cards must lift a
        // clear step above it instead of matching it — depth by layer, not stroke.
        // ZZZ: transparent so the card complements the window/console ground
        // (dark or light) instead of stacking another dark plate. Definition comes
        // from the diagonal pattern + accent bar, not a filled surface + line.
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.surfacePlate
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.layer(1)
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colLayer1
        : nayoriSettingsMaterialPreset.appearance.auroraEverywhere ? nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.colors.colLayer1Base, 0.85)
        : nayoriSettingsMaterialPreset.appearance.colors.colLayer1
    readonly property color cardBorderColor: unified ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colCardBorder
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.rule
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.hairline
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colBorder
        : nayoriSettingsMaterialPreset.appearance.auroraEverywhere ? nayoriSettingsMaterialPreset.appearance.aurora.colPopupBorder
        : nayoriSettingsMaterialPreset.appearance.colors.colLayer0Border

    readonly property color groupColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colLayer1
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.colors.colLayer2Base, nayoriSettingsMaterialPreset.appearance.angel.popupTransparentize * 0.6)
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.layer(2)
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.inir.colLayer2, 0.45)
        : nayoriSettingsMaterialPreset.appearance.auroraEverywhere ? nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.colors.colLayer2Base, 0.88)
        : nayoriSettingsMaterialPreset.colorUtils.transparentize(nayoriSettingsMaterialPreset.appearance.colors.colLayer2, 0.4)
    readonly property color groupBorderColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colLayer0Border
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colBorderSubtle
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? "transparent"
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.rule
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.hairlineStrong
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colBorderSubtle
        : nayoriSettingsMaterialPreset.appearance.auroraEverywhere ? nayoriSettingsMaterialPreset.appearance.aurora.colPopupBorder
        : nayoriSettingsMaterialPreset.appearance.colors.colLayer0Border

    // ── Header hover ──
    readonly property color headerHoverColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colLayer1Hover
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colGlassCardHover
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.surfacePlateHover
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.field
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.paperAlt
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colLayer1Hover
        : nayoriSettingsMaterialPreset.appearance.auroraEverywhere ? nayoriSettingsMaterialPreset.appearance.aurora.colSubSurfaceHover
        : nayoriSettingsMaterialPreset.appearance.colors.colLayer1Hover

    // ── Accent bar (left edge on expanded section) ──
    readonly property color accentColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colPrimary
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colPrimary
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.onColor
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.accent
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.accent
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colAccent
        : nayoriSettingsMaterialPreset.appearance.colors.colPrimary

    // ── Section title colors ──
    readonly property color titleExpandedColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colOnSurface
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colText
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.onColor
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.ink
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.onColor
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colText
        : nayoriSettingsMaterialPreset.appearance.colors.colOnSecondaryContainer
    readonly property color titleCollapsedColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colOnSurface
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colText
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.onColor
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.ink
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.colors.colOnLayer1
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colText
        : nayoriSettingsMaterialPreset.appearance.colors.colOnSurface

    // ── Icon colors ──
    // ZZZ: the card header icon rides a ZzzGlyphBadge plate (sticker when
    // expanded, secondary when collapsed); the INK on that plate must be the
    // corresponding on-plate ink, not a raw accent (which can compute near-
    // black on a low-chroma wallpaper and render as a black glyph).
    readonly property color iconExpandedColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colPrimary
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colPrimary
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.hardwarePrimary
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.accent
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.onSticker
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colAccent
        : nayoriSettingsMaterialPreset.appearance.colors.colPrimary
    readonly property color iconCollapsedColor: unified ? nayoriSettingsMaterialPreset.appearance.colors.colOnSurfaceVariant
        : nayoriSettingsMaterialPreset.appearance.angelEverywhere
        ? nayoriSettingsMaterialPreset.appearance.angel.colTextMuted
        : nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.hardwareSecondary
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? nayoriSettingsMaterialPreset.appearance.editorial.muted
        : nayoriSettingsMaterialPreset.appearance.zzzEverywhere ? nayoriSettingsMaterialPreset.appearance.zzz.onSecondary
        : nayoriSettingsMaterialPreset.appearance.inirEverywhere ? nayoriSettingsMaterialPreset.appearance.inir.colTextSecondary
        : nayoriSettingsMaterialPreset.appearance.colors.colOnSurfaceVariant

    // ── Navigation rail ──
    readonly property int navWidth: unified ? 200 : 180
    readonly property int navItemHeight: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.controlHeight
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 36 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 34) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
    readonly property int navCategorySpacing: Math.round((nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.tileGap + nayoriSettingsMaterialPreset.appearance.regalia.controlGap
        : nayoriSettingsMaterialPreset.appearance.editorialEverywhere ? 12 * nayoriSettingsMaterialPreset.appearance.editorial.spacing : 10) * nayoriSettingsMaterialPreset.appearance.fontSizeScale)
    readonly property int navItemSpacing: nayoriSettingsMaterialPreset.appearance.regaliaEverywhere ? nayoriSettingsMaterialPreset.appearance.regalia.controlGap : 2
}
