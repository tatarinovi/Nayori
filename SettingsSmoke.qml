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
    property int intervalRequests: 0
    property int closeRequests: 0
    property bool interactionsChecked: false
    property int capturePage: 0
    property int sizeIndex: 0
    readonly property var sizes: [Qt.size(720, 560), Qt.size(1100, 760), Qt.size(1600, 1000)]
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
        active: test.scenario === "ui" && test.uiVisible

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
                Test.TestEvent { id: input }
                function exerciseInput() {
                    currentPage = 0
                    focusInput()
                    test.check(input.keyClick(Qt.Key_Down, Qt.NoModifier, -1), "send navigation key")
                    test.check(test.findItem(view, "settings-nav-display").activeFocus, "arrow navigation")
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(currentPage === 5, "activate navigation by keyboard")
                    const panelsButton = test.findItem(view, "settings-nav-panels")
                    let guard = 0
                    while (!panelsButton.activeFocus && guard++ < 40)
                        test.check(input.keyClick(Qt.Key_Down, Qt.NoModifier, -1), "move toward panels")
                    test.check(panelsButton.activeFocus, "panels navigation")
                    input.keyClick(Qt.Key_Space, Qt.NoModifier, -1)
                    test.check(currentPage === 1, "panels page opens from the sidebar")
                    const slider = test.findItem(view, "bottomReservationSlider")
                    slider.forceActiveFocus()
                    const flick = test.findItem(view, "settings-panels-scroll")
                    test.check(flick.contentY > 0, "focus reveals lower controls")
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
                }
                weatherCity: settings.weatherCity
                weatherRefreshMinutes: settings.weatherRefreshMinutes
                onWeatherRefreshMinutesChangedRequested: minutes => {
                    test.intervalRequests++;
                    settings.update({weatherRefreshMinutes: minutes});
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
            if (test.ticks > 70) {
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
                    test.check(settings.weatherRefreshMinutes === 15, "missing interval uses default");
                    test.check(settings.islandRotationEnabled === true && settings.islandRotationSeconds === 15, "rotation defaults");
                    test.check(settings.preferredTerminal === "kitty" && settings.preferredFileManager === "org.gnome.Nautilus", "app defaults");
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
                    test.check(settings.preferredFileManager === "org.gnome.Nautilus", "file manager rejects non-strings");
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
                    test.check(settings.weatherCity === "Москва" && settings.topReserved === 200 && !settings.animationsEnabled && settings.weatherRefreshMinutes === 30, "restored values");
                    test.check(!settings.dirty && test.changes === 1, "no write loop on load");
                    test.finish();
                } else if (test.scenario === "revert") {
                    const original = settings.weatherCity;
                    settings.update({weatherCity: "temporary"});
                    settings.update({weatherCity: original});
                    test.phase = 5;
                } else if (test.scenario === "ui") {
                    if (test.ticks > 8) {
                        if (!test.interactionsChecked) {
                            test.viewRef.exerciseInput();
                            test.interactionsChecked = true;
                        }
                        test.check(test.viewRef.activeFocus, "navigation focus after creation");
                        test.check(test.uiRequests === 0, "service updates must not emit user requests");
                        test.viewRef.grabToImage(function(result) {
                            result.saveToFile(settings.storageDirectory + "/settings-" + test.sizeIndex + "-" + test.capturePage + ".png");
                            if (test.capturePage === 4 && test.sizeIndex < test.sizes.length - 1) {
                                test.sizeIndex++;
                                test.capturePage = 0;
                                test.viewRef.currentPage = 0;
                                timer.start();
                            } else if (test.capturePage === 4) {
                                test.uiVisible = false;
                                settings.update({weatherCity: "window closed"});
                                test.phase = 6;
                                test.ticks = 0;
                                timer.start();
                            }
                            else {
                                test.capturePage++;
                                test.viewRef.currentPage = test.capturePage;
                                timer.start();
                            }
                        });
                        timer.stop();
                    }
                } else {
                    settings.update({
                        "weatherCity": "  Москва  ",
                        "weatherRefreshMinutes": 30,
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
