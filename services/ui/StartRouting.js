.pragma library

// На какой монитор уходит Super-тап или `start toggle`.
// Меню Пуск одно на все мониторы, поэтому открытое меню важнее «активного» монитора niri:
// иначе тап, которым пользователь хочет закрыть меню, открывает второе рядом.
function target(openOutput, screenNames, focusedOutput) {
    const names = Array.isArray(screenNames) ? screenNames : []
    if (openOutput && names.indexOf(openOutput) >= 0)
        return openOutput
    if (focusedOutput && names.indexOf(focusedOutput) >= 0)
        return focusedOutput
    return names.length > 0 ? names[0] : ""
}
