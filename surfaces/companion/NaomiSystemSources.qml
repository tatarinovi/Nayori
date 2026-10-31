pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Networking as QsNet
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "../../services/niri"
import "../../services/status"
import "../../services/companion/NaomiSystemData.js" as SystemData
import "../../services/companion/NaomiPresence.js" as Presence
import "../island"

// Тонкая обвязка: источники данных, которые уже есть в проекте, подаются в NaomiController.
// Решает, говорить ли, чистая логика NaomiSystemEvents.js; здесь только чтение.
//   CPU — тот же Cpu.qml, что у лисы острова (/proc/stat раз в секунду);
//   окна — singleton Niri (EventStream);   батарея — Quickshell.Services.UPower (displayDevice);
//   интернет — тот же Network.qml, что у панели (Quickshell.Networking);
//   ввод — IdleMonitor (ext-idle-notify): две и десять минут без действий;
//   обновление — раз в несколько секунд читает процессы pacman/paru/yay/topgrade и db.lck. Ничего не запускает.
QtObject {
    id: root
    required property var controller
    // Читать источники, требующие работы (CPU, ввод, процессы). Окна, батарея и сеть читаются всегда:
    // так базовое состояние верно, когда реплики включают.
    property bool enabled: true
    property bool presenceEnabled: true
    property bool sessionLocked: false
    readonly property bool mediaPlaying: musicSnapshot.some(p => p.isPlaying === true)
    onMediaPlayingChanged: {
        root.controller.systemMediaPlayback(mediaPlaying)
        // Playback ending while already idle is not evidence that the user just left.
        if (!mediaPlaying && root.enabled && root.presence.isIdle) playbackAway.restart()
        else playbackAway.stop()
    }
    property Timer playbackAway: Timer {
        interval: SystemData.data.idleAway * 1000
        onTriggered: if (root.enabled && root.presence.isIdle && !root.mediaPlaying)
            root.controller.systemIdle("away", true)
    }
    property Binding presenceBinding: Binding { target: root.controller; property: "reminderPresent"; value: Presence.present(root.sessionLocked, root.presence.isIdle, root.mediaPlaying) }

    // --- CPU ---
    property Cpu cpu: Cpu { active: root.enabled }
    property Binding cpuBinding: Binding { target: root.controller; property: "cpuLoad"; value: root.cpu.load }

    // --- окна ---
    property Connections niriWatch: Connections {
        target: Niri
        function onWindowsChanged() { root.pushWindows() }
        function onAvailableChanged() { root.pushWindows() }
    }
    function pushWindows() { root.controller.systemWindows(Niri.windows, Niri.available) }

    // --- Яндекс Музыка: настоящее воспроизведение, включая браузерные вкладки ---
    // Читаем все плееры, независимо от выбранного в острове. Binding наблюдает
    // isPlaying/metadata каждого плеера, а не только изменение самого списка.
    readonly property var musicSnapshot: Mpris.players.values.map(p => ({
        identity: p.identity || "",
        desktopEntry: p.desktopEntry || "",
        dbusName: p.dbusName || "",
        trackUrl: p.metadata ? String(p.metadata["xesam:url"] || "") : "",
        isPlaying: p.isPlaying
    }))
    property bool musicReady: false
    onMusicSnapshotChanged: if (musicReady) root.controller.systemMusic(musicSnapshot)
    // MPRIS discovers players asynchronously on shell startup. Establish a silent
    // baseline after discovery instead of reacting to already playing music.
    property Timer musicBaseline: Timer {
        interval: 3000
        running: true
        onTriggered: {
            root.controller.systemMusic(root.musicSnapshot)
            root.musicReady = true
        }
    }

    // --- батарея ---
    readonly property var battery: UPower.displayDevice
    readonly property bool batteryReady: !!(battery && battery.ready && battery.isPresent)
    readonly property real batteryPercent: batteryReady ? Math.max(0, Math.min(1, battery.percentage)) * 100 : 0
    readonly property bool charging: !UPower.onBattery
    readonly property string batteryKey: batteryReady + "|" + Math.round(batteryPercent) + "|" + charging
    onBatteryKeyChanged: pushBattery()
    function pushBattery() { root.controller.systemBattery(batteryReady, batteryPercent, charging) }

    // --- интернет ---
    property Network network: Network {}
    // online — связь есть и без ограничений; offline — нет соединения, «ограничено» или NetworkManager видит None;
    // unknown — нет данных или портал авторизации: состояние не меняем.
    readonly property string netState: {
        if (!network.available) return "unknown"
        if (!network.linked) return "offline"
        if (network.label === "limited") return "offline"
        if (network.degraded) return "unknown"
        return network.connectivity === QsNet.NetworkConnectivity.None ? "offline" : "online"
    }
    onNetStateChanged: root.controller.systemNetwork(netState)

    // --- ввод ---
    property IdleMonitor presence: IdleMonitor {
        enabled: root.presenceEnabled
        timeout: SystemData.data.idleAway
        respectInhibitors: false
        onIsIdleChanged: {
            if (!isIdle) root.playbackAway.stop()
            if (root.enabled && !root.mediaPlaying) root.controller.systemIdle("away", isIdle)
        }
    }
    property IdleMonitor long: IdleMonitor {
        enabled: root.enabled
        timeout: SystemData.data.idleLong
        respectInhibitors: false
        onIsIdleChanged: if (!root.mediaPlaying) root.controller.systemIdle("long", isIdle)
    }
    property Binding idleBinding: Binding { target: root.controller; property: "userIdle"; value: root.presence.isIdle && !root.mediaPlaying }

    // --- обновление системы (только чтение) ---
    readonly property string probeScript: "[ -e '" + SystemData.data.pacmanLock + "' ] && echo LOCK; "
        + "pgrep -a -x '" + SystemData.data.updateProcesses.join("|") + "' 2>/dev/null; true"
    property Process probe: Process {
        command: ["sh", "-c", root.probeScript]
        stdout: StdioCollector { id: probeOut; waitForEnd: true }
        onExited: root.controller.systemUpdate(root.controller.scanUpdate(probeOut.text || ""))
    }
    property Timer poll: Timer {
        interval: SystemData.data.updatePoll * 1000
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: if (!root.probe.running) root.probe.running = true
    }

    Component.onCompleted: {
        root.controller.systemMediaPlayback(root.mediaPlaying)
        pushWindows()
        pushBattery()
        root.controller.systemNetwork(netState)
    }
}
