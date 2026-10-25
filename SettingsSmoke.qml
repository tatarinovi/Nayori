pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "services/settings"
import "surfaces/settings"
import "tokens"

ShellRoot {
    id: test

    property int phase: 0
    property int ticks: 0
    property int changes: 0
    property var viewRef: null
    property int uiRequests: 0
    property int capturePage: 0
    property bool uiVisible: true
    readonly property string scenario: Quickshell.env("NAYORI_SETTINGS_SCENARIO") || "write"

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
            implicitWidth: 760
            implicitHeight: 850

            Settings {
                id: view

                anchors.centerIn: parent
                tokens: theme
                weatherCity: settings.weatherCity
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
                    test.check(width === 700 && height === 420, "default geometry");
                    for (let i = 0; i < 5; i++) {
                        currentPage = i;
                        test.check(implicitHeight === (i === 4 ? 740 : 420), "page geometry " + i);
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
                    settings.update({ autoHideApps: true });
                    settings.flush(true);
                    test.finish();
                } else if (test.scenario === "restore") {
                    test.check(settings.weatherCity === "Москва" && settings.topReserved === 200 && !settings.animationsEnabled, "restored values");
                    test.check(!settings.dirty && test.changes === 1, "no write loop on load");
                    test.finish();
                } else if (test.scenario === "revert") {
                    const original = settings.weatherCity;
                    settings.update({weatherCity: "temporary"});
                    settings.update({weatherCity: original});
                    test.phase = 5;
                } else if (test.scenario === "ui") {
                    if (test.ticks > 8) {
                        test.check(test.viewRef.activeFocus, "navigation focus after creation");
                        test.check(test.uiRequests === 0, "service updates must not emit user requests");
                        test.viewRef.grabToImage(function(result) {
                            result.saveToFile(settings.storageDirectory + "/settings-" + test.capturePage + ".png");
                            if (test.capturePage === 4) {
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
