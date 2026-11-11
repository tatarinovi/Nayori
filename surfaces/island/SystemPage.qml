pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property var tokens
    property var service: null
    property bool monitoring: false
    readonly property bool popupOpen: gpuPicker.popup.visible || networkPicker.popup.visible
    function closePopups() {
        gpuPicker.popup.close()
        networkPicker.popup.close()
    }
    onVisibleChanged: if (!visible) closePopups()
    onEnabledChanged: if (!enabled) closePopups()
    readonly property string consumerKey: "system-" + String(root)
    function subscribe() { if (service) service.consumer(consumerKey, monitoring) }
    onMonitoringChanged: subscribe()
    onServiceChanged: subscribe()
    Component.onCompleted: subscribe()
    Component.onDestruction: if (service) service.consumer(consumerKey, false)
    readonly property var snapshot: service ? service.data : ({})
    readonly property var cpu: snapshot.cpu || ({})
    readonly property var memory: snapshot.memory || ({})
    readonly property var gpus: snapshot.gpus || []
    readonly property var disks: (snapshot.disks || []).filter(d => (d.mount === "/" || String(d.mount || "").startsWith("/mnt/")) && known(d.total)).slice().sort((a, b) => a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount))
    readonly property var networks: snapshot.network || []
    property string gpuId: ""
    property string networkId: ""
    function selected(rows, id) { return rows.find(row => row.id === id) || rows[0] || ({}) }
    readonly property var availableGpus: gpus.filter(g => known(g.load) || known(g.used) || known(g.temperature))
    readonly property var gpu: selected(availableGpus, gpuId)
    readonly property var network: selected(networks, networkId)
    function history(key) { return service && service.histories[key] ? service.histories[key] : [] }
    function known(value) { return typeof value === "number" && isFinite(value) }
    function percent(value) { return known(value) ? Math.round(value) + "%" : "—" }
    function ratio(used, total) { return known(used) && known(total) && total > 0 ? used / total * 100 : null }
    function size(value) {
        if (!known(value)) return "—"
        const units = ["Б", "КиБ", "МиБ", "ГиБ", "ТиБ"]
        let i = 0
        while (value >= 1024 && i < units.length - 1) { value /= 1024; i++ }
        return value.toFixed(i > 0 ? 1 : 0) + " " + units[i]
    }
    function temperature(kind) {
        const rows = (snapshot.temperatures || []).filter(t => t.kind === kind)
        return rows.length ? Math.max(...rows.map(t => t.value)) : null
    }
    function degrees(value) { return known(value) ? Math.round(value) + " °C" : "—" }
    readonly property string uptime: {
        if (!known(snapshot.uptime)) return "—"
        const minutes = Math.floor(snapshot.uptime / 60)
        return Math.floor(minutes / 1440) + " д " + Math.floor(minutes / 60) % 24 + " ч " + minutes % 60 + " мин"
    }
    component Copy: IslandLabel { tokens: root.tokens; Layout.fillWidth: true; Layout.fillHeight: false; elide: Text.ElideRight; maximumLineCount: 1 }
    component Small: Copy { color: root.tokens.color.textMuted; font.pixelSize: 11; lineHeight: 1.1 }
    component Value: Copy { lineHeight: 1; font.pixelSize: root.compact ? 21 : 26; font.letterSpacing: -0.5 }
    component Card: IslandCard {
        Layout.fillWidth: true
        border.width: 1
        border.color: Qt.alpha(root.tokens.color.border, 0.32)
        tokens: root.tokens
    }
    readonly property bool compact: width < 600 || height < 430
    readonly property bool showCpu: known(cpu.load) || known(cpu.ghz) || !!cpu.model
    readonly property bool showGpu: known(gpu.load) || known(gpu.used) || known(gpu.temperature)
    readonly property bool showMemory: known(memory.total) && memory.total > 0
    readonly property bool showDisk: disks.length > 0
    readonly property bool showNetwork: networks.length > 0
    readonly property bool showState: !!service && (!!service.info.osName || !!service.info.kernel || known(snapshot.uptime))
    readonly property int topCards: Number(showCpu) + Number(showGpu) + Number(showMemory)
    readonly property int middleCards: Number(showDisk) + Number(showNetwork)
    readonly property bool showPower: !!service && service.profileAvailable
    readonly property int bottomCards: Number(showState) + Number(showPower)
    readonly property int rowCount: Number(topCards > 0) + Number(middleCards > 0) + Number(bottomCards > 0)
    readonly property real weight: (topCards ? 0.49 : 0) + (middleCards ? 0.51 : 0)
    readonly property real cardsHeight: Math.max(0, height - Math.max(0, rowCount - 1) * 10)
    readonly property real bottomHeight: bottomCards ? Math.min(cardsHeight, (compact ? 104 : 100) + (service && service.profileError ? 16 : 0)) : 0
    readonly property real telemetryHeight: Math.max(0, cardsHeight - bottomHeight)
    readonly property real diskRowBudget: Math.max(0, ((weight ? telemetryHeight * 0.51 / weight : 0) - (compact ? 16 : 20) - 26 - Math.max(1, disks.length) * (compact ? 3 : 5)) / Math.max(1, disks.length))
    readonly property bool hasTunnel: networks.some(n => n.tunnel && n.state !== "down")
    component Title: RowLayout {
        property string text: ""
        property string icon: "cpu"
        objectName: "systemCardTitle"
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.minimumHeight: 26
        Layout.preferredHeight: 26
        Layout.maximumHeight: 26
        spacing: 7
        SystemIcon { name: parent.icon; ink: root.tokens.color.textMuted; Layout.preferredWidth: 20; Layout.preferredHeight: 20; Layout.alignment: Qt.AlignVCenter }
        Copy {
            objectName: "systemCardTitleText"
            text: parent.text
            font.pixelSize: root.compact ? 12 : 14
            lineHeight: 1
            Layout.minimumHeight: 20; Layout.preferredHeight: 20; Layout.maximumHeight: 20
            Layout.alignment: Qt.AlignVCenter
            verticalAlignment: Text.AlignVCenter
            transform: Translate { y: 1 }
        }
    }
    component Badge: Rectangle {
        property string text: ""
        property real maximumWidth: 260
        implicitWidth: Math.min(badgeText.implicitWidth + (root.compact ? 12 : 16), maximumWidth)
        implicitHeight: 25
        radius: 12
        color: Qt.alpha(root.tokens.color.accent, 0.12)
        border.width: 1
        border.color: Qt.alpha(root.tokens.color.accent, 0.22)
        IslandLabel { id: badgeText; tokens: root.tokens; anchors.centerIn: parent; width: Math.max(0, parent.width - (root.compact ? 12 : 16)); text: parent.text; wrapMode: Text.NoWrap; elide: Text.ElideRight; maximumLineCount: 1; horizontalAlignment: Text.AlignHCenter; font.pixelSize: root.compact ? 10 : 11 }
    }
    component Meter: Rectangle {
        property var value: null
        Layout.fillWidth: true
        implicitHeight: 9
        radius: height / 2
        color: Qt.alpha(root.tokens.color.accent, 0.13)
        Rectangle { height: parent.height; radius: height / 2; width: root.known(parent.value) ? parent.width * Math.max(0, Math.min(100, parent.value)) / 100 : 0; color: root.tokens.color.accent }
    }
    component Picker: ComboBox {
        id: picker
        onVisibleChanged: if (!visible) popup.close()
        property var rows: []
        property string selection: ""
        signal chosen(string key)
        Layout.fillWidth: true
        implicitHeight: 26
        visible: rows.length > 1
        model: rows
        textRole: "id"
        currentIndex: Math.max(0, rows.findIndex(row => row.id === selection))
        Accessible.name: "Выбрать устройство"
        onActivated: chosen(rows[currentIndex].id)
        contentItem: Small { text: picker.displayText; verticalAlignment: Text.AlignVCenter; rightPadding: 20 }
        background: Rectangle { radius: 6; color: Qt.alpha(root.tokens.color.accent, 0.08); border.width: picker.visualFocus ? 1 : 0; border.color: root.tokens.color.accent }
    }
    IslandLabel {
        tokens: root.tokens
        anchors.centerIn: parent
        visible: root.rowCount === 0
        text: root.service && root.service.error ? root.service.error : root.service && root.service.ready ? "Нет доступных показателей" : "Читаем показатели…"
    }
    Item {
        anchors.fill: parent
        Column {
            objectName: "systemLayout"
            anchors.fill: parent
            spacing: 10
            GridLayout {
                width: parent.width
                height: root.weight ? root.telemetryHeight * 0.49 / root.weight : 0
                visible: root.topCards > 0
                columns: Math.max(1, root.topCards)
                columnSpacing: 10; rowSpacing: 10
                Card {
                    objectName: "systemCpuCard"
                    visible: root.showCpu
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: 3
                        Title { text: "Процессор"; icon: "cpu" }
                        RowLayout {
                            Layout.fillHeight: false
                            Value { visible: root.known(root.cpu.load); objectName: "systemCpuValue"; text: root.percent(root.cpu.load) }
                            Badge { visible: !root.compact && root.known(root.temperature("cpu")); text: root.degrees(root.temperature("cpu")) }
                        }
                        Small { visible: root.known(root.cpu.ghz) || !!root.cpu.cores || !!root.cpu.threads; text: [(root.known(root.cpu.ghz) ? root.cpu.ghz.toFixed(2) + " ГГц" : ""), (root.cpu.cores ? root.cpu.cores + " ядер" : ""), (root.cpu.threads ? root.cpu.threads + " потоков" : "")].filter(v => !!v).join(" · ") }
                        Small { visible: !root.compact && !!root.cpu.model; text: root.cpu.model || "Модель недоступна"; ToolTip.visible: cpuHover.hovered; ToolTip.text: text; HoverHandler { id: cpuHover } }
                        SystemGraph { id: metricGraph1; visible: points.some(p => root.known(p.v)); Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 18; points: root.history("cpu"); accent: root.tokens.color.accent }
                        Item { visible: !metricGraph1.visible; Layout.fillHeight: true; Layout.minimumHeight: 0 }
                    }
                }
                Card {
                    objectName: "systemGpuCard"
                    visible: root.showGpu
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: 3
                        RowLayout {
                            Layout.fillHeight: false; Title { text: "Видеокарта"; icon: "gpu" } Picker { id: gpuPicker; objectName: "systemGpuPicker"; rows: root.availableGpus; selection: root.gpu.id || ""; onChosen: key => root.gpuId = key } }
                        RowLayout {
                            Layout.fillHeight: false; Value { visible: root.known(root.gpu.load); text: root.percent(root.gpu.load) } Badge { visible: !root.compact && root.known(root.gpu.temperature); text: root.degrees(root.gpu.temperature) } }
                        Small { visible: !!root.gpu.model; text: root.gpu.model || "GPU не обнаружена"; ToolTip.visible: gpuHover.hovered; ToolTip.text: text; HoverHandler { id: gpuHover } }
                        Small { visible: !root.compact && root.gpus.length < 2 && root.known(root.gpu.used) && root.known(root.gpu.total); text: "VRAM  " + root.size(root.gpu.used) + " / " + root.size(root.gpu.total) }
                        SystemGraph { id: metricGraph2; visible: points.some(p => root.known(p.v)); Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 18; points: root.history("gpu:" + root.gpu.id); accent: root.tokens.color.accent }
                        Item { visible: !metricGraph2.visible; Layout.fillHeight: true; Layout.minimumHeight: 0 }
                    }
                }
                Card {
                    objectName: "systemMemoryCard"
                    visible: root.showMemory
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: 8
                        Title { text: "Память"; icon: "memory" }
                        Value { visible: root.known(root.memory.used); text: root.size(root.memory.used); font.pixelSize: root.compact ? 18 : 24 }
                        RowLayout {
                            Layout.fillHeight: false; Small { text: "из " + root.size(root.memory.total) } Badge { visible: !root.compact && root.known(root.ratio(root.memory.used, root.memory.total)); text: root.percent(root.ratio(root.memory.used, root.memory.total)) } }
                        Meter { visible: root.known(value); value: root.ratio(root.memory.used, root.memory.total) }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
            GridLayout {
                width: parent.width
                height: root.weight ? root.telemetryHeight * 0.51 / root.weight : 0
                visible: root.middleCards > 0
                columns: Math.max(1, root.middleCards)
                columnSpacing: 10; rowSpacing: 10
                Card {
                    objectName: "systemDiskCard"
                    visible: root.showDisk
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: root.compact ? 3 : 5
                        Title { text: "Диски"; icon: "disk" }
                        Repeater {
                            model: root.disks
                            delegate: Item {
                                id: diskRow
                                required property var modelData
                                required property int index
                                objectName: "systemDiskMount" + index
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 0
                                readonly property string capacity: (root.known(modelData.used) ? root.size(modelData.used) + " / " : "Всего ") + root.size(modelData.total)
                                readonly property string speed: (root.known(modelData.read) ? "↓ " + root.size(modelData.read) + "/с" : "") + (root.known(modelData.write) ? "    ↑ " + root.size(modelData.write) + "/с" : "")
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 3
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: false
                                        Copy {
                                            objectName: "systemDiskMountLabel" + diskRow.index
                                            text: diskRow.modelData.mount
                                            font.pixelSize: 12
                                            ToolTip.visible: mountHover.hovered
                                            ToolTip.text: text + " · " + diskRow.modelData.source + "\n" + diskRow.capacity + (root.known(diskRow.modelData.available) ? " · свободно " + root.size(diskRow.modelData.available) : "") + (diskRow.speed ? "\n" + diskRow.speed : "")
                                            HoverHandler { id: mountHover }
                                        }
                                        Small {
                                            Layout.fillWidth: false
                                            Layout.maximumWidth: diskRow.width * 0.75
                                            text: diskRow.capacity + (root.known(root.ratio(diskRow.modelData.used, diskRow.modelData.total)) ? " · " + root.percent(root.ratio(diskRow.modelData.used, diskRow.modelData.total)) : "")
                                        }
                                    }
                                    Meter {
                                        visible: root.diskRowBudget >= 34 && root.known(value)
                                        implicitHeight: 6
                                        value: root.ratio(diskRow.modelData.used, diskRow.modelData.total)
                                    }
                                    Small { visible: root.diskRowBudget >= 54 && !!diskRow.speed; text: diskRow.speed }
                                    SystemGraph {
                                        visible: root.diskRowBudget >= 90 && points.some(p => root.known(p.v))
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
                                        ceiling: 0
                                        points: root.history("disk:" + diskRow.modelData.id)
                                        accent: root.tokens.color.accent
                                    }
                                    Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                                }
                            }
                        }
                    }
                }
                Card {
                    objectName: "systemNetworkCard"
                    visible: root.showNetwork
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: root.compact ? 3 : 5
                        RowLayout {
                            Layout.fillHeight: false; Title { text: "Сеть"; icon: "network" } Small { visible: root.networks.length < 2; text: root.network.id || "Нет интерфейсов"; horizontalAlignment: Text.AlignRight } Picker { id: networkPicker; objectName: "systemNetworkPicker"; rows: root.networks; selection: root.network.id || ""; onChosen: key => root.networkId = key } }
                        Small { visible: root.known(root.network.down) || root.known(root.network.up); text: (root.known(root.network.down) ? "↓ " + root.size(root.network.down) + "/с" : "") + (root.known(root.network.up) ? "    ↑ " + root.size(root.network.up) + "/с" : "") }
                        SystemGraph { id: metricGraph4; visible: points.some(p => root.known(p.v)); Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 18; ceiling: 0; points: root.history("net:" + root.network.id); accent: root.tokens.color.accent }
                        Item { visible: !metricGraph4.visible; Layout.fillHeight: true; Layout.minimumHeight: 0 }
                        Flow {
                            Layout.fillWidth: true; spacing: 4
                            Badge { visible: !!root.service && root.service.networkStatus.wifiLabel !== "—"; maximumWidth: Math.max(40, parent.width); text: root.compact ? "Wi-Fi " + (root.service && root.service.networkStatus.wifiConnected ? "●" : root.service && root.service.networkStatus.wifiLabel !== "—" ? "○" : "?") : "Wi-Fi · " + (root.service ? root.service.networkStatus.wifiLabel : "—"); ToolTip.visible: wifiHover.hovered; ToolTip.text: root.service ? root.service.networkStatus.wifiLabel : "—"; HoverHandler { id: wifiHover } }
                            Badge { visible: !!root.service && root.service.networkStatus.ethernetLabel !== "—"; maximumWidth: Math.max(40, parent.width); text: root.compact ? "LAN " + (root.service && root.service.networkStatus.ethernetConnected ? "●" : root.service && root.service.networkStatus.ethernetLabel !== "—" ? "○" : "?") : "Ethernet · " + (root.service ? root.service.networkStatus.ethernetLabel : "—"); ToolTip.visible: ethernetHover.hovered; ToolTip.text: root.service ? root.service.networkStatus.ethernetLabel : "—"; HoverHandler { id: ethernetHover } }
                            Badge { visible: root.hasTunnel; text: root.networks.some(n => n.tunnel && n.state !== "down") ? (root.compact ? "VPN ◉" : "VPN · туннель") : (root.compact ? "VPN ?" : "VPN · неизвестно") }
                        }
                    }
                }
            }
            GridLayout {
                width: parent.width
                height: root.bottomHeight
                visible: root.bottomCards > 0
                columns: Math.max(1, root.bottomCards)
                columnSpacing: 10; rowSpacing: 10
                Card {
                    objectName: "systemStateCard"
                    visible: root.showState
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: 3
                        RowLayout {
                            Layout.fillHeight: false
                            Title { text: "Состояние"; icon: "state" }
                            Badge {
                                objectName: "systemUptime"
                                visible: !root.compact && root.known(root.snapshot.uptime)
                                text: "◷  " + root.uptime
                            }
                        }
                        Badge {
                            objectName: "systemUptimeCompact"
                            Layout.fillWidth: true
                            visible: root.compact && root.known(root.snapshot.uptime)
                            text: "◷  " + root.uptime
                        }
                        Small { visible: !!root.service && !!root.service.info.osName; text: root.service ? root.service.info.osName || "Дистрибутив недоступен" : "—" }
                        Small { visible: !root.compact && !!root.service && !!root.service.info.kernel; text: root.service && root.service.info.kernel ? "Linux " + root.service.info.kernel : "Ядро недоступно" }
                        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                    }
                }
                Card {
                    objectName: "systemPowerCard"
                    visible: root.showPower
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: root.compact ? 8 : 10; spacing: 8
                        Title { text: "Питание"; icon: "power" }
                        RowLayout {
                            Layout.fillHeight: false
                            Layout.fillWidth: true; spacing: 6
                            uniformCellSizes: true
                            visible: !!root.service && root.service.profileAvailable
                            Repeater {
                                model: [{key:"power-saver",title:"Экономия",icon:"eco"}, {key:"balanced",title:"Баланс",icon:"balanced"}, {key:"performance",title:"Максимум",icon:"performance"}]
                                delegate: IslandAction {
                                    id: profileButton
                                    required property var modelData
                                    objectName: "systemProfile-" + modelData.key
                                    tokens: root.tokens
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.preferredWidth: 1
                                    implicitWidth: 0
                                    implicitHeight: root.compact ? 40 : 44
                                    padding: 8
                                    enabled: !!root.service && root.service.profileAvailable && (modelData.key !== "performance" || root.service.hasPerformanceProfile)
                                    text: modelData.title
                                    Accessible.name: "Профиль питания: " + text
                                    Accessible.role: Accessible.RadioButton
                                    Accessible.checked: !!root.service && root.service.profile === modelData.key
                                    onClicked: root.service.chooseProfile(modelData.key)
                                    ToolTip.visible: hovered
                                    ToolTip.text: root.service && root.service.profileError ? root.service.profileError : text
                                    background: Rectangle {
                                        radius: 8
                                        color: profileButton.Accessible.checked ? Qt.alpha(root.tokens.color.accent, 0.22) : Qt.alpha(root.tokens.color.accent, profileButton.hovered ? 0.14 : 0.05)
                                        border.width: 1
                                        border.color: profileButton.visualFocus || profileButton.Accessible.checked ? root.tokens.color.accent : Qt.alpha(root.tokens.color.border, 0.25)
                                        opacity: profileButton.enabled ? 1 : 0.4
                                    }
                                    contentItem: Item {
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 5
                                            SystemIcon {
                                                name: profileButton.modelData.icon
                                                width: 18; height: 18
                                                anchors.verticalCenter: parent.verticalCenter
                                                ink: profileButton.enabled ? root.tokens.color.accent : root.tokens.color.textMuted
                                            }
                                            IslandLabel {
                                                tokens: root.tokens
                                                visible: !root.compact
                                                text: profileButton.text
                                                font.pixelSize: 11
                                                wrapMode: Text.NoWrap
                                                anchors.verticalCenter: parent.verticalCenter
                                                opacity: profileButton.enabled ? 1 : 0.4
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Small { visible: !!root.service && !!root.service.profileError; text: root.service ? root.service.profileError : ""; font.pixelSize: 10 }
                        Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                    }
                }
            }
        }
    }
}
