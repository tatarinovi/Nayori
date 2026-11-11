import QtQuick

// One optical grid and stroke weight for telemetry and power-profile icons.
// Original SVG geometry; no icon font or third-party artwork required.
Image {
    id: root
    objectName: "systemIcon"
    property string name: "cpu"
    property color ink: "white"
    readonly property var shapes: ({
        cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9" y="9" width="6" height="6" rx="1"/><path d="M9 3v3m6-3v3M9 18v3m6-3v3M3 9h3m-3 6h3m12-6h3m-3 6h3"/>',
        gpu: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="11" cy="12" r="3.25"/><path d="M11 8.75v6.5M7.75 12h6.5M18 10v4M6 18v3m4-3v2"/>',
        memory: '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 10v4m5-4v4m5-4v4M6 18v3m4-3v3m4-3v3m4-3v3"/>',
        disk: '<path d="m6 4-3 10v5a1 1 0 0 0 1 1h16a1 1 0 0 0 1-1v-5L18 4Z"/><path d="M3 14h18m-14 3h.01M11 17h.01"/>',
        network: '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12h18"/>',
        state: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4M7 9h4m-4 3h7"/>',
        power: '<path d="m13 3-8 11h6l-1 7 9-12h-7Z"/>',
        eco: '<path d="M5 16C1 7 10 4 20 4c0 10-3 17-12 14M4 21 15 10"/>',
        balanced: '<path d="M3 7h4m4 0h10M3 17h10m4 0h4"/><circle cx="9" cy="7" r="2"/><circle cx="15" cy="17" r="2"/>',
        performance: '<path d="M4.2 18a9 9 0 1 1 15.6 0M6 16l1.5-1M6.5 7.5 8 9m4-6v2m5.5 2.5L16 9M12 14l4-3"/><circle cx="12" cy="14" r="1.5"/>'
    })
    width: 20
    height: 20
    sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
    source: "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="' + ink.toString() + '" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">' + (shapes[name] || shapes.state) + '</svg>')
    fillMode: Image.PreserveAspectFit
}
