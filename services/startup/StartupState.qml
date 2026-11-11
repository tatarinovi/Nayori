import QtQuick

// One process-local barrier. Reports are scoped to the current output list;
// unplugged screens never hold startup, new screens must render before release.
QtObject {
    id: root
    property bool settingsReady: false
    property bool enabled: true
    property bool servicesReady: false
    property var outputs: []
    property var reports: ({})
    property var exitReports: ({})
    property bool present: true
    property bool dismissed: false
    property bool stalled: false
    property string error: ""
    property int warningDelay: 15000
    readonly property bool covered: outputs.length > 0
        && outputs.every(name => reports[name] && reports[name].cover)
    readonly property bool ready: settingsReady && servicesReady && outputs.length > 0
        && outputs.every(name => reports[name] && reports[name].wallpaper
            && reports[name].panels && reports[name].cover)
    readonly property bool releasing: ready || dismissed
    onSettingsReadyChanged: checkDisabled()
    onEnabledChanged: checkDisabled()
    function checkDisabled() { if (settingsReady && !enabled) present = false }
    function report(output, kind, value) {
        if (!present || outputs.indexOf(output) < 0) return
        const prior = reports[output] || {}
        if (prior[kind] === value) return
        const next = Object.assign({}, reports)
        next[output] = Object.assign({}, prior)
        next[output][kind] = value
        reports = next
    }
    function dismiss() { if (stalled) dismissed = true }
    // A removed then reconnected output must not reuse its old frame receipt.
    onOutputsChanged: {
        const next = {}
        for (const name of outputs) if (reports[name]) next[name] = reports[name]
        reports = next
        Qt.callLater(finishIfExited)
    }
    onReleasingChanged: if (!releasing) exitReports = ({})
    function exited(output) {
        if (!present || !releasing || outputs.indexOf(output) < 0) return
        exitReports = Object.assign({}, exitReports, { [output]: true })
        finishIfExited()
    }
    function finishIfExited() {
        if (present && releasing && outputs.length > 0 && outputs.every(name => exitReports[name])) present = false
    }
    property Timer deadline: Timer {
        interval: root.warningDelay
        running: root.present && !root.stalled
        onTriggered: root.stalled = true
    }
}
