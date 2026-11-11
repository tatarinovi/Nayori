# Smoke-стенды

Все отдельные QML-конфигурации для проверки Nayori собраны здесь. Запускайте конкретный файл из корня репозитория, например:

```sh
qs -p tests/smoke/IslandBehaviorSmoke.qml
bash scripts/check-island.sh
bash scripts/check-music.sh
bash scripts/check-canvas.sh
qs -p tests/smoke/ClipboardSmoke.qml
```

Quickshell ограничивает импорты каталогом конфигурации. Ссылки `tokens`, `services`, `surfaces`, `islands`, `assets`, `scripts` и `RealShell.qml`, `ShellSession.qml` открывают стендам общие исходники и ресурсы без копирования. Ссылки `fake-audio.py` и `fake-lyrics-worker.py` ведут к искусственным источникам в `tests/`. Сохраняйте эти относительные ссылки при переносе репозитория. `RealShell.qml` используется только для проверки настоящей корневой конфигурации; для запуска стенда всегда указывайте его файл явно.

Автоматические проверки используют временные каталоги и искусственные данные. Проверки материалов и корневой конфигурации требуют Wayland; уведомления проверяются на отдельной D-Bus-шине. Подробные команды — в корневом README и документации соответствующего компонента.

`ClipboardSmoke.qml` проверяет список, превью картинки, поиск, клавиатуру, метаданные, закрепление и очистку на искусственной истории. `ClipboardWindowSmoke.qml` запускается из `python3 tests/clipboard-window.py` во вложенном niri и проверяет слой, фокус и анимацию. Оба стенда не подключают службу реального буфера. Подробнее — [журнал буфера обмена](../../docs/CLIPBOARD.md).

`python3 tests/naomi-sprite.py` запускает `NaomiSpriteSmoke.qml`. `NaomiPixelSmoke.qml` запускается напрямую:

```sh
qs -p tests/smoke/NaomiPixelSmoke.qml
```

`python3 tests/color-scheme.py` проверяет светлую палитру, контраст текста и акцентов, цвета с обоев, прозрачность и возврат к тёмной теме. `NAYORI_THEME_PREVIEW=/tmp/nayori-light.png python3 tests/color-scheme.py` также сохраняет превью настроек.

`python3 tests/panel-modes.py` проверяет отдельные режимы и отступы двух мониторов, селекты с клавиатуры, задержку автоскрытия и промежуточные кадры появления/исчезновения. `node tests/panel-modes.cjs` проверяет нормализацию и совместимость со старыми настройками.

`dbus-run-session -- python3 tests/bluetooth.py` проверяет `BluetoothSmoke.qml` с настоящими Quickshell Bluetooth-моделями и изолированным тестовым BlueZ; нужен PyGObject/Gio. Реальный адаптер не используется. См. [Bluetooth](../../docs/BLUETOOTH.md).

`qs -p tests/smoke/PolkitDialogSmoke.qml` проверяет карточку диалога на искусственном запросе и импортирует модуль Polkit. Объект `PolkitAgent` стенд не создаёт, поэтому агент сеанса не регистрируется. См. [POLKIT.md](../../docs/POLKIT.md).

`WorkspaceMotionSmoke.qml` проверяет промежуточный кадр перехода и отключение
анимаций, шесть карточек стиля с клавиатуры, повторный выбор карточки, восемь
столов на одном выходе и независимый второй выход, постоянную ширину дорожки,
клик, шаги вперёд/назад, пустой список и недоступный сервис Niri.
`tests/settings.py` проверяет применение, нормализацию и сохранение
`workspaceIndicatorStyle` после перезапуска. Оба стенда входят в smoke-набор CI;
`tests/workspace-styles.cjs` входит в unit-набор.

`python3 tests/keybinds.py --smoke` запускает `KeybindsSmoke.qml` с временной
конфигурацией, mock Niri и offscreen Qt. Проверяет поиск, фильтры и подтверждение
черновика, создание/отключение/удаление пользовательского бинда без живого IPC.

### Desktop blur

`DesktopBlurSmoke.qml` feeds fixture snapshots and events into the shared Niri
singleton without a socket: empty/occupied workspaces, independent outputs,
rapid retargeting, disconnect/reconnect, settings and disabled motion. It also
checks source-matched current/previous blur frames, a failed cache, and Center/Fit
geometry. Run it only with disposable XDG directories, offscreen Qt and no
`NIRI_SOCKET`. A second invocation with `NAYORI_BLUR_RESTORE=1` and the same
config directory checks persistence. `SystemPageLoadSmoke.qml` instantiates the
system page and island to catch read-only property conflicts during loading.
These checks do not measure GPU frame time or physical layer-shell stacking.

`python3 tests/widget-dim.py` checks the focused NowPlaying input copy, the dim
layer toggle, and avoiding a second dim on the background copy. CI uses the
software backend. For pixel checks, explicitly set `QT_QUICK_BACKEND=rhi` with
an available graphics backend; offscreen software Qt cannot render MultiEffect.

### System monitor

`SystemMonitorSmoke.qml` uses a disposable Python worker and fixture metrics. It
checks four-tab navigation, three rows without scrolling at 760 and 360 px,
unknown values, the desktop widget adapter, bounded histories and hot removal,
multiple subscribers, repeated open/close and recovery after worker exit. Power
profile clicks target a mock service and never change the host profile. It saves
`/tmp/nayori-system-wide.png` and `/tmp/nayori-system-narrow.png`. Run with the
same disposable XDG/offscreen/D-Bus isolation as the CI smoke suite, or run
`bash scripts/check-system-monitor.sh`. Missing sensors and whole unavailable
cards must hide, and the remaining cards must expand. The lower row has state on the left and power on
the right; the separate temperatures card is absent. Power buttons have equal
geometry and centered icons, rendered by the shared SystemIcon SVG component.
The uptime belongs to the system-state card; there is no inner page heading.

### Startup splash

`python3 tests/startup-splash.py` checks the shared startup barrier, first Qt
frames, two-output fade completion, hotplug cancellation, timeout with explicit
continue, failed wallpaper fallback, accent tinting, frozen startup palette/cache fallback and settings preservation.
It uses temporary XDG directories and offscreen FloatingWindows with the real
StartupCover; layer-shell stacking and physical monitor presentation require
an isolated Wayland check. See [STARTUP_SPLASH.md](../../docs/STARTUP_SPLASH.md).
