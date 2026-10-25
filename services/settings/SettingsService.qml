import QtQuick
import Quickshell
import Quickshell.Io

// Owned by ShellRoot, never by a settings page or window.
QtObject {
    id: root

    property string storageDirectory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nayori"
    property var document: ({
        "version": 1
    })
    property var values: defaults()
    readonly property bool autoHideTop: values.autoHideTop
    readonly property bool autoHideApps: values.autoHideApps
    readonly property bool autoHideWorkspaces: values.autoHideWorkspaces
    readonly property bool autoHideStatus: values.autoHideStatus
    readonly property bool hideSecondaryIsland: values.hideSecondaryIsland
    readonly property int topReserved: values.topReserved
    readonly property int bottomReserved: values.bottomReserved
    readonly property string surfaceStyle: values.surfaceStyle
    readonly property bool animationsEnabled: values.animationsEnabled
    readonly property string weatherCity: values.weatherCity
    readonly property int weatherRefreshMinutes: values.weatherRefreshMinutes
    readonly property bool islandRotationEnabled: values.islandRotationEnabled
    readonly property int islandRotationSeconds: values.islandRotationSeconds
    readonly property string startIconStyle: values.startIconStyle
    readonly property string preferredTerminal: values.preferredTerminal
    readonly property string preferredFileManager: values.preferredFileManager
    property bool ready: false
    property bool dirty: false
    property bool saving: false
    property bool writeFailed: false
    // loading, writable, corrupt, unsupported, unreadable
    property string state: "loading"
    property string message: ""
    property string backupPath: ""
    property int revision: 0
    property int savedRevision: 0
    readonly property bool canRecover: ready && state === "corrupt" && !backup.running
    readonly property bool canRetry: ready && state === "writable" && dirty && writeFailed && !saving
    property Timer debounceTimer

    debounceTimer: Timer {
        id: debounce

        interval: 250
        onTriggered: root.flush(false)
    }

    property Process directoryProcess

    directoryProcess: Process {
        command: ["mkdir", "-p", "--", root.storageDirectory]
        running: true
        onExited: function(code) {
            // Still try reading on mkdir failure (e.g. a read-only existing directory).
            store.path = root.storageDirectory + "/settings.json";
        }
    }

    property Process backupProcess

    backupProcess: Process {
        id: backup

        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../scripts/settings-backup.py").toString()).replace(/^file:\/\//, ""), root.storageDirectory + "/settings.json"]
        onExited: function(code) {
            if (code !== 0) {
                root.message = "Не удалось создать резервную копию. Исходный файл не изменён. Повторите восстановление.";
                return ;
            }
            root.document = {
                "version": 1
            };
            root.state = "writable";
            root.dirty = true;
            root.revision++;
            root.flush(false);
        }

        stdout: StdioCollector {
            onStreamFinished: root.backupPath = text.trim()
        }

    }

    property FileView file

    file: FileView {
        id: store

        atomicWrites: true
        printErrors: false
        watchChanges: false
        onLoaded: root.restore(text())
        onLoadFailed: function(error) {
            if (root.ready)
                return ;

            root.ready = true;
            if (error === FileViewError.FileNotFound) {
                root.state = "writable";
            } else {
                root.state = "unreadable";
                root.message = "Не удалось прочитать settings.json. Проверьте доступ к файлу и перезапустите Nayori.";
            }
        }
        onSaved: {
            root.saving = false;
            root.dirty = root.revision !== root.savedRevision;
            root.message = root.dirty ? "Сохранение…" : "Настройки сохранены.";
            if (root.dirty)
                debounce.restart();

        }
        onSaveFailed: {
            root.saving = false;
            root.dirty = true;
            root.writeFailed = true;
            root.message = "Настройки применены, но не сохранены. Проверьте доступ к каталогу и повторите запись.";
        }
    }

    function defaults() {
        return {
            "autoHideTop": false,
            "autoHideApps": false,
            "autoHideWorkspaces": false,
            "autoHideStatus": false,
            "hideSecondaryIsland": false,
            "topReserved": 0,
            "bottomReserved": 0,
            "animationsEnabled": true,
            "surfaceStyle": "solid",
            "startIconStyle": "current",
            "weatherCity": "",
            "weatherRefreshMinutes": 15,
            "islandRotationEnabled": true,
            "islandRotationSeconds": 15,
            "preferredTerminal": "kitty",
            "preferredFileManager": "io.github.lgse.Strata"
        };
    }

    function normalize(key, value) {
        const fallback = defaults()[key];
        if (key === "topReserved" || key === "bottomReserved")
            return typeof value === "number" && isFinite(value) ? Math.max(0, Math.min(200, Math.round(value / 4) * 4)) : fallback;

        if (key === "weatherRefreshMinutes")
            return typeof value === "number" && isFinite(value) && Math.floor(value) === value && value >= 1 && value <= 180 ? value : fallback;

        if (key === "islandRotationSeconds") {
            if (typeof value !== "number" || !isFinite(value))
                return fallback;
            return Math.max(5, Math.min(120, Math.round(value)));
        }

        if (key === "startIconStyle")
            return value === "current" || value === "fox" ? value : fallback;

        if (key === "surfaceStyle")
            return value === "solid" || value === "frosted" ? value : fallback;

        if (key === "weatherCity")
            return typeof value === "string" ? value.trim() : fallback;

        if (key === "preferredTerminal" || key === "preferredFileManager") {
            if (typeof value !== "string")
                return fallback;
            const trimmed = value.trim();
            return trimmed.length > 0 ? trimmed : fallback;
        }

        return typeof value === "boolean" ? value : fallback;
    }

    function restore(text) {
        if (ready)
            return ;

        try {
            const parsed = JSON.parse(text);
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                throw new Error("object");

            document = parsed;
            if (parsed.version !== 1) {
                state = "unsupported";
                message = "Версия settings.json не поддерживается. Изменения действуют только в этом сеансе.";
            } else {
                const next = defaults();
                for (const key of Object.keys(next)) next[key] = normalize(key, parsed[key])
                values = next;
                state = "writable";
            }
        } catch (error) {
            state = "corrupt";
            message = "settings.json повреждён. Восстановите настройки; исходный файл будет сохранён в копии.";
        }
        ready = true;
    }

    function update(patch) {
        if (!ready)
            return ;

        const next = Object.assign({
        }, values);
        let changed = false;
        for (const key of Object.keys(defaults())) {
            if (!Object.prototype.hasOwnProperty.call(patch, key))
                continue;

            const value = normalize(key, patch[key]);
            if (next[key] !== value) {
                next[key] = value;
                changed = true;
            }
        }
        if (!changed)
            return ;

        values = next;
        revision++;
        dirty = true;
        if (state === "writable") {
            message = "Сохранение…";
            debounce.restart();
        }
    }

    function flush(blocking) {
        debounce.stop();
        if (saving && blocking === true) store.waitForJob();
        if (!ready || state !== "writable" || !dirty || saving)
            return ;
        if (writeFailed) {
            // FileView caches failed writes and skips identical setText calls.
            // Refresh only the I/O cache; restore() ignores subsequent loads.
            store.reload();
            store.waitForJob();
        }
        // Preserve the entire source document, including unknown nested values.
        const next = Object.assign({
        }, document, values, {
            "version": 1
        });
        document = next;
        const text = JSON.stringify(next, null, 2) + "\n";
        // Returning to the persisted state needs no write (and FileView emits no saved signal).
        if (store.text() === text) {
            dirty = false;
            writeFailed = false;
            message = "Настройки сохранены.";
            return;
        }
        savedRevision = revision;
        saving = true;
        writeFailed = false;
        store.blockWrites = blocking === true;
        store.setText(text);
    }

    function recover() {
        if (!canRecover)
            return ;

        message = "Создание резервной копии…";
        backup.running = true;
    }

    // Best effort on component teardown; synchronous writes complete before return.
    // Abrupt process termination does not necessarily destroy QML components.
    Component.onDestruction: flush(true)
}
