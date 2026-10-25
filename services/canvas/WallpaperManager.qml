import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    // Bundled wallpaper: upscaled 3344 × 1882 edition.
    readonly property url defaultSource: Qt.resolvedUrl("../../assets/wallpapers/nayori.png")
    property string storageDirectory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nayori"
    property var state: ({ version: 1, enabled: true, shared: true, wallpaper: { source: "", mode: "fill" }, outputs: {} })
    property bool ready: false
    property bool saving: false
    property string message: ""
    property var renderErrors: ({})
    readonly property bool enabled: ready && state.enabled && Quickshell.env("NAYORI_CANVAS_DISABLED") !== "1"

    function validWallpaper(value) {
        return value && typeof value.source === "string"
            && (value.source === "" || /^file:\/\/\//.test(value.source))
            && ["fill", "fit", "stretch", "center"].indexOf(value.mode) >= 0
    }
    function wallpaper(output) {
        const value = !state.shared && Object.prototype.hasOwnProperty.call(state.outputs, output)
            ? state.outputs[output] : state.wallpaper
        return { source: value.source || String(defaultSource), mode: value.mode }
    }
    function restore(text) {
        try {
            const value = JSON.parse(text)
            if (value.version !== 1 || typeof value.enabled !== "boolean"
                || typeof value.shared !== "boolean" || !validWallpaper(value.wallpaper)
                || !value.outputs || typeof value.outputs !== "object" || Array.isArray(value.outputs))
                throw new Error("schema")
            for (const name of Object.keys(value.outputs))
                if (!validWallpaper(value.outputs[name])) throw new Error("output")
            state = value
        } catch (error) {
            message = "Не удалось прочитать настройки обоев. Показан стандартный фон. Примените настройки, чтобы сохранить их заново."
        }
        ready = true
    }
    function apply(output, source, mode, shared, enabled) {
        if (!ready || saving || !validWallpaper({ source: String(source), mode: mode })) return
        const next = JSON.parse(JSON.stringify(state))
        next.enabled = enabled
        next.shared = shared
        const value = { source: String(source), mode: mode }
        if (shared) next.wallpaper = value
        else if (output) next.outputs[output] = value
        else return
        state = next
        message = "Сохранение…"
        saving = true
        store.setText(JSON.stringify(state, null, 2) + "\n")
    }
    function report(output, failed) {
        const next = Object.assign({}, renderErrors)
        if (failed) next[output] = true
        else delete next[output]
        renderErrors = next
    }
    property Process directory: Process {
        command: ["mkdir", "-p", "--", root.storageDirectory]
        running: true
        onExited: function(code) {
            if (code === 0) store.path = root.storageDirectory + "/canvas.json"
            else root.message = "Не удалось создать каталог настроек Nayori."
        }
    }
    property FileView file: FileView {
        id: store
        atomicWrites: true
        printErrors: false
        onLoaded: root.restore(text())
        onLoadFailed: function(error) {
            root.ready = true
            if (error !== FileViewError.FileNotFound)
                root.message = "Не удалось прочитать настройки обоев. Проверьте доступ к canvas.json."
        }
        onSaved: { root.saving = false; root.message = "Обои сохранены." }
        onSaveFailed: {
            root.saving = false
            root.message = "Обои применены, но не сохранены. Проверьте доступ к каталогу настроек и повторите попытку."
        }
    }
}
