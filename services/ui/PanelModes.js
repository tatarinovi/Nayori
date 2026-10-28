// Overrides are keyed by connector name, so unplugging/reordering screens keeps preferences.
function normalize(value) {
    const result = {};
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    for (const output of Object.keys(value)) {
        if (!output || output.length > 256 || /[\x00-\x1f]/.test(output)) continue;
        const entry = value[output];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const modes = {};
        for (const part of ["top", "apps", "workspaces", "status"]) {
            const mode = entry[part];
            if (mode === "always" || mode === "auto" || mode === "hidden") modes[part] = mode;
        }
        if (Object.keys(modes).length) Object.defineProperty(result, output, {value: modes, enumerable: true, configurable: true});
    }
    return result;
}
function explicitMode(overrides, output, part) {
    return overrides && Object.prototype.hasOwnProperty.call(overrides, output) ? overrides[output][part] || "" : "";
}
function mode(overrides, output, part, legacyAuto, legacyHidden) {
    return explicitMode(overrides, output, part) || (legacyHidden ? "hidden" : legacyAuto ? "auto" : "always");
}
function updated(overrides, output, part, mode) {
    const next = normalize(overrides);
    const entry = Object.assign({}, Object.prototype.hasOwnProperty.call(next, output) ? next[output] : {});
    entry[part] = mode;
    Object.defineProperty(next, output, {value: entry, enumerable: true, configurable: true});
    return normalize(next);
}

function normalizeReservations(value) {
    const result = {};
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    for (const output of Object.keys(value)) {
        if (!output || output.length > 256 || /[\x00-\x1f]/.test(output)) continue;
        const entry = value[output];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const reservation = {};
        for (const edge of ["top", "bottom"]) {
            const amount = entry[edge];
            if (typeof amount === "number" && isFinite(amount))
                reservation[edge] = Math.max(0, Math.min(200, Math.round(amount / 4) * 4));
        }
        if (Object.keys(reservation).length)
            Object.defineProperty(result, output, {value: reservation, enumerable: true, configurable: true});
    }
    return result;
}
function reservation(overrides, output, edge, fallback) {
    const entry = overrides && Object.prototype.hasOwnProperty.call(overrides, output) ? overrides[output] : null;
    return entry && typeof entry[edge] === "number" ? entry[edge] : fallback;
}
function updatedReservation(overrides, output, top, bottom) {
    const next = normalizeReservations(overrides);
    Object.defineProperty(next, output, {value: {top: top, bottom: bottom}, enumerable: true, configurable: true});
    return normalizeReservations(next);
}
