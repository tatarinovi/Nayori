import QtQuick
import Quickshell.Services.Pipewire as QsPw

// Клиент уже запущенного PipeWire. Свой демон не поднимается.
// Mute и уровень читаются с узла и обновляются его сигналами.
QtObject {
    id: root

    readonly property var sink: QsPw.Pipewire.defaultAudioSink
    // sink.ready в этой сборке Quickshell остаётся false у уже звучащего узла.
    // Достаточно живого PipeWire и аудиоинтерфейса узла.
    readonly property bool available: QsPw.Pipewire.ready
            && sink !== null
            && sink.audio !== null
    readonly property bool muted: available && sink.audio.muted
    readonly property real level: available ? sink.audio.volume : 0
    readonly property string label: {
        if (!available)
            return ""
        if (muted)
            return "mute"
        var pct = Math.round(level * 100)
        if (!isFinite(pct))
            return ""
        return pct + "%"
    }

    property QsPw.PwObjectTracker tracker: QsPw.PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function setVolume(value) {
        if (available && isFinite(value))
            sink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMuted() {
        if (!available || sink === null || sink.audio === null)
            return
        sink.audio.muted = !sink.audio.muted
    }
}
