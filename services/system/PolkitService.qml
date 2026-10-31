pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "PolkitDialog.js" as Dialog

// Агент создаётся только при polkitAgent: true и свободном имени. Чужой агент не останавливается.
QtObject {
    id: root
    property bool enabled: false
    property string primaryName: ""
    property var backend: null
    property var session: Dialog.create()
    property var view: null
    property int pendingCount: 0
    property string phase: "off"
    property bool probeSettled: false
    property bool blockRegistration: false
    property string agentHint: ""
    property string nameOwner: ""
    property bool retireBackend: false
    property bool registrationSettled: false
    readonly property bool dialogOpen: view !== null
    readonly property string scriptFile: {
        let path = Qt.resolvedUrl("polkit_status.py").toString()
        if (path.indexOf("file://") === 0) path = path.slice("file://".length)
        try { path = decodeURIComponent(path) } catch (error) { return "" }
        return path
    }
    readonly property string statusText: {
        if (!probeSettled && phase === "off")
            return "Проверяем, есть ли в\u00A0сеансе другой агент"
        if (phase === "off") {
            if (nameOwner !== "")
                return "Агент выключен. Имя уже занято: " + nameOwner + ". Nayori его не заменяет"
            if (agentHint !== "")
                return "Агент выключен. Сейчас запущен " + agentHint + ". Nayori его не останавливает"
            return "Агент выключен. Nayori не регистрируется и не заменяет другой агент"
        }
        if (phase === "probing" || phase === "connecting")
            return "Подключение к\u00A0службе подтверждения"
        if (phase === "registered")
            return "Nayori принимает запросы подтверждения"
        if (phase === "missing")
            return "Модуль Quickshell Polkit недоступен. Агент не запущен"
        if (nameOwner !== "")
            return "Имя агента занято: " + nameOwner + ". Nayori его не заменяет. Выключите тот агент сами и снова включите переключатель"
        if (agentHint !== "")
            return "Сейчас запущен " + agentHint + ". Nayori его не заменила. Выключите тот агент сами и снова включите переключатель"
        return "Для этого сеанса агент уже есть. Nayori его не заменила. Выключите тот агент сами и снова включите переключатель"
    }

    function describe(comm, pid) {
        const name = String(comm || "").trim()
        if (!name && !(pid > 0)) return ""
        if (name && pid > 0) return name + ", процесс " + pid
        if (name) return name
        return "процесс " + pid
    }
    function applyProbe(data) {
        blockRegistration = !!data.blockRegistration
        const owners = []
        const sessionOwner = describe(data.sessionComm, data.sessionPid)
        const systemOwner = describe(data.systemComm, data.systemPid)
        if (data.sessionOwned && sessionOwner) owners.push(sessionOwner)
        if (data.systemOwned && systemOwner && owners.indexOf(systemOwner) < 0) owners.push(systemOwner)
        nameOwner = owners.join(", ")
        const hints = (data.agents || []).map(item => describe(item.comm, item.pid)).filter(item => item !== "")
        agentHint = hints.join(", ")
    }
    function ingestProbe(line) {
        const late = probeSettled
        let data = null
        try { data = JSON.parse(String(line || "")) } catch (error) { data = null }
        if (!data || data.ok === false) {
            if (!late) {
                blockRegistration = false
                nameOwner = ""
            }
        } else applyProbe(data)
        probeSettled = true
        probeTimer.stop()
        if (late && backend && backend.registered) return
        if (blockRegistration && backend && !backend.registered) stopAgent()
        sync()
    }
    function startProbe() {
        if (!scriptFile || probe.running) return
        probeTimer.restart()
        probe.running = true
    }
    function publish() {
        const active = Dialog.shown(session)
        pendingCount = session.queue.length
        if (!active) {
            view = null
            return
        }
        view = {
            cookie: active.cookie,
            message: active.message,
            actionId: active.actionId,
            iconName: active.iconName,
            identities: active.identities.map(item => ({
                id: item.id,
                title: Dialog.identityTitle(item)
            })),
            selected: active.selected,
            hint: Dialog.promptHint(active.prompt),
            responseRequired: active.responseRequired,
            responseVisible: active.responseVisible,
            failed: active.failed,
            errorText: active.errorText,
            infoText: active.infoText,
            generation: active.generation,
            pending: session.queue.length
        }
    }
    function identityRecord(item) {
        if (!item) return null
        let name = ""
        try { name = item["string"] || "" } catch (error) { name = "" }
        if (!name) name = item.name || ""
        return { id: item.id, name: name, displayName: item.displayName || name, isGroup: !!item.isGroup }
    }
    function snapshot(flow) {
        const identities = []
        const list = flow.identities || []
        for (let i = 0; i < list.length; ++i) {
            const record = identityRecord(list[i])
            if (record) identities.push(record)
        }
        const selected = flow.selectedIdentity
        return {
            cookie: flow.cookie || "",
            message: flow.message || "",
            actionId: flow.actionId || "",
            iconName: flow.iconName || "",
            identities: identities,
            selectedId: selected ? selected.id : undefined,
            prompt: flow.inputPrompt || "",
            responseRequired: !!flow.isResponseRequired,
            responseVisible: !!flow.responseVisible
        }
    }
    function adopt() {
        const flow = backend ? backend.flow : null
        if (!flow || !flow.cookie) {
            if (session.active && (session.active.phase === "active" || session.active.phase === "failed"))
                Dialog.settle(session, session.active.cookie, "left")
            Dialog.advance(session)
            publish()
            return
        }
        Dialog.follow(session, snapshot(flow))
        publish()
    }
    function syncPrompt() {
        const flow = backend ? backend.flow : null
        if (!flow || !session.active || flow.cookie !== session.active.cookie) return
        Dialog.prompt(session, flow.cookie, {
            prompt: flow.inputPrompt || "",
            responseRequired: !!flow.isResponseRequired,
            responseVisible: !!flow.responseVisible
        })
        publish()
    }
    function syncNote() {
        const flow = backend ? backend.flow : null
        if (!flow || !session.active || flow.cookie !== session.active.cookie) return
        Dialog.note(session, flow.cookie, flow.supplementaryMessage || "", !!flow.supplementaryIsError)
        publish()
    }
    function onFailed() {
        const flow = backend ? backend.flow : null
        if (!flow || !session.active || flow.cookie !== session.active.cookie) return
        const message = flow.supplementaryIsError ? (flow.supplementaryMessage || "") : ""
        Dialog.fail(session, flow.cookie, message)
        publish()
    }
    function onSucceeded() {
        const flow = backend ? backend.flow : null
        if (flow && session.active && flow.cookie === session.active.cookie)
            Dialog.settle(session, flow.cookie, "done")
        publish()
    }
    function onCancelled() {
        const flow = backend ? backend.flow : null
        if (flow && session.active && flow.cookie === session.active.cookie)
            Dialog.settle(session, flow.cookie, "cancelled")
        publish()
    }
    function canSubmit() {
        const active = session.active
        if (!active) return false
        return Dialog.canSubmit(session, active.cookie, active.generation)
    }
    function submit(response) {
        const flow = backend ? backend.flow : null
        const active = session.active
        if (typeof response !== "string" || response.length === 0) return false
        if (!flow || !active || flow.cookie !== active.cookie) return false
        if (!Dialog.canSubmit(session, active.cookie, active.generation)) return false
        flow.submit(response)
        Dialog.prompt(session, active.cookie, { responseRequired: false })
        publish()
        return true
    }
    function cancelCurrent() {
        const flow = backend ? backend.flow : null
        const active = session.active
        if (active) Dialog.settle(session, active.cookie, "cancelled")
        publish()
        if (flow && active && flow.cookie === active.cookie) flow.cancelAuthenticationRequest()
    }
    function select(id) {
        const flow = backend ? backend.flow : null
        const active = session.active
        if (!flow || !active || flow.cookie !== active.cookie) return false
        if (!Dialog.selectIdentity(session, active.cookie, id)) return false
        publish()
        const list = flow.identities || []
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && String(list[i].id) === String(id)) {
                flow.selectedIdentity = list[i]
                break
            }
        }
        return true
    }
    function invalidateInput() {
        if (!Dialog.invalidateInput(session)) return
        publish()
    }
    function releaseBackend() {
        const old = backend
        backend = null
        retireBackend = false
        registrationSettled = false
        session = Dialog.create()
        publish()
        if (old) Qt.callLater(() => old.destroy())
    }
    function stopAgent() {
        if (!backend) {
            session = Dialog.create()
            publish()
            return
        }
        if (backend.registered || registrationSettled) {
            registerTimer.stop()
            releaseBackend()
            return
        }
        retireBackend = true
        session = Dialog.create()
        publish()
    }
    function finishAgent(component) {
        if (!enabled || blockRegistration || phase === "off") return
        if (component.status !== Component.Ready) {
            phase = "missing"
            return
        }
        backend = component.createObject(root)
        if (!backend) {
            phase = "missing"
            return
        }
        phase = "connecting"
        registerTimer.restart()
    }
    function startAgent() {
        if (backend) {
            retireBackend = false
            if (backend.registered) {
                phase = "registered"
                return
            }
            phase = "connecting"
            if (!registrationSettled) registerTimer.restart()
            return
        }
        const component = Qt.createComponent("PolkitBackend.qml")
        if (component.status === Component.Error) {
            phase = "missing"
            return
        }
        if (component.status === Component.Loading) {
            component.statusChanged.connect(function() { root.finishAgent(component) })
            return
        }
        finishAgent(component)
    }
    function sync() {
        if (!enabled) {
            probeTimer.stop()
            stopAgent()
            phase = "off"
            return
        }
        if (!probeSettled) {
            phase = "probing"
            startProbe()
            return
        }
        if (blockRegistration) {
            phase = "refused"
            stopAgent()
            return
        }
        if (phase === "refused" && backend && !backend.registered) return
        if (phase === "missing") return
        startAgent()
    }

    // У QtObject нет default property: таймеры и процесс задаются свойствами.
    property Process probeProcess: Process {
        id: probe
        command: ["python3", root.scriptFile, "--probe"]
        stdout: SplitParser { onRead: data => root.ingestProbe(data) }
        onExited: code => { if (!root.probeSettled) root.ingestProbe("") }
    }
    property Timer probeClock: Timer {
        id: probeTimer
        interval: 3000
        onTriggered: if (!root.probeSettled) root.ingestProbe("")
    }
    property Timer registerClock: Timer {
        id: registerTimer
        interval: 2500
        onTriggered: {
            root.registrationSettled = true
            if (root.retireBackend || !root.enabled) {
                root.releaseBackend()
                if (!root.enabled) root.phase = "off"
                return
            }
            if (root.backend && root.backend.registered) root.phase = "registered"
            else if (root.enabled && !root.blockRegistration) root.phase = "refused"
        }
    }
    property Connections backendEvents: Connections {
        target: root.backend
        function onRegisteredChanged() {
            if (!root.backend) return
            if (root.backend.registered) {
                root.registrationSettled = true
                root.registerTimer.stop()
                if (root.retireBackend || !root.enabled || root.blockRegistration) {
                    root.phase = root.enabled && root.blockRegistration ? "refused" : "off"
                    root.releaseBackend()
                    return
                }
                root.phase = "registered"
                return
            }
            root.registrationSettled = true
            if (root.retireBackend || !root.enabled) {
                root.registerTimer.stop()
                root.releaseBackend()
                if (!root.enabled) root.phase = "off"
            }
        }
        function onRequestStarted() { root.adopt() }
        function onFlowChanged() { root.adopt() }
        function onPromptChanged() { root.syncPrompt() }
        function onSupplementaryChanged() { root.syncNote() }
        function onRequestFailed() { root.onFailed() }
        function onRequestSucceeded() { root.onSucceeded() }
        function onRequestCancelled() { root.onCancelled() }
    }
    onEnabledChanged: {
        if (enabled) probeSettled = false
        sync()
    }
    onPrimaryNameChanged: invalidateInput()
    Component.onCompleted: startProbe()
}
