.pragma library

// Куда девается верхний остров, если на всех экранах кроме первого он скрыт.
// screenNames[0] — основной монитор, как probeScreen в оболочке.
function screenList(screenNames) {
    if (!Array.isArray(screenNames))
        return []
    const names = []
    for (let i = 0; i < screenNames.length; ++i)
        names.push(typeof screenNames[i] === "string" ? screenNames[i] : "")
    return names
}

// Экран Naomi. "secondary" держит её на втором мониторе и не смотрит на полный экран.
// Иначе это основной экран, с тем же переносом, что у host().
function companionOutput(screenNames, screenMode, primaryFullscreen, fullscreenOutput) {
    const names = screenList(screenNames)
    if (screenMode === "secondary" && names.length > 1 && names[1] !== "")
        return names[1]
    return host(names, primaryFullscreen, fullscreenOutput)
}

function host(screenNames, primaryFullscreen, fullscreenOutput) {
    const names = screenList(screenNames)
    const primary = names.length > 0 ? names[0] : ""
    if (!primaryFullscreen || typeof fullscreenOutput !== "string" || fullscreenOutput === "")
        return primary
    const index = names.indexOf(fullscreenOutput)
    return index > 0 ? names[index] : primary
}

function topEnabled(screenName, screenNames, hideSecondary, primaryFullscreen, fullscreenOutput) {
    if (typeof screenName !== "string" || screenName === "")
        return false
    if (!hideSecondary)
        return true
    const names = screenList(screenNames)
    if (names.length > 0 && screenName === names[0])
        return true
    if (!primaryFullscreen || typeof fullscreenOutput !== "string" || fullscreenOutput === "" || fullscreenOutput === names[0])
        return false
    return screenName === fullscreenOutput && names.indexOf(fullscreenOutput) > 0
}

// Место, которое окна уступают острову на время переноса. 0, пока переноса нет.
// Настроенный верхний резерв не уменьшается: берётся большее из него и высоты капсулы.
function relocationReserve(active, topReserved, islandBand) {
    if (!active)
        return 0
    const configured = typeof topReserved === "number" && isFinite(topReserved) ? Math.max(0, topReserved) : 0
    const band = typeof islandBand === "number" && isFinite(islandBand) ? Math.max(0, Math.round(islandBand)) : 0
    return Math.round(Math.max(configured, band))
}
