import QtQuick
import Quickshell
import Quickshell.Io
import "../status/MixerSources.js" as MixerSources
import "../island/NotificationPolicy.js" as NotificationPolicy
import "../ui/PanelModes.js" as PanelModes

// Owned by ShellRoot, never by a settings page or window.
QtObject {
    id: root

    property string storageDirectory: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/nayori"
    property var document: ({
        "version": 1
    })
    property var values: defaults()
    readonly property var panelReservations: values.panelReservations
    readonly property var panelModes: values.panelModes
    readonly property bool autoHideTop: values.autoHideTop
    readonly property bool autoHideApps: values.autoHideApps
    readonly property bool autoHideWorkspaces: values.autoHideWorkspaces
    readonly property bool bluetoothIconVisible: values.bluetoothIconVisible
    readonly property bool autoHideStatus: values.autoHideStatus
    readonly property bool hideSecondaryIsland: values.hideSecondaryIsland
    readonly property string fullscreenIslandOutput: values.fullscreenIslandOutput
    readonly property int topReserved: values.topReserved
    readonly property int bottomReserved: values.bottomReserved
    readonly property string colorScheme: values.colorScheme
    readonly property string surfaceStyle: values.surfaceStyle
    readonly property string accentMode: values.accentMode
    readonly property string manualAccent: values.manualAccent
    readonly property string companionStyle: values.companionStyle
    readonly property bool companionEnabled: values.companionEnabled
    readonly property bool companionDesktopOnly: values.companionDesktopOnly
    readonly property bool companionReactToPointer: values.companionReactToPointer
    readonly property bool companionSystemLines: values.companionSystemLines
    readonly property string fullscreenCompanionOutput: values.fullscreenCompanionOutput
    readonly property string companionScreen: values.companionScreen
    readonly property string companionSide: values.companionSide
    readonly property bool animationsEnabled: values.animationsEnabled
    readonly property string weatherCity: values.weatherCity
    readonly property int weatherRefreshMinutes: values.weatherRefreshMinutes
    readonly property bool islandRotationEnabled: values.islandRotationEnabled
    readonly property int islandRotationSeconds: values.islandRotationSeconds
    readonly property string startIconStyle: values.startIconStyle
    readonly property string preferredTerminal: values.preferredTerminal
    readonly property string preferredFileManager: values.preferredFileManager
    readonly property bool niriColorIntegration: values.niriColorIntegration
    readonly property bool strataThemeIntegration: values.strataThemeIntegration
    readonly property var mixerSources: values.mixerSources
    readonly property bool notificationsEnabled: values.notificationsEnabled
    // null — пользователь ещё не выбирал приём, тогда решает NAYORI_NOTIFICATIONS.
    readonly property var notificationReception: values.notificationReception
    readonly property var notificationSources: values.notificationSources
    readonly property var notificationsDndUntil: values.notificationsDndUntil
    readonly property bool notificationsDndManual: values.notificationsDndManual
    readonly property bool polkitAgent: values.polkitAgent === true
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
            "panelModes": {},
            "panelReservations": {},
            "autoHideTop": false,
            "autoHideApps": false,
            "autoHideWorkspaces": false,
            "autoHideStatus": false,
            "bluetoothIconVisible": true,
            "hideSecondaryIsland": false,
            "fullscreenIslandOutput": "",
            "topReserved": 0,
            "bottomReserved": 0,
            "animationsEnabled": true,
            "companionEnabled": false,
            "companionStyle": "current",
            "companionDesktopOnly": false,
            "companionReactToPointer": true,
            "companionSystemLines": true,
            "fullscreenCompanionOutput": "",
            "companionScreen": "primary",
            "companionSide": "right",
            "colorScheme": "dark",
            "surfaceStyle": "solid",
            "accentMode": "default",
            "manualAccent": "#C0AFD1",
            "startIconStyle": "current",
            "weatherCity": "",
            "weatherRefreshMinutes": 15,
            "islandRotationEnabled": true,
            "islandRotationSeconds": 15,
            "preferredTerminal": "kitty",
            "preferredFileManager": "io.github.lgse.Strata",
            "niriColorIntegration": true,
            "strataThemeIntegration": true,
            "captureShotDir": "~/Pictures/Screenshots",
            "captureVideoDir": "~/Videos/Screencasts",
            "captureColor": "#CAA7AA",
            "captureFps": 30,
            "captureFormat": "mp4",
            "captureQuality": "high",
            "captureCountdown": 3,
            "captureMic": false,
            "captureSystemAudio": true,
            "captureCursor": true,
            "mixerSources": [],
            "notificationsEnabled": true,
            "notificationReception": null,
            "notificationSources": [],
            "notificationsDndUntil": 0,
            "notificationsDndManual": false,
            "polkitAgent": false
        };
    }

    function normalize(key, value) {
        const fallback = defaults()[key];
        if (key === "panelModes") return PanelModes.normalize(value);
        if (key === "panelReservations") return PanelModes.normalizeReservations(value);
        if (key === "mixerSources")
            return MixerSources.normalize(value);
        if (key === "notificationSources")
            return NotificationPolicy.normalizeSources(value);
        if (key === "notificationReception")
            return value === true || value === false ? value : null;
        if (key === "notificationsEnabled")
            return typeof value === "boolean" ? value : true;
        if (key === "notificationsDndManual")
            return value === true;
        if (key === "notificationsDndUntil")
            return typeof value === "number" && isFinite(value) && value > 0 ? Math.round(value) : 0;
        if (key === "captureShotDir" || key === "captureVideoDir")
            return typeof value === "string" && /^(\/|~\/)/.test(value.trim()) && !/[\x00-\x1f]/.test(value) && value.length < 4096 ? value.trim() : fallback;
        if (key === "captureFps") return value === 30 || value === 60 ? value : fallback;
        if (key === "captureFormat") return value === "mp4" || value === "webm" ? value : fallback;
        if (key === "captureQuality") return value === "high" || value === "very_high" ? value : fallback;
        if (key === "captureCountdown") return value === 0 || value === 3 || value === 5 ? value : fallback;
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

        if (key === "companionStyle")
            return value === "current" || value === "pixel-art" || value === "layered" || value === "haori" || value === "chibi" ? value : fallback;

        if (key === "companionScreen")
            return value === "primary" || value === "secondary" ? value : fallback;

        if (key === "companionSide")
            return value === "left" || value === "right" ? value : fallback;

        if (key === "colorScheme")
            return value === "dark" || value === "light" ? value : fallback;

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

        if (key === "fullscreenIslandOutput" || key === "fullscreenCompanionOutput") {
            if (typeof value !== "string")
                return fallback;
            const trimmed = value.trim();
            return trimmed.length > 256 ? fallback : trimmed;
        }

        if (key === "accentMode")
            return value === "default" || value === "automatic" || value === "manual" ? value : fallback;

        if (key === "niriColorIntegration" || key === "strataThemeIntegration")
            return typeof value === "boolean" ? value : fallback;

        if (key === "polkitAgent")
            return value === true;

        if (key === "manualAccent" || key === "captureColor") {
            if (typeof value !== "string")
                return fallback;
            const match = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.exec(value.trim());
            if (!match)
                return fallback;
            let body = match[1];
            if (body.length === 3)
                body = body[0] + body[0] + body[1] + body[1] + body[2] + body[2];
            else if (body.length === 8)
                body = body.slice(2);
            return "#" + body.toUpperCase();
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
            const unchanged = (key === "panelModes" || key === "panelReservations") ? JSON.stringify(next[key]) === JSON.stringify(value) : key === "mixerSources" ? MixerSources.same(next[key], value) : key === "notificationSources" ? NotificationPolicy.same(next[key], value) : next[key] === value;
            if (unchanged)
                continue;

            next[key] = value;
            changed = true;
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
