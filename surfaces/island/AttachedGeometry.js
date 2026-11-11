// Left edge of the top cubic at a normalized height. Shared with the region
// approximation; path topology and coordinates never depend on content state.
function topEdge(start, depth, y) {
    if (depth <= 0) return 0;
    const target = Math.max(0, Math.min(1, y / depth));
    let lo = 0, hi = 1;
    for (let i = 0; i < 16; ++i) {
        const t = (lo + hi) / 2;
        const v = 3 * (1 - t) * t * t * 0.447715 + t * t * t;
        if (v < target) lo = t; else hi = t;
    }
    const t = (lo + hi) / 2, u = 1 - t;
    return start * (u * u * u + 3 * u * u * t * 0.447715);
}
