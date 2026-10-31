pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Polkit

// Создание этого объекта регистрирует агент в polkit. Тесты его не загружают.
QtObject {
    id: root
    signal requestStarted()
    signal requestFailed()
    signal requestSucceeded()
    signal requestCancelled()
    signal flowChanged()
    signal promptChanged()
    signal supplementaryChanged()

    readonly property bool registered: agent.isRegistered
    readonly property bool active: agent.isActive
    readonly property var flow: agent.flow

    PolkitAgent {
        id: agent
        path: "/org/nayori/PolkitAgent"
        onAuthenticationRequestStarted: root.requestStarted()
        onFlowChanged: root.flowChanged()
    }
    Connections {
        target: agent.flow
        function onAuthenticationFailed() { root.requestFailed() }
        function onAuthenticationSucceeded() { root.requestSucceeded() }
        function onAuthenticationRequestCancelled() { root.requestCancelled() }
        function onIsResponseRequiredChanged() { root.promptChanged() }
        function onInputPromptChanged() { root.promptChanged() }
        function onResponseVisibleChanged() { root.promptChanged() }
        function onSupplementaryMessageChanged() { root.supplementaryChanged() }
        function onSupplementaryIsErrorChanged() { root.supplementaryChanged() }
    }
}
