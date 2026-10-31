.pragma library

// Общие размеры панелей. Токены одни на все экраны: разрешение выхода их не меняет.
// Режимы «Не отображать» прячут панель, но не меняют эту высоту.
// Снизу один резерв на все острова, поэтому берётся самое высокое окно.

function appsIconSlot() {
    return 40
}

function topReserve(spacingSmall, panelHeight) {
    const gap = whole(spacingSmall)
    // Отступ окна, капсула и такой же зазор под ней. ScreenPanels.islandBand.
    return gap * 2 + whole(panelHeight)
}

function bottomReserve(spacingSmall, panelHeight, controlHeight) {
    const gap = whole(spacingSmall)
    // IslandWindow: margins.bottom = 0, implicitHeight = высота острова + spacing.small.
    const workspaces = whole(panelHeight) + gap
    const status = whole(controlHeight) + gap * 2 + gap
    const apps = appsIconSlot() + gap * 2 + gap
    return Math.max(workspaces, status, apps)
}

function fit(tokens) {
    const spacing = tokens && tokens.spacing ? tokens.spacing.small : 0
    const panel = tokens && tokens.panel ? tokens.panel : {}
    return {
        top: topReserve(spacing, panel.height),
        bottom: bottomReserve(spacing, panel.height, panel.control)
    }
}

function whole(value) {
    const number = Number(value)
    return isFinite(number) ? Math.max(0, Math.round(number)) : 0
}
