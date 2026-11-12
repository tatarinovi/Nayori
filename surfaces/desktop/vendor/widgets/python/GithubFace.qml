import "."
import "../BridgeContext.js" as BridgeContext
// Modified for Nayori, 2026-11-12: imports, instance data and motion adapters.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland




Item {
    readonly property var nayoriGithubFace: BridgeContext.find(typeof parent !== "undefined" ? parent : null)

    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: nayoriGithubFace.scaler.s(520)
    property real maxWidth: nayoriGithubFace.scaler.s(1200)
    property real minHeight: nayoriGithubFace.scaler.s(140)
    property real maxHeight: nayoriGithubFace.scaler.s(380)
    property real fixedAspect: 0
    property real minAspect: minWidth / maxHeight
    property real maxAspect: maxWidth / minHeight
    property bool isRound: false
    // The Stage slot can own the backing without covering this face.
    property bool ryokuBare: false


    property string username: ""
    // A live Stage option takes precedence over an older cached account.
    property string hostUser: ""
    onHostUserChanged: {
        if (hostUser.trim() === "") {
            if (nayoriGithubFace.runtime) nayoriGithubFace.runtime.release("github-" + String(root) + ":")
            username = ""
            clearData()
            return
        }
        if (hostUser !== "" && hostUser !== username) {
            saveUsername(hostUser);
            loadUser(hostUser, true);
        }
    }
    property var rawContributionsList: []
    property var weeks: []
    property int totalContributions: 0
    property bool loading: false
    property bool hasError: false

    property var selectedDay: null
    property bool isEditingUser: false
    property bool wantsKeyboardFocus: isEditingUser

    property int currentYear: new Date().getFullYear()
    property int selectedYear: new Date().getFullYear()
    property int minYear: 2008
    property int maxYear: new Date().getFullYear()

    readonly property real spacing: nayoriGithubFace.scaler.s(3)
    readonly property real monthGap: nayoriGithubFace.scaler.s(8)
    readonly property real availH: Math.max(10, heatmapContainer.height)
    property real cellSize: Math.max(nayoriGithubFace.scaler.s(10), Math.floor((availH - (6 * spacing)) / 7))
    property bool isResizing: false

    function setKeyboardFocus(enable) { root.wantsKeyboardFocus = enable; if (enable) root.forceActiveFocus() }

    Timer {
        id: resizeSettledTimer
        interval: 150
        repeat: false
        onTriggered: {
            root.isResizing = false;
            let nextSize = Math.max(nayoriGithubFace.scaler.s(10), Math.floor((root.availH - (6 * root.spacing)) / 7));
            if (Math.abs(root.cellSize - nextSize) >= 1) {
                root.cellSize = nextSize;
            }
            root.scrollToLatest();
        }
    }

    onWidthChanged: {
        root.isResizing = true;
        resizeSettledTimer.restart();
    }

    onAvailHChanged: {
        root.isResizing = true;
        resizeSettledTimer.restart();
    }

    function scrollToLatest() {
        if (heatmapFlickable.contentWidth > heatmapFlickable.width) {
            heatmapFlickable.contentX = heatmapFlickable.contentWidth - heatmapFlickable.width;
        } else {
            heatmapFlickable.contentX = 0;
        }
    }

    function formatDate(dateStr) {
        if (!dateStr) return "";
        let parts = dateStr.split("-");
        if (parts.length !== 3) return dateStr;
        let monthKeys = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        let m = parseInt(parts[1]) - 1;
        let d = parseInt(parts[2]);
        let monthStr = (m >= 0 && m < 12) ? nayoriGithubFace.i18n.t("weather.months." + monthKeys[m]) : parts[1];
        return monthStr + " " + d;
    }

    function getColorForLevel(lvl) {
        let accent = (!!nayoriGithubFace.pythonTheme && nayoriGithubFace.pythonTheme.green) ? nayoriGithubFace.pythonTheme.green : Qt.color("#a6e3a1");
        let baseSurface = (!!nayoriGithubFace.pythonTheme && nayoriGithubFace.pythonTheme.surface1) ? nayoriGithubFace.pythonTheme.surface1 : Qt.color("#313244");
        if (lvl <= 0) return Qt.alpha(baseSurface, nayoriGithubFace.pythonTheme.elementOpacity);
        if (lvl === 1) return Qt.rgba(accent.r, accent.g, accent.b, 0.35);
        if (lvl === 2) return Qt.rgba(accent.r, accent.g, accent.b, 0.58);
        if (lvl === 3) return Qt.rgba(accent.r, accent.g, accent.b, 0.80);
        return accent;
    }

    function selectDefaultDate() {
        if (!root.rawContributionsList || root.rawContributionsList.length === 0) {
            root.selectedDay = null;
            return;
        }

        let now = new Date();
        let yyyy = now.getFullYear();
        let mm = String(now.getMonth() + 1).padStart(2, "0");
        let dd = String(now.getDate()).padStart(2, "0");
        let todayStr = yyyy + "-" + mm + "-" + dd;

        for (let i = root.rawContributionsList.length - 1; i >= 0; i--) {
            if (root.rawContributionsList[i].date === todayStr) {
                root.selectedDay = root.rawContributionsList[i];
                return;
            }
        }
        root.selectedDay = root.rawContributionsList[root.rawContributionsList.length - 1];
    }

    function processContributions(list, totalCount) {
        if (!list || list.length === 0) {
            root.rawContributionsList = [];
            root.weeks = [];
            root.totalContributions = 0;
            root.selectedDay = null;
            root.loading = false;
            return;
        }

        list.sort(function(a, b) {
            return a.date.localeCompare(b.date);
        });

        root.rawContributionsList = list;

        let weeksArr = [];
        let curWeek = [];
        let prevMonth = -1;

        let firstDateParts = list[0].date.split("-");
        let firstDate = new Date(parseInt(firstDateParts[0]), parseInt(firstDateParts[1]) - 1, parseInt(firstDateParts[2]));
        let firstDayOfWeek = (firstDate.getDay() + 6) % 7;

        for (let p = 0; p < firstDayOfWeek; p++) {
            curWeek.push(null);
        }

        let calculatedTotal = 0;
        for (let i = 0; i < list.length; i++) {
            let item = list[i];
            calculatedTotal += (item.count || 0);
            curWeek.push(item);
            if (curWeek.length === 7) {
                let primaryMonth = -1;
                for (let d = 0; d < 7; d++) {
                    if (curWeek[d] && curWeek[d].date) {
                        let m = parseInt(curWeek[d].date.split("-")[1]) - 1;
                        if (primaryMonth === -1 || d >= 3) {
                            primaryMonth = m;
                        }
                    }
                }
                let isMonthStart = (prevMonth !== -1 && primaryMonth !== -1 && primaryMonth !== prevMonth);
                if (primaryMonth !== -1) prevMonth = primaryMonth;

                weeksArr.push({ days: curWeek, isNewMonth: isMonthStart });
                curWeek = [];
            }
        }

        if (curWeek.length > 0) {
            while (curWeek.length < 7) {
                curWeek.push(null);
            }
            let primaryMonth = -1;
            for (let d = 0; d < 7; d++) {
                if (curWeek[d] && curWeek[d].date) {
                    let m = parseInt(curWeek[d].date.split("-")[1]) - 1;
                    if (primaryMonth === -1 || d >= 3) {
                        primaryMonth = m;
                    }
                }
            }
            let isMonthStart = (prevMonth !== -1 && primaryMonth !== -1 && primaryMonth !== prevMonth);
            weeksArr.push({ days: curWeek, isNewMonth: isMonthStart });
        }

        root.weeks = weeksArr;
        root.totalContributions = (totalCount !== undefined && totalCount !== null) ? totalCount : calculatedTotal;
        root.hasError = false;
        root.loading = false;
        root.selectDefaultDate();
        Qt.callLater(root.scrollToLatest);
    }

    function clearData() {
        root.rawContributionsList = [];
        root.weeks = [];
        root.totalContributions = 0;
        root.selectedDay = null;
        root.hasError = false;
        root.loading = false;
    }

    Component.onDestruction: if (nayoriGithubFace && nayoriGithubFace.runtime) nayoriGithubFace.runtime.release("github-" + String(root) + ":")

    function saveUsername(user) { nayoriGithubFace.editOption("hostUser", user) }

    function loadUser(user, forceFetch) {
        if (!user || user.trim() === "") {
            clearData();
            return;
        }
        let clean = user.trim();
        root.username = clean;
        root.selectedDay = null;
        if (forceFetch) {
            fetchContributions(clean, root.selectedYear, true);
            return;
        }
        readCacheForYear(clean, root.selectedYear);
    }

    function readCacheForYear(user,year) { fetchContributions(user,year) }

    function saveCachedData(user,year,list,totalVal) {} // shared service owns the cache

    function fetchContributions(user,year,force) {
        if (!user || !nayoriGithubFace.runtime || !nayoriGithubFace.active) { root.clearData(); return }
        root.loading = true; root.hasError = false
        nayoriGithubFace.runtime.request("github", {user:user,year:year,force:!!force}, "github-" + String(root) + ":" + user + ":" + year)
    }

    function fetchGithubHtml(user,year) { root.hasError = true; root.loading = false }











    Connections {
        target: nayoriGithubFace.runtime
        function onResponse(key,data) {
            if (key !== "github-" + String(root) + ":" + root.username + ":" + root.selectedYear) return
            if (data.error) { root.loading = false; root.hasError = true; return }
            root.processContributions(data.contributions || [],data.total)
        }
    }
    Connections {
        target: nayoriGithubFace
        function onActiveChanged() {
            if (nayoriGithubFace.active && root.hostUser) root.loadUser(root.hostUser,false)
            else if (nayoriGithubFace.runtime) nayoriGithubFace.runtime.release("github-" + String(root) + ":")
        }
    }
    Component.onCompleted: if (root.hostUser) root.loadUser(root.hostUser,false)
    TextMetrics {
        id: usernameTextMetrics
        font.family: nayoriGithubFace.pythonTheme.fontFamily
        font.pixelSize: nayoriGithubFace.scaler.s(11)
        font.weight: Font.Medium
        text: root.username !== "" ? root.username : nayoriGithubFace.i18n.t("widgets.github.set_user")
    }

    Rectangle {
        anchors.fill: parent
        color: root.ryokuBare ? "transparent" : Qt.alpha(nayoriGithubFace.pythonTheme.surface0, nayoriGithubFace.pythonTheme.elementOpacity)
        radius: nayoriGithubFace.pythonTheme.clampedBorderRadius !== undefined ? nayoriGithubFace.pythonTheme.clampedBorderRadius : nayoriGithubFace.pythonTheme.borderRadius
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
            visible: !root.ryokuBare
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: nayoriGithubFace.scaler.s(8)
            spacing: nayoriGithubFace.scaler.s(6)

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                spacing: nayoriGithubFace.scaler.s(6)

                IconButton {
                    Layout.preferredWidth: nayoriGithubFace.scaler.s(30)
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                    size: nayoriGithubFace.scaler.s(30)
                    cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                    buttonIcon: root.isEditingUser ? "󰄬" : "󰏫"
                    iconFontSize: nayoriGithubFace.scaler.s(14)
                    accentColor: root.isEditingUser ? nayoriGithubFace.pythonTheme.green : nayoriGithubFace.pythonTheme.surface1
                    bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                    textColor: root.isEditingUser ? nayoriGithubFace.pythonTheme.surface0 : nayoriGithubFace.pythonTheme.subtext0

                    onClicked: {
                        if (root.isEditingUser) {
                            let clean = usernameInput.text.trim();
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                            if (clean !== root.username && clean !== "") {
                                root.saveUsername(clean);
                                root.loadUser(clean, false);
                            }
                        } else {
                            usernameInput.text = root.username;
                            root.isEditingUser = true;
                            root.setKeyboardFocus(true);
                            Qt.callLater(function() {
                                if (usernameInput.forceInputFocus) {
                                    usernameInput.forceInputFocus();
                                } else if (usernameInput.forceActiveFocus) {
                                    usernameInput.forceActiveFocus();
                                }
                                if (usernameInput.selectAll) {
                                    usernameInput.selectAll();
                                }
                            });
                        }
                    }
                }

                Item {
                    id: usernameSlot
                    Layout.preferredWidth: root.isEditingUser ? Math.max(nayoriGithubFace.scaler.s(100), usernameInput.implicitWidth) : Math.max(nayoriGithubFace.scaler.s(44), usernameTextMetrics.width + nayoriGithubFace.scaler.s(22))
                    Layout.fillWidth: root.isEditingUser
                    Layout.maximumWidth: root.isEditingUser ? nayoriGithubFace.scaler.s(160) : -1
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)

                    ClickButton {
                        id: usernameDisplayButton
                        anchors.fill: parent
                        visible: !root.isEditingUser
                        enabled: !root.isEditingUser
                        cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                        horizontalPadding: nayoriGithubFace.scaler.s(8)
                        textFontSize: nayoriGithubFace.scaler.s(11)
                        accentColor: nayoriGithubFace.pythonTheme.surface1
                        bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                        textColor: nayoriGithubFace.pythonTheme.text
                        buttonText: root.username !== "" ? root.username : nayoriGithubFace.i18n.t("widgets.github.set_user")

                        onClicked: {
                            usernameInput.text = root.username;
                            root.isEditingUser = true;
                            root.setKeyboardFocus(true);
                            Qt.callLater(function() {
                                if (usernameInput.forceInputFocus) {
                                    usernameInput.forceInputFocus();
                                } else if (usernameInput.forceActiveFocus) {
                                    usernameInput.forceActiveFocus();
                                }
                                if (usernameInput.selectAll) {
                                    usernameInput.selectAll();
                                }
                            });
                        }
                    }

                    Input {
                        id: usernameInput
                        anchors.fill: parent
                        visible: root.isEditingUser
                        enabled: root.isEditingUser
                        fontPixelSize: nayoriGithubFace.scaler.s(11)
                        horizontalPadding: nayoriGithubFace.scaler.s(8)
                        cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                        baseColor: nayoriGithubFace.pythonTheme.surface1
                        bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                        textColor: nayoriGithubFace.pythonTheme.text
                        subTextColor: nayoriGithubFace.pythonTheme.subtext0
                        accentColor: nayoriGithubFace.pythonTheme.green
                        leadingIcon: ""
                        showClearButton: false
                        placeholderText: nayoriGithubFace.i18n.t("widgets.types.user")
                        isBusy: root.loading && !root.isEditingUser
                        hasError: false

                        Keys.onEscapePressed: {
                            usernameInput.text = root.username;
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                        }

                        onAccepted: function(finalText) {
                            let clean = (finalText !== undefined ? finalText : usernameInput.text).trim();
                            root.isEditingUser = false;
                            root.setKeyboardFocus(false);
                            if (clean !== root.username && clean !== "") {
                                root.saveUsername(clean);
                                root.loadUser(clean, false);
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                        color: "transparent"
                        visible: root.isEditingUser
                        z: 10
                    }
                }

                NumberSelector {
                    id: yearSelector
                    Layout.preferredWidth: nayoriGithubFace.scaler.s(104)
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                    cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                    from: root.minYear
                    to: root.maxYear
                    stepSize: 1.0
                    decimals: 0
                    value: root.selectedYear
                    fontPixelSize: nayoriGithubFace.scaler.s(11)
                    iconFontSize: nayoriGithubFace.scaler.s(12)
                    baseColor: Qt.alpha(nayoriGithubFace.pythonTheme.surface1, nayoriGithubFace.pythonTheme.elementOpacity)
                    buttonColor: Qt.alpha(nayoriGithubFace.pythonTheme.surface2 !== undefined ? nayoriGithubFace.pythonTheme.surface2 : Qt.lighter(nayoriGithubFace.pythonTheme.surface1, 1.1), nayoriGithubFace.pythonTheme.elementOpacity)
                    textColor: nayoriGithubFace.pythonTheme.text
                    accentColor: nayoriGithubFace.pythonTheme.green
                    buttonTextColor: nayoriGithubFace.pythonTheme.subtext0

                    onValueChanged: {
                        let y = Math.round(value);
                        if (y !== root.selectedYear) {
                            root.selectedYear = y;
                            if (root.username !== "") {
                                root.readCacheForYear(root.username, y);
                            }
                        }
                    }
                }

                ClickButton {
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                    Layout.minimumWidth: nayoriGithubFace.scaler.s(60)
                    cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                    horizontalPadding: nayoriGithubFace.scaler.s(10)
                    textFontSize: nayoriGithubFace.scaler.s(11)
                    accentColor: nayoriGithubFace.pythonTheme.surface1
                    bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                    textColor: root.hasError ? nayoriGithubFace.pythonTheme.red : (root.loading ? nayoriGithubFace.pythonTheme.subtext0 : nayoriGithubFace.pythonTheme.text)
                    buttonText: {
                        if (root.loading) return "...";
                        if (root.hasError) return nayoriGithubFace.i18n.t("widgets.github.error");
                        if (root.username === "") return "0 " + nayoriGithubFace.i18n.t("widgets.github.commits");
                        return root.totalContributions + " " + (root.totalContributions === 1 ? nayoriGithubFace.i18n.t("widgets.github.commit") : nayoriGithubFace.i18n.t("widgets.github.commits"));
                    }

                    onClicked: {
                        if (root.username !== "") {
                            nayoriGithubFace.spawn.runApp(["xdg-open", "https://github.com/" + root.username], { label: "browser" });
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }

                ClickButton {
                    Layout.preferredWidth: nayoriGithubFace.scaler.s(142)
                    Layout.minimumWidth: nayoriGithubFace.scaler.s(90)
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                    cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                    horizontalPadding: nayoriGithubFace.scaler.s(8)
                    textFontSize: nayoriGithubFace.scaler.s(10)
                    accentColor: nayoriGithubFace.pythonTheme.surface1
                    bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                    textColor: nayoriGithubFace.pythonTheme.text
                    buttonText: {
                        if (root.selectedDay) {
                            let cnt = root.selectedDay.count || 0;
                            let commitLabel = cnt === 1 ? nayoriGithubFace.i18n.t("widgets.github.commit") : nayoriGithubFace.i18n.t("widgets.github.commits");
                            return cnt + " " + commitLabel + " • " + root.formatDate(root.selectedDay.date);
                        }
                        return nayoriGithubFace.i18n.t("widgets.github.no_day_selected");
                    }

                    onClicked: {
                        root.selectDefaultDate();
                    }
                }

                IconButton {
                    Layout.preferredWidth: nayoriGithubFace.scaler.s(30)
                    Layout.preferredHeight: nayoriGithubFace.scaler.s(30)
                    size: nayoriGithubFace.scaler.s(30)
                    cornerRadius: nayoriGithubFace.pythonTheme.borderRadius > 0 ? Math.min(nayoriGithubFace.pythonTheme.borderRadius, nayoriGithubFace.scaler.s(6)) : nayoriGithubFace.scaler.s(6)
                    buttonIcon: "󰑓"
                    iconFontSize: nayoriGithubFace.scaler.s(14)
                    accentColor: nayoriGithubFace.pythonTheme.surface1
                    bgOpacity: nayoriGithubFace.pythonTheme.elementOpacity
                    textColor: nayoriGithubFace.pythonTheme.subtext0

                    onClicked: {
                        if (root.username !== "") {
                            root.fetchContributions(root.username, root.selectedYear);
                        }
                    }
                }
            }

            Item {
                id: heatmapContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Flickable {
                    id: heatmapFlickable
                    anchors.fill: parent
                    contentWidth: weeksRow.width
                    contentHeight: parent.height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    WheelHandler {
                        target: heatmapFlickable
                        onWheel: function(event) {
                            let delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            heatmapFlickable.contentX = Math.max(0, Math.min(heatmapFlickable.contentWidth - heatmapFlickable.width, heatmapFlickable.contentX - delta));
                        }
                    }

                    Row {
                        id: weeksRow
                        spacing: 0
                        height: parent.height

                        Repeater {
                            model: root.weeks

                            delegate: Row {
                                id: weekRow
                                spacing: 0
                                height: parent.height
                                readonly property var weekData: modelData
                                z: weekHoverHandler.hovered ? 3 : 1

                                HoverHandler {
                                    id: weekHoverHandler
                                }

                                Item {
                                    width: (weekData.isNewMonth && index > 0) ? root.monthGap : 0
                                    height: 1
                                }

                                Column {
                                    spacing: root.spacing
                                    width: root.cellSize
                                    anchors.verticalCenter: parent.verticalCenter

                                    Repeater {
                                        model: weekData.days

                                        delegate: Rectangle {
                                            id: cellBox
                                            readonly property var dayObj: modelData
                                            readonly property bool isHovered: (tileMa.containsMouse || tileHoverHandler.hovered) && cellBox.dayObj !== null
                                            readonly property color baseColor: cellBox.dayObj ? root.getColorForLevel(cellBox.dayObj.level) : "transparent"

                                            property real popScale: 1.0
                                            property real flashOpacity: 0.0

                                            z: cellBox.isHovered ? 2 : 1
                                            width: root.cellSize
                                            height: root.cellSize
                                            radius: Math.max(2, Math.min(nayoriGithubFace.scaler.s(4), Math.round(root.cellSize * 0.22)))
                                            color: cellBox.dayObj === null ? "transparent" : (tileMa.pressed ? Qt.darker(cellBox.baseColor, 1.12) : (cellBox.isHovered ? Qt.lighter(cellBox.baseColor, 1.12) : cellBox.baseColor))
                                            Behavior on color { ColorAnimation { duration: (nayoriGithubFace.reducedMotion ? 0 : 150) } }

                                            scale: (cellBox.dayObj === null ? 1.0 : (tileMa.pressed ? 1.08 : (cellBox.isHovered ? 1.04 : 1.0))) * cellBox.popScale
                                            Behavior on scale {
                                                NumberAnimation {
                                                    duration: (nayoriGithubFace.reducedMotion ? 0 : 250)
                                                    easing.type: Easing.OutQuint
                                                }
                                            }

                                            SequentialAnimation {
                                                id: tilePopAnim
                                                NumberAnimation {
                                                    target: cellBox
                                                    property: "popScale"
                                                    to: 1.1
                                                    duration: (nayoriGithubFace.reducedMotion ? 0 : 110)
                                                    easing.type: Easing.OutQuad
                                                }
                                                NumberAnimation {
                                                    target: cellBox
                                                    property: "popScale"
                                                    to: 1.0
                                                    duration: (nayoriGithubFace.reducedMotion ? 0 : 400)
                                                    easing.type: Easing.OutQuint
                                                }
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: cellBox.radius
                                                color: "#ffffff"
                                                opacity: cellBox.flashOpacity
                                                clip: true

                                                PropertyAnimation on opacity {
                                                    id: tileFlashAnim
                                                    to: 0
                                                    duration: (nayoriGithubFace.reducedMotion ? 0 : 400)
                                                    easing.type: Easing.OutExpo
                                                }
                                            }

                                            HoverHandler {
                                                id: tileHoverHandler
                                                enabled: !root.isResizing && cellBox.dayObj !== null
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            MouseArea {
                                                id: tileMa
                                                anchors.fill: parent
                                                enabled: !root.isResizing && cellBox.dayObj !== null
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    if (cellBox.dayObj) {
                                                        tilePopAnim.start();
                                                        cellBox.flashOpacity = 0.4;
                                                        tileFlashAnim.start();
                                                        if (!!nayoriGithubFace.sounds) {
                                                            nayoriGithubFace.sounds.playSfx("reusables/iconbutton/click.wav");
                                                        }
                                                        root.selectedDay = cellBox.dayObj;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: root.spacing
                                    height: 1
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: nayoriGithubFace.scaler.s(4)
                    visible: root.weeks.length === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: nayoriGithubFace.pythonTheme.iconFont
                        font.pixelSize: nayoriGithubFace.scaler.s(22)
                        color: root.hasError ? nayoriGithubFace.pythonTheme.red : nayoriGithubFace.pythonTheme.subtext0
                        text: root.hasError ? "󰅚" : (root.loading ? "󰑓" : "󰊤")
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        font.family: nayoriGithubFace.pythonTheme.fontFamily
                        font.pixelSize: nayoriGithubFace.scaler.s(10)
                        font.weight: Font.Medium
                        color: root.hasError ? nayoriGithubFace.pythonTheme.red : nayoriGithubFace.pythonTheme.subtext0
                        text: {
                            if (root.loading) return nayoriGithubFace.i18n.t("widgets.github.fetching");
                            if (root.hasError) return nayoriGithubFace.i18n.t("widgets.github.fetch_error", { user: root.username }).replace("{user}", root.username);
                            if (root.username === "") return nayoriGithubFace.i18n.t("widgets.github.enter_username");
                            return nayoriGithubFace.i18n.t("widgets.github.no_contributions");
                        }
                    }
                }
            }
        }
    }
}
