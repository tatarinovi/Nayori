pragma ComponentBehavior: Bound

import QtQuick

Column {
    id: root
    required property var tokens
    property var service: null
    signal closeRequested()
    spacing: 10
    readonly property var windows: service ? service.windows : []

    component Label: Text {
        color: root.tokens.color.text
        font.family: root.tokens.type.body.family
        font.pixelSize: root.tokens.type.body.size
        font.weight: root.tokens.type.body.weight
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }

    component Symbol: Canvas {
        id: symbol
        property string kind: "terminal"
        property color ink: root.tokens.color.accent
        onKindChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const c = getContext("2d")
            c.reset()
            c.strokeStyle = ink
            c.lineWidth = 1.8
            c.lineCap = "round"
            c.lineJoin = "round"
            c.beginPath()
            if (kind === "terminal") {
                c.moveTo(5, 6); c.lineTo(9, 10); c.lineTo(5, 14)
                c.moveTo(11, 14); c.lineTo(15, 14)
            } else if (kind === "clock") {
                c.arc(10, 10, 7, 0, Math.PI * 2)
                c.moveTo(10, 5); c.lineTo(10, 10); c.lineTo(13, 12)
            } else {
                c.roundedRect(3, 5, 14, 12, 2, 2)
                c.moveTo(3, 8); c.lineTo(17, 8)
                c.moveTo(7, 3); c.lineTo(7, 6)
                c.moveTo(13, 3); c.lineTo(13, 6)
            }
            c.stroke()
        }
    }

    Item {
        width: parent.width
        height: 60
        Rectangle {
            width: 40; height: 40; radius: root.tokens.radius.small
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            color: root.tokens.color.accentSoft
            Symbol { anchors.centerIn: parent; width: 20; height: 20; ink: root.tokens.color.accentSoftText }
        }
        Label {
            x: 50; anchors.verticalCenter: parent.verticalCenter
            text: "Codex"
            font.family: root.tokens.type.display.family
            font.pixelSize: root.tokens.type.display.size
        }
        StatusButton {
            objectName: "codex-refresh"
            width: 32; height: 32
            anchors.right: closeButton.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            tokens: root.tokens
            iconName: "refresh"
            hint: root.service && root.service.busy ? "Обновление…" : "Обновить лимиты"
            enabled: !!root.service && root.service.enabled && !root.service.busy
            onClicked: root.service.refresh()
        }
        StatusButton {
            id: closeButton
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32
            tokens: root.tokens
            text: "×"
            hint: "Закрыть"
            onClicked: root.closeRequested()
        }
    }
    Label {
        visible: root.windows.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        color: root.tokens.color.textMuted
        text: root.service && root.service.data.status === "missing" ? "Установите AI Usage Bar" : root.service && root.service.data.status === "loading" ? "Загрузка лимитов…" : "Не удалось получить лимиты Codex через AI Usage Bar"
    }
    Repeater {
        model: root.windows
        delegate: Rectangle {
            id: card
            required property var modelData
            required property int index
            width: root.width
            height: 90
            radius: root.tokens.radius.medium
            color: root.tokens.color.surface
            border.width: 1
            border.color: root.tokens.color.border
            Rectangle {
                x: 12; y: 14; width: 36; height: 36
                radius: root.tokens.radius.small
                color: root.tokens.material.panel
                Symbol { anchors.centerIn: parent; width: 20; height: 20; kind: card.index === 0 ? "clock" : "calendar" }
            }
            Label {
                x: 58; y: 12; width: parent.width - 124
                text: root.service.label(card.modelData)
                font.bold: true
                elide: Text.ElideRight
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 12; y: 10
                width: 58; height: 27; radius: 13.5
                color: root.tokens.color.accentSoft
                Label { anchors.centerIn: parent; text: card.modelData.left + "%"; color: root.tokens.color.accentSoftText; font.bold: true }
            }
            Label {
                x: 58; y: 36; width: parent.width - 70
                color: root.tokens.color.textMuted
                font.pixelSize: root.tokens.type.small.size
                elide: Text.ElideRight
                text: card.modelData.resetText ? "Сброс через " + card.modelData.resetText : "Время сброса неизвестно"
            }
            Rectangle {
                x: 58; y: 68; width: parent.width - 70; height: 6; radius: 3
                color: root.tokens.color.border
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(100, card.modelData.left)) / 100
                    height: parent.height; radius: parent.radius
                    color: root.tokens.color.accent
                }
            }
        }
    }
}
