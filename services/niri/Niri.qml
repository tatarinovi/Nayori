pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Официальный IPC niri 26.04: путь только из NIRI_SOCKET.
// Одно соединение пишет "EventStream" и читает события.
// FocusWorkspace и FocusWindow уходят отдельным коротким соединением и только из функций клика.
QtObject {
    id: root

    property bool _available: false
    property string _error: ""
    property string _focusedOutput: ""
    property var _keyboardLayouts: []
    property int _keyboardIndex: 0
    readonly property string keyboardLayout: _keyboardLayouts[_keyboardIndex] || ""
    property var _workspaces: []
    property var _windows: []

    readonly property bool available: _available
    readonly property string error: _error
    readonly property string focusedOutput: _focusedOutput
    readonly property var workspaces: _workspaces
    readonly property var windows: _windows
    // First ConfigLoaded on a connection is the catch-up for the running config.
    // configReloads counts only later successful loads. Overview uses that to
    // avoid mapping a backdrop layer before this process has actually loaded it.
    property bool _configSeen: false
    property bool _configFailed: false
    property int _configReloads: 0
    readonly property bool configFailed: _configFailed
    readonly property int configReloads: _configReloads

    property bool _awaitingHandshake: false
    property bool _streamLive: false
    property bool _dropping: false
    property int _streamEpoch: 0

    property var _actionQueue: []
    property bool _actionLive: false
    property string _actionPayload: ""
    property bool _droppingAction: false

    function socketPath() {
        try {
            var value = Quickshell.env("NIRI_SOCKET")
            if (value === undefined || value === null)
                return ""
            return String(value).trim()
        } catch (e) {
            return ""
        }
    }

    function isId(value) {
        return typeof value === "number" && isFinite(value) && Math.floor(value) === value
    }

    function asString(value) {
        if (value === undefined || value === null)
            return ""
        return String(value)
    }

    function findWorkspace(id) {
        var list = _workspaces
        for (var i = 0; i < list.length; ++i) {
            if (list[i] && list[i].id === id)
                return list[i]
        }
        return null
    }

    function findWindow(id) {
        var list = _windows
        for (var i = 0; i < list.length; ++i) {
            if (list[i] && list[i].id === id)
                return list[i]
        }
        return null
    }

    function outputForWorkspace(workspaceId) {
        var workspace = findWorkspace(workspaceId)
        if (!workspace)
            return ""
        return asString(workspace.output)
    }

    function workspaceObject(id, idx, name, output, active, focused, urgent) {
        return {
            id: id,
            idx: idx,
            name: name,
            output: output,
            active: active,
            focused: focused,
            urgent: urgent
        }
    }

    function windowObject(id, appId, title, workspaceId, output, focused, layout, floating, pid) {
        var geometry = mapGeometry(layout)
        return {
            id: id,
            appId: appId,
            pid: isId(pid) ? pid : null,
            title: title,
            workspaceId: workspaceId,
            output: output,
            focused: focused,
            floating: floating === true,
            layout: layout || null,
            geometryKnown: geometry !== null,
            geometry: geometry
        }
    }

    // Niri 26.04 only exposes viewport positions for some window types.
    // In particular, tiled positions are null: never invent a viewport offset.
    // Rectangles include compositor decorations and use workspace-view logical pixels.
    function mapGeometry(layout) {
        if (!layout)
            return null
        var pos = layout.tile_pos_in_workspace_view
        var size = layout.tile_size
        if (!Array.isArray(pos) || !Array.isArray(size) || pos.length !== 2 || size.length !== 2)
            return null
        for (var i = 0; i < 2; ++i) {
            if (typeof pos[i] !== "number" || !isFinite(pos[i])
                || typeof size[i] !== "number" || !isFinite(size[i]) || size[i] <= 0)
                return null
        }
        return { x: pos[0], y: pos[1], width: size[0], height: size[1] }
    }

    function mapWorkspace(raw) {
        if (!raw || !isId(raw.id) || !isId(raw.idx))
            return null
        return workspaceObject(
            raw.id,
            raw.idx,
            asString(raw.name),
            asString(raw.output),
            raw.is_active === true,
            raw.is_focused === true,
            raw.is_urgent === true
        )
    }

    function mapWindow(raw) {
        if (!raw || !isId(raw.id))
            return null
        var workspaceId = isId(raw.workspace_id) ? raw.workspace_id : 0
        return windowObject(
            raw.id,
            asString(raw.app_id),
            asString(raw.title),
            workspaceId,
            outputForWorkspace(workspaceId),
            raw.is_focused === true,
            raw.layout,
            raw.is_floating === true,
            raw.pid
        )
    }

    function publishWorkspaces(list, epoch) {
        if (epoch !== _streamEpoch)
            return
        var focusedOutput = ""
        for (var i = 0; i < list.length; ++i) {
            if (list[i].focused) {
                focusedOutput = asString(list[i].output)
                break
            }
        }
        _focusedOutput = focusedOutput
        _workspaces = list
        refreshWindowOutputs(epoch)
    }

    function refreshWindowOutputs(epoch) {
        if (epoch !== _streamEpoch)
            return
        var current = _windows
        if (!current || current.length === 0)
            return
        var next = []
        var changed = false
        for (var i = 0; i < current.length; ++i) {
            var window = current[i]
            var output = outputForWorkspace(window.workspaceId)
            if (output !== window.output) {
                next.push(windowObject(window.id, window.appId, window.title, window.workspaceId, output, window.focused, window.layout, window.floating, window.pid))
                changed = true
            } else {
                next.push(window)
            }
        }
        if (changed && epoch === _streamEpoch)
            _windows = next
    }

    function openStream() {
        try {
            if (_dropping || streamSocket.connected || _awaitingHandshake || _streamLive)
                return
            var path = socketPath()
            if (path.length === 0) {
                dropStream("NIRI_SOCKET не задан")
                return
            }
            _awaitingHandshake = true
            handshakeTimer.restart()
            streamSocket.path = path
            streamSocket.connected = true
        } catch (e) {
            dropStream("сокет niri недоступен")
        }
    }

    function dropStream(message) {
        if (_dropping)
            return
        _dropping = true
        _streamEpoch += 1
        _awaitingHandshake = false
        _streamLive = false
        handshakeTimer.stop()
        _available = false
        _error = message.length > 0 ? message : "сокет niri недоступен"
        _focusedOutput = ""
        _keyboardLayouts = []
        _keyboardIndex = 0
        _workspaces = []
        _windows = []
        _actionQueue = []
        _configSeen = false
        try {
            if (streamSocket.connected)
                streamSocket.connected = false
        } catch (e) {
        }
        _dropping = false
        if (!retryTimer.running)
            retryTimer.start()
    }

    function onStreamConnectedChanged() {
        if (_dropping)
            return
        try {
            if (!streamSocket.connected) {
                if (_awaitingHandshake || _streamLive)
                    dropStream("сокет niri закрыт")
                return
            }
            if (!_awaitingHandshake) {
                dropStream("сокет niri недоступен")
                return
            }
            streamSocket.write("\"EventStream\"\n")
            streamSocket.flush()
        } catch (e) {
            dropStream("сокет niri недоступен")
        }
    }

    function onStreamError() {
        if (_dropping)
            return
        if (!_awaitingHandshake && !_streamLive)
            return
        dropStream("сокет niri недоступен")
    }

    function onHandshakeTimeout() {
        if (_streamLive || _dropping)
            return
        dropStream("рукопожатие niri не пришло")
    }

    function onStreamLine(data) {
        var epoch = _streamEpoch
        if (!_awaitingHandshake && !_streamLive)
            return
        try {
            var text = String(data).trim()
            if (text.length === 0)
                return
            var msg = JSON.parse(text)
            if (epoch !== _streamEpoch)
                return
            if (!msg || typeof msg !== "object" || Array.isArray(msg)) {
                dropStream("неожиданное сообщение niri")
                return
            }
            if (_awaitingHandshake) {
                if (msg.Ok === "Handled") {
                    _awaitingHandshake = false
                    _streamLive = true
                    handshakeTimer.stop()
                    retryTimer.stop()
                    _available = true
                    _error = ""
                    return
                }
                if (typeof msg.Err === "string")
                    dropStream(msg.Err.length > 0 ? msg.Err : "неожиданный ответ niri")
                else
                    dropStream("неожиданный ответ niri")
                return
            }
            applyEvent(msg, epoch)
        } catch (e) {
            if (epoch === _streamEpoch)
                dropStream("неожиданное сообщение niri")
        }
    }

    // Неизвестные события оставляем: niri добавляет варианты в следующих выпусках.
    // Состояние меняют только перечисленные ниже.
    function applyEvent(msg, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (msg.KeyboardLayoutsChanged !== undefined) {
            const layouts = msg.KeyboardLayoutsChanged.keyboard_layouts
            if (layouts && Array.isArray(layouts.names) && Number.isInteger(layouts.current_idx)) {
                _keyboardLayouts = layouts.names
                _keyboardIndex = layouts.current_idx
            }
            return
        }
        if (msg.KeyboardLayoutSwitched !== undefined) {
            if (Number.isInteger(msg.KeyboardLayoutSwitched.idx)) _keyboardIndex = msg.KeyboardLayoutSwitched.idx
            return
        }
        if (msg.WorkspacesChanged !== undefined) {
            applyWorkspaces(msg.WorkspacesChanged, epoch)
            return
        }
        if (msg.WorkspaceUrgencyChanged !== undefined) {
            applyWorkspaceUrgency(msg.WorkspaceUrgencyChanged, epoch)
            return
        }
        if (msg.WorkspaceActivated !== undefined) {
            applyWorkspaceActivated(msg.WorkspaceActivated, epoch)
            return
        }
        if (msg.WindowsChanged !== undefined) {
            applyWindows(msg.WindowsChanged, epoch)
            return
        }
        if (msg.WindowOpenedOrChanged !== undefined) {
            applyWindowOpenedOrChanged(msg.WindowOpenedOrChanged, epoch)
            return
        }
        if (msg.WindowClosed !== undefined) {
            applyWindowClosed(msg.WindowClosed, epoch)
            return
        }
        if (msg.WindowLayoutsChanged !== undefined) {
            applyWindowLayoutsChanged(msg.WindowLayoutsChanged, epoch)
            return
        }
        if (msg.WindowFocusChanged !== undefined) {
            applyWindowFocusChanged(msg.WindowFocusChanged, epoch)
            return
        }
        if (msg.ConfigLoaded !== undefined) {
            applyConfigLoaded(msg.ConfigLoaded, epoch)
            return
        }
    }

    function applyConfigLoaded(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || typeof body.failed !== "boolean")
            return
        _configFailed = body.failed
        if (!_configSeen) {
            _configSeen = true
            return
        }
        if (!body.failed)
            _configReloads += 1
    }

    function applyWorkspaces(body, epoch) {
        if (!body || !Array.isArray(body.workspaces)) {
            dropStream("неожиданное событие niri")
            return
        }
        var list = []
        for (var i = 0; i < body.workspaces.length; ++i) {
            var mapped = mapWorkspace(body.workspaces[i])
            if (mapped)
                list.push(mapped)
        }
        publishWorkspaces(list, epoch)
    }

    function applyWorkspaceUrgency(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || !isId(body.id) || typeof body.urgent !== "boolean")
            return
        var current = _workspaces
        var next = []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            var workspace = current[i]
            if (workspace.id === body.id) {
                found = true
                next.push(workspaceObject(
                    workspace.id, workspace.idx, workspace.name, workspace.output,
                    workspace.active, workspace.focused, body.urgent
                ))
            } else {
                next.push(workspace)
            }
        }
        if (found)
            publishWorkspaces(next, epoch)
    }

    function applyWorkspaceActivated(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || !isId(body.id) || typeof body.focused !== "boolean")
            return
        var current = _workspaces
        var target = null
        for (var i = 0; i < current.length; ++i) {
            if (current[i].id === body.id) {
                target = current[i]
                break
            }
        }
        if (!target)
            return
        var output = target.output
        var next = []
        for (var j = 0; j < current.length; ++j) {
            var workspace = current[j]
            var active = workspace.output === output ? workspace.id === body.id : workspace.active
            var focused = body.focused ? workspace.id === body.id : workspace.focused
            if (active !== workspace.active || focused !== workspace.focused) {
                next.push(workspaceObject(
                    workspace.id, workspace.idx, workspace.name, workspace.output,
                    active, focused, workspace.urgent
                ))
            } else {
                next.push(workspace)
            }
        }
        publishWorkspaces(next, epoch)
    }

    function applyWindows(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || !Array.isArray(body.windows)) {
            dropStream("неожиданное событие niri")
            return
        }
        var list = []
        for (var i = 0; i < body.windows.length; ++i) {
            var mapped = mapWindow(body.windows[i])
            if (mapped)
                list.push(mapped)
        }
        if (epoch === _streamEpoch)
            _windows = list
    }

    function applyWindowOpenedOrChanged(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body)
            return
        var window = mapWindow(body.window)
        if (!window)
            return
        var current = _windows
        var next = []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            var existing = current[i]
            if (existing.id === window.id) {
                found = true
                next.push(window)
            } else if (window.focused && existing.focused) {
                next.push(windowObject(
                    existing.id, existing.appId, existing.title, existing.workspaceId,
                    existing.output, false, existing.layout, existing.floating, existing.pid
                ))
            } else {
                next.push(existing)
            }
        }
        if (!found)
            next.push(window)
        if (epoch === _streamEpoch)
            _windows = next
    }

    function applyWindowClosed(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || !isId(body.id))
            return
        var current = _windows
        var next = []
        var found = false
        for (var i = 0; i < current.length; ++i) {
            if (current[i].id === body.id) {
                found = true
                continue
            }
            next.push(current[i])
        }
        if (found && epoch === _streamEpoch)
            _windows = next
    }

    function applyWindowLayoutsChanged(body, epoch) {
        if (epoch !== _streamEpoch || !body || !Array.isArray(body.changes))
            return
        var layouts = {}
        for (var i = 0; i < body.changes.length; ++i) {
            var change = body.changes[i]
            if (Array.isArray(change) && change.length === 2 && isId(change[0])
                && change[1] && typeof change[1] === "object")
                layouts[change[0]] = change[1]
        }
        var next = []
        var changed = false
        for (var j = 0; j < _windows.length; ++j) {
            var window = _windows[j]
            if (Object.prototype.hasOwnProperty.call(layouts, window.id)) {
                next.push(windowObject(window.id, window.appId, window.title,
                    window.workspaceId, window.output, window.focused,
                    layouts[window.id], window.floating, window.pid))
                changed = true
            } else {
                next.push(window)
            }
        }
        if (changed && epoch === _streamEpoch)
            _windows = next
    }

    function applyWindowFocusChanged(body, epoch) {
        if (epoch !== _streamEpoch)
            return
        if (!body || !("id" in body))
            return
        var id = body.id
        if (id !== null && !isId(id))
            return
        var current = _windows
        var next = []
        for (var i = 0; i < current.length; ++i) {
            var window = current[i]
            var focused = id !== null && window.id === id
            if (focused !== window.focused) {
                next.push(windowObject(
                    window.id, window.appId, window.title, window.workspaceId,
                    window.output, focused, window.layout, window.floating, window.pid
                ))
            } else {
                next.push(window)
            }
        }
        if (epoch === _streamEpoch)
            _windows = next
    }

    function focusWorkspace(id) {
        try {
            if (!_available || !isId(id) || !findWorkspace(id))
                return
            enqueueAction(JSON.stringify({
                Action: {
                    FocusWorkspace: {
                        reference: { Id: id }
                    }
                }
            }))
        } catch (e) {
        }
    }

    function focusWindow(id) {
        try {
            if (!_available || !isId(id) || !findWindow(id))
                return
            enqueueAction(JSON.stringify({
                Action: {
                    FocusWindow: { id: id }
                }
            }))
        } catch (e) {
        }
    }

    // path остаётся null: niri 26.04 перечитывает текущий файл, а не подменяет его.
    // Справка действия: «Reload the config file». Это не quit и не перезапуск сессии.
    function reloadConfig() {
        try {
            if (!_available)
                return false
            enqueueAction(JSON.stringify({
                Action: {
                    LoadConfigFile: { path: null }
                }
            }))
            return true
        } catch (e) {
            return false
        }
    }

    function enqueueAction(payload) {
        if (!_available)
            return
        var queue = _actionQueue.slice()
        queue.push(payload)
        _actionQueue = queue
        pumpAction()
    }

    function pumpAction() {
        try {
            if (_actionLive || _droppingAction)
                return
            if (!_available || _actionQueue.length === 0) {
                if (!_available)
                    _actionQueue = []
                return
            }
            if (actionSocket.connected)
                return
            var path = socketPath()
            if (path.length === 0) {
                _actionQueue = []
                return
            }
            var queue = _actionQueue.slice()
            var payload = queue.shift()
            _actionQueue = queue
            _actionPayload = payload
            _actionLive = true
            actionTimer.restart()
            actionSocket.path = path
            actionSocket.connected = true
        } catch (e) {
            failAction()
        }
    }

    function onActionConnectedChanged() {
        if (_droppingAction)
            return
        try {
            if (!actionSocket.connected) {
                var wasLive = _actionLive
                actionTimer.stop()
                _actionLive = false
                _actionPayload = ""
                if (wasLive || _actionQueue.length > 0)
                    Qt.callLater(function () { root.pumpAction() })
                return
            }
            if (!_actionLive)
                return
            actionSocket.write(_actionPayload + "\n")
            actionSocket.flush()
        } catch (e) {
            failAction()
        }
    }

    function onActionReply(data) {
        if (!_actionLive)
            return
        try {
            var text = String(data).trim()
            if (text.length === 0)
                return
            JSON.parse(text)
        } catch (e) {
        }
        closeActionSocket()
    }

    function onActionError() {
        // Ошибка после уже принятого ответа приходит от нашего же закрытия сокета.
        if (_droppingAction || !_actionLive)
            return
        failAction()
    }

    function closeActionSocket() {
        actionTimer.stop()
        if (!actionSocket.connected) {
            _actionLive = false
            _actionPayload = ""
            Qt.callLater(function () { root.pumpAction() })
            return
        }
        _droppingAction = true
        _actionLive = false
        _actionPayload = ""
        try {
            actionSocket.connected = false
        } catch (e) {
        }
        _droppingAction = false
        if (!actionSocket.connected)
            Qt.callLater(function () { root.pumpAction() })
    }

    function failAction() {
        actionTimer.stop()
        _actionQueue = []
        _actionPayload = ""
        _actionLive = false
        _droppingAction = true
        try {
            if (actionSocket.connected)
                actionSocket.connected = false
        } catch (e) {
        }
        _droppingAction = false
    }

    Component.onCompleted: openStream()

    // У QtObject нет свойства по умолчанию, поэтому сокеты и таймеры лежат в свойствах.
    property Timer retryTimer: Timer {
        interval: 1000
        repeat: false
        onTriggered: root.openStream()
    }

    property Timer handshakeTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.onHandshakeTimeout()
    }

    property Timer actionTimer: Timer {
        interval: 2000
        repeat: false
        onTriggered: root.failAction()
    }

    property Socket streamSocket: Socket {
        connected: false
        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (data) { root.onStreamLine(data) }
        }
        onConnectedChanged: root.onStreamConnectedChanged()
        onError: root.onStreamError()
    }

    property Socket actionSocket: Socket {
        connected: false
        parser: SplitParser {
            splitMarker: "\n"
            onRead: function (data) { root.onActionReply(data) }
        }
        onConnectedChanged: root.onActionConnectedChanged()
        onError: root.onActionError()
    }
}
