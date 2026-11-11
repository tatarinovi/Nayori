import QtQuick
import Quickshell
import Quickshell.Io

// A disposable last-known appearance, never a second settings store. The real
// session publishes only after SettingsService and the current palette settle.
QtObject {
    id: root
    property string directory: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/nayori"
    property bool ready: false
    property bool writable: false
    property var snapshot: defaults()
    property var pending: null
    function defaults() {
        return {version: 1, accent: "#C0AFD1", enabled: true, dynamicAccent: true,
            fadeDuration: 220, animationsEnabled: true}
    }
    function normalize(value) {
        const fallback = defaults()
        if (!value || value.version !== 1) return fallback
        return {
            version: 1,
            accent: typeof value.accent === "string" && /^#[0-9a-fA-F]{6}$/.test(value.accent) ? value.accent : fallback.accent,
            enabled: typeof value.enabled === "boolean" ? value.enabled : true,
            dynamicAccent: typeof value.dynamicAccent === "boolean" ? value.dynamicAccent : true,
            fadeDuration: typeof value.fadeDuration === "number" && isFinite(value.fadeDuration)
                ? Math.max(0, Math.min(500, Math.round(value.fadeDuration))) : 220,
            animationsEnabled: typeof value.animationsEnabled === "boolean" ? value.animationsEnabled : true
        }
    }
    function restore(text) {
        if (ready) return
        try { snapshot = normalize(JSON.parse(text)) } catch (error) { snapshot = defaults() }
        ready = true
    }
    function publish(value) {
        pending = normalize(value)
        debounce.restart()
    }
    function flush() {
        if (!pending) return
        if (!writable) {
            if (!makeDirectory.running) makeDirectory.running = true
            return
        }
        const text = JSON.stringify(pending) + "\n"
        if (store.text() !== text) store.setText(text)
    }
    property Timer debounce: Timer { interval: 100; onTriggered: root.flush() }
    // Reading needs no mkdir, subprocess, settings service, or compositor IPC.
    property FileView file: FileView {
        id: store
        path: root.directory + "/startup.json"
        atomicWrites: true
        printErrors: false
        watchChanges: false
        onLoaded: root.restore(text())
        onLoadFailed: if (!root.ready) root.ready = true
    }
    property Process makeDirectory: Process {
        command: ["mkdir", "-p", "--", root.directory]
        onExited: code => {
            root.writable = code === 0
            if (root.writable) root.flush()
        }
    }
}
