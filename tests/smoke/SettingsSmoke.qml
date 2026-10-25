pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import QtTest as Test
import Quickshell.Io
import "services/settings"
import "services/canvas"
import "surfaces/settings"
import "tokens"

ShellRoot {
    id: test

    property int phase: 0
    property int ticks: 0
    property int changes: 0
    property var viewRef: null
    property int uiRequests: 0
    property int surfaceStyleRequests: 0
    property int iconRequests: 0
    property var visitedSections: []
    property int intervalRequests: 0
    property int closeRequests: 0
    property bool interactionsChecked: false
    property int capturePage: 0
    readonly property var capturePages: viewRef ? viewRef.sections.map(section => section.page) : [0]
    property int sizeIndex: 0
    readonly property var sizes: [Qt.size(720, 560), Qt.size(1100, 760), Qt.size(1600, 1000), Qt.size(880, 680)]
    property bool uiVisible: true
    readonly property string scenario: Quickshell.env("NAYORI_SETTINGS_SCENARIO") || "write"

    function findItem(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children || []) {
            const found = findItem(child, name)
            if (found) return found
        }
        return null
    }

    function check(ok, message) {
        if (!ok) {
            console.error("SETTINGS_FAIL " + message);
            Qt.exit(1);
        }
    }

    function finish() {
        console.log("SETTINGS_PASS " + scenario);
        Qt.quit();
    }

    SettingsService {
        id: settings

        storageDirectory: Quickshell.env("NAYORI_SETTINGS_DIR")
    }

    WallpaperManager { id: wallpaper; storageDirectory: Quickshell.env("NAYORI_SETTINGS_DIR") }

    Tokens {
        id: theme
        surfaceStyle: settings.surfaceStyle
        animationsEnabled: settings.animationsEnabled
    }

    Connections {
        function onValuesChanged() {
            test.changes++;
        }

        target: settings
    }

    Process {
        id: allowWrite
        command: ["chmod", "700", settings.storageDirectory]
        onExited: function(code) {
            test.check(code === 0, "restore directory permissions")
            settings.flush(false)
            test.phase = 5
        }
    }

    // UI is intentionally absent during the persistence scenarios.
    LazyLoader {
        active: (test.scenario === "ui" || test.scenario === "motion") && test.uiVisible

        FloatingWindow {
            visible: true
            implicitWidth: 1600
            implicitHeight: 1000

            Settings {
                id: view

                width: test.sizes[test.sizeIndex].width
                height: test.sizes[test.sizeIndex].height
                tokens: theme
                wallpaperManager: wallpaper
                onCloseRequested: test.closeRequests++
                frequentKeys: ["appearance", "sound", "network", "power"]
                recentKeys: ["display", "lockscreen", "wallpapers", "sound", "network", "panels", "island", "power"]
                onSectionVisited: key => { test.visitedSections = test.visitedSections.concat([key]); }
                Test.TestEvent { id: input }
                function exerciseInput() {
                    test.check(section.title === "Обзор" && !hasSecondary, "consistent overview name")
                    const shortcuts = ["wallpapers", "appearance", "panels", "island"]
                    for (const key of shortcuts) {
                        openKey("home")
                        const item = test.findItem(view, "home-quick-" + key)
                        item.forceActiveFocus()
                        input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                        test.check(section.key === key, "overview quick link " + key)
                    }
                    for (const key of ["network", "sound", "power"]) {
                        openKey("home")
                        const item = test.findItem(view, "home-status-" + key)
                        item.forceActiveFocus()
                        input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                        test.check(section.key === key, "overview status link " + key)
                    }
                    openKey("home")
                    const frequent = test.findItem(view, "home-frequent-sound")
                    frequent.forceActiveFocus()
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(currentPage === 6, "frequent section opens")
                    test.check(test.visitedSections.indexOf("home") < 0, "overview excluded from history")
                    const visits = test.visitedSections.length
                    openKey("sound")
                    test.check(test.visitedSections.length === visits, "same page does not count twice")
                    openKey("home")
                    const search = test.findItem(view, "settings-search-toggle")
                    input.mouseClick(search, search.width / 2, search.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                    Qt.callLater(exerciseSearch)
                }
                function exerciseSearch() {
                    const field = test.findItem(view, "settings-search")
                    test.check(searchOpen && field.visible && field.activeFocus && visibleSections.length === 7 && visibleSections[0].key === "display" && visibleSections[6].key === "island", "global search shows seven most recent sections")
                    const display = test.findItem(view, "settings-nav-display")
                    test.check(display.detail === "Система / Экран", "search result includes settings path")
                    test.check(sectionPath(sections.find(item => item.key === "lockscreen")) === "Облик / Экран блокировки", "appearance path uses visible category name")
                    for (const letter of "Dynamic") input.keyClickChar(letter, Qt.NoModifier, -1)
                    test.check(visibleSections.some(item => item.key === "island"), "search finds global section")
                    navQuery = "а"
                    test.check(visibleSections.length === 10, "query results limited to ten")
                    const recent = recentKeys
                    recentKeys = []
                    navQuery = ""
                    test.check(visibleSections.length === 0, "empty history does not invent recent sections")
                    recentKeys = recent
                    navQuery = field.text
                    input.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
                    test.check(searchOpen && navQuery === "" && test.closeRequests === 0, "Escape clears search")
                    input.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
                    test.check(!searchOpen && test.closeRequests === 0, "Escape closes search without closing settings")
                    test.check(test.findItem(view, "settings-search-toggle").activeFocus, "search returns focus to trigger")
                    selectCategory("Система")
                    test.check(!field.visible, "no search field in category navigation")
                    Qt.callLater(exerciseSystem)
                }
                function exerciseSystem() {
                    focusInput()
                    test.check(test.findItem(view, "settings-nav-display").activeFocus, "category navigation focus")
                    input.keyClick(Qt.Key_Down, Qt.NoModifier, -1)
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(currentPage === 6, "activate category page by keyboard")
                    selectCategory("Персонализация")
                    Qt.callLater(exercisePersonal)
                }
                function exercisePersonal() {
                    focusInput()
                    input.keyClick(Qt.Key_Down, Qt.NoModifier, -1)
                    input.keyClick(Qt.Key_Down, Qt.NoModifier, -1)
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(currentPage === 1, "panels page opens from the sidebar")
                    const slider = test.findItem(view, "bottomReservationSlider")
                    slider.forceActiveFocus()
                    const flick = test.findItem(view, "settings-panels-scroll")
                    test.check(flick.contentY > 0, "focus reveals lower controls")
                    test.check(flick.height > 0 && flick.contentHeight > flick.height, "panels page scrolls: visible height and taller content")
                    test.check(flick.contentY + flick.height <= flick.contentHeight + 1, "reveal stays inside the scrollable range")
                    const revealedY = flick.contentY
                    const autohide = test.findItem(view, "panels-autohide")
                    autohide.forceActiveFocus()
                    test.check(flick.contentY >= 0 && flick.contentY + flick.height <= flick.contentHeight + 1, "focus on the top switch keeps scroll in range")
                    slider.forceActiveFocus()
                    test.check(Math.abs(flick.contentY - revealedY) < 1, "refocusing a visible control does not move the page")
                    currentPage = 2
                    const frosted = test.findItem(view, "surfaceStyle-frosted")
                    input.mouseClick(frosted, frosted.width / 2, frosted.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                    test.check(settings.surfaceStyle === "frosted" && test.surfaceStyleRequests === 1, "style action applies once")
                    settings.update({surfaceStyle: "solid"})
                    test.check(!frosted.checked && test.surfaceStyleRequests === 1, "service updates style without signal loop")
                    const animationsControl = test.findItem(view, "settingsAnimationsToggle")
                    animationsControl.forceActiveFocus()
                    const appearance = test.findItem(view, "settingsAppearanceScroll")
                    const animationY = animationsControl.mapToItem(appearance.contentItem, 0, 0).y
                    test.check(animationY >= -1 && animationY + animationsControl.height <= appearance.height + 1,
                        "compact appearance scroll reveals keyboard focus")
                    openKey("naomi")
                    test.check(currentPage === 25, "dedicated Naomi page opens")
                    const companionControl = test.findItem(view, "settingsCompanionToggle")
                    companionControl.forceActiveFocus()
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(!settings.companionEnabled, "companion disables from settings")
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(settings.companionEnabled, "companion re-enables from settings")
                    const desktopOnlyControl = test.findItem(view, "settingsCompanionDesktopOnlyToggle")
                    settings.update({companionDesktopOnly: false})
                    test.check(!desktopOnlyControl.checked, "desktop-only switch follows the service")
                    desktopOnlyControl.forceActiveFocus()
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(settings.companionDesktopOnly && desktopOnlyControl.checked, "desktop-only applies from settings")
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(!settings.companionDesktopOnly, "desktop-only turns off from settings")
                    settings.update({startIconStyle: "current"})
                    openKey("start")
                    Qt.callLater(exerciseStart)
                }
                function exerciseStart() {
                    const fox = test.findItem(view, "startIcon-fox")
                    fox.forceActiveFocus()
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(settings.startIconStyle === "fox" && test.iconRequests === 1, "fox applies immediately exactly once")
                    settings.update({startIconStyle: "current"})
                    test.check(!fox.checked && test.iconRequests === 1, "service updates icon selection without feedback")
                    currentPage = 3
                    const field = test.findItem(view, "weatherCityInput")
                    const original = settings.weatherCity
                    field.forceActiveFocus()
                    field.selectAll()
                    for (const letter of "Paris") input.keyClickChar(letter, Qt.NoModifier, -1)
                    test.check(settings.weatherCity === original, "typing does not apply city")
                    const apply = test.findItem(view, "weatherApplyButton")
                    input.keyClick(Qt.Key_Tab, Qt.NoModifier, -1)
                    test.check(apply.activeFocus, "Tab reaches Apply")
                    input.keyClick(Qt.Key_Tab, Qt.ShiftModifier, -1)
                    test.check(field.activeFocus, "Shift+Tab returns to city input")
                    input.mouseClick(apply, apply.width / 2, apply.height / 2, Qt.LeftButton, Qt.NoModifier, -1)
                    test.check(settings.weatherCity === "Paris", "Apply changes city")
                    settings.update({weatherCity: original})
                    test.check(field.text === original, "service updates open page")
                    const refresh = test.findItem(view, "weatherRefreshMinutesInput")
                    const originalMinutes = settings.weatherRefreshMinutes
                    refresh.forceActiveFocus()
                    input.keyClick(Qt.Key_Up, Qt.NoModifier, -1)
                    test.check(test.intervalRequests === 1 && settings.weatherRefreshMinutes === originalMinutes + 1, "SpinBox action emits once and applies interval")
                    settings.update({weatherRefreshMinutes: originalMinutes})
                    test.check(refresh.value === originalMinutes && test.intervalRequests === 1, "service updates interval without user signal loop")
                    input.keyClick(Qt.Key_Escape, Qt.NoModifier, -1)
                    test.check(test.closeRequests === 1, "unhandled Escape closes settings")
                    currentPage = 0
                    focusInput()
                    frequentKeys = ["appearance", "shortcuts", "lockscreen", "island"]
                    test.interactionsChecked = true
                    timer.start()
                }
                weatherCity: settings.weatherCity
                weatherRefreshMinutes: settings.weatherRefreshMinutes
                onWeatherRefreshMinutesChangedRequested: minutes => {
                    test.intervalRequests++;
                    settings.update({weatherRefreshMinutes: minutes});
                }
                companionEnabled: settings.companionEnabled
                onCompanionChangedRequested: enabled => settings.update({companionEnabled: enabled})
                companionDesktopOnly: settings.companionDesktopOnly
                onCompanionDesktopOnlyChangedRequested: enabled => settings.update({companionDesktopOnly: enabled})
                startIconStyle: settings.startIconStyle
                onStartIconStyleChangedRequested: style => { test.iconRequests++; settings.update({startIconStyle: style}); }
                surfaceStyle: settings.surfaceStyle
                onSurfaceStyleChangedRequested: style => {
                    test.surfaceStyleRequests++;
                    settings.update({surfaceStyle: style});
                }
                animationsEnabled: settings.animationsEnabled
                onAnimationsChangedRequested: function(enabled) {
                    test.uiRequests++;
                    settings.update({
                        "animationsEnabled": enabled
                    });
                }
                onWeatherCityChangedRequested: (city) => {
                    return settings.update({
                        "weatherCity": city
                    });
                }
                Component.onCompleted: {
                    test.viewRef = view;
                    test.check(implicitWidth === 1100 && implicitHeight === 760, "window-independent desired size");
                    for (let i = 0; i < 5; i++) {
                        currentPage = i;
                        test.check(implicitHeight === 760, "page must not resize window " + i);
                    }
                    currentPage = 0;
                    focusInput();
                    Qt.callLater(function() {
                        view.focusInput();
                    });
                }
            }

        }

    }

    Timer {
        id: timer

        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (!settings.ready)
                return ;

            test.ticks++;
            if (test.ticks > 400) {
                test.check(false, "timeout");
                return ;
            }
            if (test.phase === 0) {
                if (test.scenario === "unsupported" || test.scenario === "unreadable") {
                    test.check(settings.state === test.scenario, "protected state");
                    settings.update({
                        "weatherCity": "changed"
                    });
                    settings.flush(true);
                    test.check(!settings.canRecover && !settings.canRetry, "protected actions");
                    test.phase = 9;
                } else if (test.scenario === "recover" || test.scenario === "backup-fail") {
                    test.check(settings.state === "corrupt" && settings.canRecover, "corrupt state");
                    settings.update({
                        "weatherCity": "Recovered"
                    });
                    settings.recover();
                    test.phase = 3;
                } else if (test.scenario === "normalize") {
                    test.check(settings.topReserved === 4 && settings.bottomReserved === 0, "normalize loaded reservations");
                    test.check(settings.autoHideTop === false && settings.animationsEnabled === true && settings.weatherCity === "", "invalid and missing fields use defaults");
                    test.check(!settings.dirty, "load normalization does not write");
                    test.check(!settings.companionEnabled, "companion defaults off");
                    test.check(!settings.companionDesktopOnly, "desktop-only defaults off");
                    settings.update({companionDesktopOnly: "yes"});
                    test.check(!settings.companionDesktopOnly, "invalid desktop-only value defaults off");
                    settings.update({companionDesktopOnly: true});
                    test.check(settings.companionDesktopOnly, "desktop-only applies immediately");
                    settings.update({companionDesktopOnly: false});
                    settings.update({companionEnabled: true});
                    test.check(settings.companionEnabled, "companion enables immediately");
                    settings.update({companionEnabled: "yes"});
                    test.check(!settings.companionEnabled, "invalid companion value defaults off");
                    settings.update({companionEnabled: true});
                    test.check(settings.startIconStyle === "current", "missing icon defaults to current");
                    settings.update({startIconStyle: "fox"});
                    test.check(settings.startIconStyle === "fox", "fox enum accepted");
                    settings.update({startIconStyle: "unsupported"});
                    test.check(settings.startIconStyle === "current", "invalid icon defaults to current");
                    test.check(settings.surfaceStyle === "solid", "missing or invalid style defaults to solid");
                    test.check(settings.accentMode === "default" && settings.manualAccent === "#C0AFD1", "accent defaults");
                    settings.update({accentMode: "automatic", manualAccent: "#abc"});
                    test.check(settings.accentMode === "automatic" && settings.manualAccent === "#AABBCC", "short accent expands");
                    settings.update({manualAccent: "#80aabbcc"});
                    test.check(settings.manualAccent === "#AABBCC", "accent keeps rgb from #AARRGGBB");
                    settings.update({manualAccent: "#C0AFD1FF"});
                    test.check(settings.manualAccent === "#AFD1FF", "accent drops leading alpha");
                    settings.update({manualAccent: "#C0AFD1"});
                    test.check(settings.manualAccent === "#C0AFD1", "full accent kept");
                    for (const value of ["automatic", "manual", "default"]) {
                        settings.update({accentMode: value});
                        test.check(settings.accentMode === value, "accent mode " + value);
                    }
                    for (const value of ["glass", "", null, true, 1, "#C0AFD1"]) {
                        settings.update({accentMode: "manual"});
                        settings.update({accentMode: value});
                        test.check(settings.accentMode === "default", "invalid accent mode defaults");
                    }
                    settings.update({accentMode: "manual"});
                    for (const value of ["", "red", "#C0AFD1F", "#ABCD", true, null, 1]) {
                        settings.update({manualAccent: "#112233"});
                        settings.update({manualAccent: value});
                        test.check(settings.manualAccent === "#C0AFD1", "invalid manual accent defaults");
                    }
                    settings.update({accentMode: "default", manualAccent: "#C0AFD1"});
                    settings.update({surfaceStyle: "frosted"});
                    test.check(settings.surfaceStyle === "frosted", "frosted accepted");
                    for (const value of ["glass", "Solid", "", null, true, 1]) {
                        settings.update({surfaceStyle: "frosted"});
                        settings.update({surfaceStyle: value});
                        test.check(settings.surfaceStyle === "solid", "invalid style defaults to solid");
                    }
                    test.check(settings.weatherRefreshMinutes === 15, "missing interval uses default");
                    test.check(settings.islandRotationEnabled === true && settings.islandRotationSeconds === 15, "rotation defaults");
                    test.check(settings.preferredTerminal === "kitty" && settings.preferredFileManager === "io.github.lgse.Strata", "app defaults");
                    test.check(settings.niriColorIntegration === true && settings.strataThemeIntegration === true, "integration defaults");
                    settings.update({niriColorIntegration: false, strataThemeIntegration: false});
                    test.check(settings.niriColorIntegration === false && settings.strataThemeIntegration === false, "integration off");
                    settings.update({niriColorIntegration: "no", strataThemeIntegration: 1});
                    test.check(settings.niriColorIntegration === true && settings.strataThemeIntegration === true, "invalid integration defaults on");
                    settings.update({niriColorIntegration: true, strataThemeIntegration: true});
                    settings.update({islandRotationSeconds: 3});
                    test.check(settings.islandRotationSeconds === 5, "rotation clamps low");
                    settings.update({islandRotationSeconds: 500});
                    test.check(settings.islandRotationSeconds === 120, "rotation clamps high");
                    settings.update({islandRotationSeconds: 15.2});
                    test.check(settings.islandRotationSeconds === 15, "rotation rounds");
                    settings.update({islandRotationSeconds: "30"});
                    test.check(settings.islandRotationSeconds === 15, "rotation rejects non-numbers");
                    settings.update({preferredTerminal: "  foot  "});
                    test.check(settings.preferredTerminal === "foot", "terminal trims");
                    settings.update({preferredTerminal: "   "});
                    test.check(settings.preferredTerminal === "kitty", "empty terminal uses default");
                    settings.update({preferredFileManager: 12});
                    test.check(settings.preferredFileManager === "io.github.lgse.Strata", "file manager rejects non-strings");
                    settings.update({islandRotationEnabled: false});
                    test.check(settings.islandRotationEnabled === false, "rotation bool");
                    settings.update({islandRotationSeconds: 15, islandRotationEnabled: true, preferredTerminal: "kitty"});
                    for (const value of [0, 181, 2.5, NaN, Infinity, "30", null, true]) {
                        settings.update({weatherRefreshMinutes: 30});
                        settings.update({weatherRefreshMinutes: value});
                        test.check(settings.weatherRefreshMinutes === 15, "invalid interval uses default " + value);
                    }
                    for (const value of [1, 180, 42]) {
                        settings.update({weatherRefreshMinutes: value});
                        test.check(settings.weatherRefreshMinutes === value, "valid interval " + value);
                    }
                    settings.update({ autoHideApps: true });
                    settings.flush(true);
                    test.finish();
                } else if (test.scenario === "restore") {
                    test.check(settings.weatherCity === "Москва" && settings.topReserved === 200 && !settings.animationsEnabled && settings.weatherRefreshMinutes === 30 && settings.surfaceStyle === "frosted" && settings.startIconStyle === "fox", "restored values");
                    test.check(settings.companionEnabled, "companion restored after restart");
                    test.check(settings.companionDesktopOnly, "desktop-only restored after restart");
                    test.check(!settings.dirty && test.changes === 1, "no write loop on load");
                    test.finish();
                } else if (test.scenario === "revert") {
                    const original = settings.weatherCity;
                    settings.update({weatherCity: "temporary"});
                    settings.update({weatherCity: original});
                    test.phase = 5;
                } else if (test.scenario === "motion") {
                    const view = test.viewRef
                    if (test.ticks === 8) {
                        test.check(view.sidebarWidth === view.railWidth && !view.hasSecondary, "overview has no second level")
                        view.openKey("start")
                    } else if (test.ticks === 9) {
                        const main = test.findItem(view, "settings-main")
                        const sidebar = test.findItem(view, "settings-sidebar")
                        test.check(main.opacity < 1, "page fades before replacement")
                        test.check(sidebar.width > view.railWidth && sidebar.width < view.sidebarWidth, "sidebar expands smoothly")
                    } else if (test.ticks === 14) {
                        test.check(view.displayedPage === 14 && view.displayedCategory === "Персонализация", "page and second level settle")
                        view.openKey("display")
                    } else if (test.ticks === 15) {
                        const main = test.findItem(view, "settings-main")
                        const opacityBefore = main.opacity
                        view.openKey("windows")
                        test.check(main.opacity === opacityBefore, "rapid navigation preserves current opacity")

                    } else if (test.ticks === 21) {
                        test.check(view.displayedPage === 17 && view.displayedCategory === "Окна и столы", "rapid navigation settles on latest target")
                        test.check(test.findItem(view, "settings-main").opacity === 1, "opacity restored")
                        view.openKey("home")
                        settings.update({animationsEnabled: false})
                        test.check(view.displayedPage === 0 && view.displayedCategory === "Обзор", "disabling motion commits pending selection")
                    } else if (test.ticks === 23) {
                        test.check(!test.findItem(view, "settings-secondary").visible, "overview secondary disappears")
                        view.openKey("start")
                        test.check(view.displayedPage === 14 && view.displayedCategory === "Персонализация", "disabled animations apply immediately")
                        test.finish()
                    }
                } else if (test.scenario === "ui") {
                    if (test.ticks > 8) {
                        if (!test.interactionsChecked) {
                            timer.stop();
                            test.viewRef.exerciseInput();
                            return;
                        }
                        test.check(test.viewRef.activeFocus, "navigation focus after creation");
                        test.check(test.uiRequests === 0, "service updates must not emit user requests");
                        test.viewRef.grabToImage(function(result) {
                            for (const category of test.viewRef.categories) {
                                const button = test.findItem(test.viewRef, "settings-category-" + category.glyph)
                                const icon = test.findItem(button, "settings-category-icon")
                                const caption = test.findItem(button, "settings-category-caption")
                                const point = icon.mapToItem(button, 0, 0)
                                test.check(Math.abs(point.x + icon.width / 2 - button.width / 2) < 1, "primary icon horizontally centered")
                                test.check(caption.mapToItem(button, 0, 0).y >= point.y + icon.height, "primary caption below icon")
                            }
                            if (test.viewRef.hasSecondary) for (const section of test.viewRef.visibleSections) {
                                const button = test.findItem(test.viewRef, "settings-nav-" + section.key)
                                const icon = test.findItem(button, "settings-action-icon")
                                const captions = test.findItem(button, "settings-action-captions")
                                test.check(icon.visible && button.glyph === section.key, "second level has icon " + section.key)
                                const center = captions.mapToItem(button, 0, 0).y + captions.height / 2
                                test.check(Math.abs(center - button.height / 2) < 1, "second-level text centered in fill")
                                test.check(Math.abs(icon.mapToItem(button, 0, 0).y + icon.height / 2 - center) < 1, "second-level icon aligned with text")
                            }
                            if (test.viewRef.currentPage === 0) {
                                const banner = test.findItem(test.viewRef, "home-customization-banner")
                                for (const key of ["wallpapers", "appearance", "panels", "island"]) {
                                    const card = test.findItem(test.viewRef, "home-quick-" + key)
                                    const position = card.mapToItem(banner, 0, 0)
                                    test.check(position.y >= 16 && position.y + card.height <= banner.height - 15, "customization stays inside banner " + key)
                                    const glyph = test.findItem(card, "home-link-icon")
                                    const caption = test.findItem(card, "home-link-title")
                                    const arrow = test.findItem(card, "home-link-arrow")
                                    const center = glyph.y + glyph.height / 2
                                    test.check(Math.abs(center - caption.y - caption.height / 2) < 1
                                        && Math.abs(center - arrow.y - arrow.height / 2) < 1, "customization content centered " + key)
                                }
                                for (const key of ["appearance", "shortcuts", "lockscreen", "island"]) {
                                    const card = test.findItem(test.viewRef, "home-frequent-" + key)
                                    const glyph = test.findItem(card, "home-link-icon")
                                    const caption = test.findItem(card, "home-link-title")
                                    test.check(caption.y >= glyph.y + glyph.height, "frequent icon and long title do not overlap " + key)
                                }
                            }
                            result.saveToFile(settings.storageDirectory + "/settings-" + test.sizeIndex + "-" + test.capturePages[test.capturePage] + ".png");
                            if (test.capturePage === test.capturePages.length - 1 && test.sizeIndex < test.sizes.length - 1) {
                                test.sizeIndex++;
                                test.capturePage = 0;
                                test.viewRef.currentPage = 0;
                                timer.start();
                            } else if (test.capturePage === test.capturePages.length - 1) {
                                test.uiVisible = false;
                                settings.update({weatherCity: "window closed"});
                                test.phase = 6;
                                test.ticks = 0;
                                timer.start();
                            }
                            else {
                                test.capturePage++;
                                test.viewRef.currentPage = test.capturePages[test.capturePage];
                                timer.start();
                            }
                        });
                        timer.stop();
                    }
                } else {
                    settings.update({
                        "weatherCity": "  Москва  ",
                        "weatherRefreshMinutes": 30,
                        "surfaceStyle": "frosted",
                        "startIconStyle": "fox",
                        "companionEnabled": true,
                        "companionDesktopOnly": true,
                        "topReserved": 999,
                        "animationsEnabled": false,
                        "autoHideTop": true
                    });
                    test.check(settings.weatherCity === "Москва" && settings.topReserved === 200 && !settings.animationsEnabled, "immediate normalized state");
                    settings.update({
                        "autoHideApps": true
                    });
                    test.check(settings.dirty && !settings.saving, "debounce pending");
                    if (test.scenario === "shutdown") {
                        test.finish();
                        return ;
                    }
                    if (test.scenario === "flush") {
                        settings.flush(true);
                        test.check(!settings.dirty, "blocking flush");
                        test.finish();
                    }
                    test.phase = 1;
                    test.ticks = 0;
                }
            } else if (test.phase === 1) {
                if (test.ticks === 3)
                    settings.update({
                    "bottomReserved": settings.bottomReserved === 72 ? 64 : 72
                });

                if (test.ticks < 7)
                    test.check(settings.dirty, "debounce restarts for all settings");

                if (test.scenario === "save-fail") {
                    if (!settings.saving && settings.message.indexOf("не сохранены") >= 0) {
                        test.check(settings.dirty && settings.canRetry, "retry after error");
                        test.phase = 4;
                        allowWrite.running = true;
                    }
                } else if (!settings.dirty && !settings.saving) {
                    test.finish();
                }
            } else if (test.phase === 3) {
                if (test.scenario === "backup-fail") {
                    if (!settings.backupProcess.running) {
                        test.check(settings.state === "corrupt" && settings.canRecover, "failed backup blocks replacement");
                        test.finish();
                    }
                } else if (settings.state === "writable" && !settings.dirty && !settings.saving) {
                    test.finish();
                }
            } else if (test.phase === 6) {
                if (test.ticks === 1) test.uiVisible = true;
                if (test.ticks > 8) {
                    test.check(!settings.dirty && test.viewRef.weatherCity === "window closed", "save and reopen while debounce pending");
                    test.check(test.uiRequests === 0, "reopening must not send user actions");
                    test.finish();
                }
            } else if (test.phase === 5 && !settings.saving && !settings.dirty) {
                test.check(!settings.canRetry, "successful retry clears error");
                test.finish();
            } else if (test.phase === 9 && test.ticks > 8) {
                test.finish();
            }
        }
    }

}
