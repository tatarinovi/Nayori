// SPDX-License-Identifier: GPL-3.0-only
// Adapted 2026-11-11 from Ryoku's ryogami/daemon/preview.go at
// f7197d72de8a21e44b0bea922bdd915f28f6b327. See NOTICE.
// The preview is a paint, never an apply. Committed state remains authoritative.
// Unlike Ryogami's accumulated paint targets, replacing this value immediately
// restores outputs no longer covered; no frame snapshots are needed in QML.
function begin(source, mode, outputs) {
    return { source: source, mode: mode, outputs: outputs.slice() };
}

function covers(preview, output) {
    return preview !== null && (preview.outputs.length === 0
        || preview.outputs.indexOf("*") >= 0 || preview.outputs.indexOf(output) >= 0);
}

function frame(preview, output, committed) {
    return covers(preview, output)
        ? { source: preview.source, mode: preview.mode, preview: true }
        : committed;
}
