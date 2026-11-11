# Архитектура Nayori

Nayori — оболочка на Quickshell и QML. Вход — `shell.qml`, объект `ShellRoot`, идентификатор приложения `nayori`. Запуск: `qs -p` с каталогом оболочки.

Каталогов Noctalia и angelOS в дереве нет. Исторический аудит angelOS: [ANGELOS_AUDIT.md](ANGELOS_AUDIT.md), коммит `79add8bf5a4c0fb8fb9acdf47607f973edfa6e02`. Аудит описывает angelOS и машину на момент снятия. Текущее дерево Nayori он не описывает.

Смежные тексты: [PANEL.md](PANEL.md), [CANVAS.md](CANVAS.md), [SETTINGS.md](SETTINGS.md), [MATERIALS.md](MATERIALS.md), [CLIPBOARD.md](CLIPBOARD.md), [NAOMI.md](NAOMI.md), [ISLAND_INTERACTION.md](ISLAND_INTERACTION.md), [MUSIC_LYRICS.md](MUSIC_LYRICS.md), [ROADMAP.md](ROADMAP.md).

## Слои

| Слой | Где лежит | Что его меняет |
|---|---|---|
| Токены | `tokens/Tokens.qml`, `tokens/AccentRoles.js` | Роли цвета, шаг, шрифт, длительность |
| Настройки | `services/settings/SettingsService.qml` | Выбор человека, файл `settings.json` |
| Сессия запуска | свойства `Scope` в `surfaces/ShellSession.qml` | Какие поверхности открыты в этом процессе |
| Сервисы | `services/` | Сокет niri, звук, сеть, обои, буфер, музыка, погода |
| Поверхности | `surfaces/`, `islands/` | Окна слоя и их жест |

Поверхность получает экземпляр `Tokens` снаружи и вызывает методы сервиса. Поток `EventStream` и очередь действий открывает синглтон `services/niri/Niri.qml`. Путь сокета он берёт только из `NIRI_SOCKET`. Токены в этот сокет не ходят: `NiriAccent` получает уже посчитанный цвет.

Каталогов `state/` и `character/` в дереве нет. Файлов `state/Settings.qml`, `state/Session.qml`, `state/Niri.qml` и `character/Presence.qml` нет.

## Вход

`shell.qml` сначала читает кэш палитры и показывает splash. После первого кадра Loader загружает `surfaces/ShellSession.qml`: этот Scope создаёт сервисы и держит флаги запуска. На каждый подключённый экран `Variants` строит `surfaces/panel/ScreenPanels.qml`. Экран с `focus-at-startup` в конфигурации niri задаёт `probeScreen`, обои для акцента и полный экран основного монитора; если он отключён или не задан, используется первый подключённый экран Quickshell. `Niri.focusedOutput` для этой привязки не используется.

Сервисы, которые оболочка создаёт сама:

- `SettingsService` — настройки
- `WallpaperManager`, `OverviewBlur`, `OverviewRule` — фон и правило обзора
- `AccentExtractor`, два экземпляра `Tokens`, `NiriAccent`, `StrataTheme`
- `MusicService`, `AudioReaction`, `NotificationModel`, `Notifications`
- `ClipboardService`, `WeatherService`
- `SettingsController` — окно настроек
- `SuperTap` — клавиша Super открывает и закрывает меню Пуск

Флаги сессии живут на корневом `Scope` в `surfaces/ShellSession.qml`: `launcherOpened` и `overlayScreen`, `startMenuOutput`, `clipboardOpened`, `settingsController.opened`. Меню Пуск одно на все мониторы. Раскрытый Dynamic Island — свойство `expandedOpened` внутри `ScreenPanels`, у каждого экрана своё.

Связанные закрытия в `surfaces/ShellSession.qml`: Пуск закрывает буфер; лаунчер закрывает буфер; буфер закрывает лаунчер и просит открытый Пуск переключиться; настройки закрывают буфер и лаунчер.

Команды `qs ipc` этого процесса:

| Цель | Функции |
|---|---|
| `canvas` | `closeSettings`, `applyDefault`, `openSettings` |
| `start` | `toggle` |
| `launcher` | `toggle`, `close` |
| `clipboard` | `toggle`, `close` |
| `settings` | `open`, `openPage`, `close` |

Окно Naomi добавляет цель `naomi` (`say`, `trigger`, `triggerValue`, `triggers`). Приём уведомлений, когда он включён, живёт в другом процессе и добавляет цель `notifications`.

## Дерево

```text
shell.qml                 ранний bootstrap
surfaces/ShellSession.qml отложенная основная сессия
tokens/Tokens.qml
tokens/AccentRoles.js
services/niri/             синглтон Niri, акцент, правило обзора
services/settings/         settings.json и история посещений
services/canvas/           обои и размытая копия для обзора
services/palette/          цвет с обоев
services/strata/           файл темы Strata
services/status/           звук, сеть, трей; обычные объекты, не синглтоны
services/system/           сеанс, устройства, чтение конфигурации niri
services/island/           музыка, уведомления, лиса, реакция на звук
services/companion/        логика Naomi
services/clipboard/
services/weather/
services/ui/               маршруты острова, полный экран, автоскрытие
services/Apps.qml          каталог .desktop для одного хозяина
services/launcher/         файлы, папки и команда по префиксу >
islands/workspaces/        левый нижний остров, без своего PanelWindow
islands/apps/              центр
islands/status/            правый остров
islands/shared/            подсказка
surfaces/panel/            сборка экрана
surfaces/island/           Dynamic Island
surfaces/launcher/         строка поиска
surfaces/settings/
surfaces/canvas/
surfaces/companion/
surfaces/clipboard/
```

Единственный QML-синглтон — `Niri` (`services/niri/qmldir`). `NiriAccent`, `OverviewRule`, `StrataTheme` и `SettingsService` оболочка создаёт по одному разу. `Apps`, `Audio` и `Network` создаёт тот экран, которому они нужны: лаунчер, меню Пуск, остров статуса, Dynamic Island, страницы настроек.

`surfaces/launcher/LauncherWindow.qml` описывает полноэкранное окно `nayori-launcher`. `shell.qml` его не создаёт. Живой поиск — строка внутри Dynamic Island (`embedded: true` в `MorphingIsland.qml`) и карточка результатов `nayori-launcher-list`.

## Niri

Клиент в `services/niri/Niri.qml` рассчитан на IPC niri 26.04, как написано в самом файле.

- Путь сокета только из `NIRI_SOCKET`.
- Одно соединение пишет строку `"EventStream"` и читает события. Повтор через 1 с, если сокет пропал. Рукопожатие ждёт 2 с.
- Запросы идут очередью, отдельным коротким соединением, по одному.
- Неизвестное событие состояние не меняет.

Снимок: рабочие столы, окна, `focusedOutput` (выход стола в фокусе), признак перезагрузки конфигурации. Применённые события: `WorkspacesChanged`, `WorkspaceUrgencyChanged`, `WorkspaceActivated`, `WindowsChanged`, `WindowOpenedOrChanged`, `WindowClosed`, `WindowLayoutsChanged`, `WindowFocusChanged`, `ConfigLoaded`.

`FocusWorkspace` и `FocusWindow` вызывают острова по клику. Старт оболочки эти два действия не шлёт. `LoadConfigFile` с `path: null` перечитывает текущий файл. Его вызывает `OverviewRule`, если фрагмент обзора уже подключён, а правило ещё не загружено: один раз за процесс.

Запись конфигурации niri делают три сценария. Все оставляют `noctalia.kdl` как есть.

- `NiriAccent` при `niriColorIntegration` (по умолчанию включено) пишет уже посчитанный акцент во фрагмент `nayori-accent.kdl` рядом с `config.kdl` и подключает фрагмент из `config.kdl`. Путь: `NIRI_CONFIG`, иначе `$XDG_CONFIG_HOME/niri/config.kdl`, а если переменная пуста — `~/.config/niri/config.kdl`.
- `OverviewRule` пишет `nayori-overview.kdl` с `layer-rule` для namespace `nayori-overview` (`place-within-backdrop`). Если строка include уже в файле, а правило ещё не загружено, один раз вызывается `Niri.reloadConfig()`.

Оба скрипта после записи вызывают `niri validate` и при ошибке возвращают прежний текст. Страницы «Экран», «Мышь» и «Клавиатура» пишут в тот же `config.kdl` через `services/system/niri_config_apply.py`, только по кнопке. Старт оболочки этот модуль не вызывает. Перед заменой лежит копия, затем `niri validate -c`. Ошибка проверки или записи возвращает прежний текст. Правка экрана 15 секунд ждёт «Оставить» и сама возвращает копию, если подтверждения нет. Перечитать сессию просит отдельная команда `niri msg action load-config-file`; проверки её не вызывают. `services/system/niri_config_view.py` файл только читает и отдельно спрашивает раскладки командой `niri msg keyboard-layouts`. Выход из сеанса в `SessionActions` идёт командой `niri msg action quit --skip-confirmation`. Эти команды в очередь `Niri.qml` не входят. Горячие клавиши по явному сохранению редактирует `KeybindService` через адаптер Niri и тот же безопасный writer; подробности — [KEYBINDS.md](KEYBINDS.md). Раздел «Клавиатура» по кнопке меняет блок `keyboard`: раскладку, повтор, `track-layout` и `numlock`.

## Токены и акцент

Определение ролей одно: `tokens/Tokens.qml`. В `surfaces/ShellSession.qml` два экземпляра; отдельные лёгкие токены bootstrap задают типографику и анимации splash.

Экземпляр оболочки получает `surfaceStyle`, `animationsEnabled`, акцент и нейтрали. Его читают панели, остров, настройки, буфер и Canvas. В `Launcher.qml` есть запасной `Tokens`, если свойство `tokens` пустое. Живой остров передаёт экземпляр оболочки. Экземпляр Naomi получает `animationsEnabled` и цвет `AccentExtractor`, в том числе при `accentMode: default`. `surfaceStyle` и нейтрали с обоев ему не передаются, поэтому стекло оболочки на Naomi не распространяется. Подробности заливок: [MATERIALS.md](MATERIALS.md).

`AccentExtractor` читает обои `probeScreen`. В режиме `default` токены оболочки оставляют авторские цвета: фон `#121217`, поверхность `#4F4F57`, капсула `#443D4E`, акцент `#C0AFD1`. В `automatic` и `manual` фон и поверхности берутся с обоев, когда извлечение готово и нейтраль найдена. Акцент в `manual` — `manualAccent`. В `automatic` — цвет с обоев, если извлечение готово и запасная лаванда не понадобилась. Иначе остаётся `#C0AFD1`.

При `accentDerived: false` роли акцента авторские: `accent` `#C0AFD1`, `accentSoft` и `accentHover` `#80758C`, `accentText` `#121217`, `accentSoftText` `#F0E9DB`, `accentBorder` `#C0AFD1`. При `true` их считает `tokens/AccentRoles.js` из `accentSource`. Текст `#F0E9DB`, приглушённый текст `#D5CEC4` и роза `#CAA7AA` от картинки не меняются.

`NiriAccent` и `StrataTheme` получают уже посчитанные цвета оболочки. При `strataThemeIntegration` (по умолчанию включено) тема пишется в `$XDG_CONFIG_HOME/strata/themes/nayori.toml`, иначе `~/.config/strata/themes/nayori.toml`. Выбор темы в `settings.toml` скрипт обновляет, пока процесс Strata не запущен.

Остальные роли, как они названы в коде:

| Роль | Значение |
|---|---|
| `color.border`, `color.shadow` | `#57F0E9DB`, `#6B05060A` |
| `spacing.small`, `spacing.medium`, `spacing.large` | 8, 16, 24 |
| `radius.small`, `radius.medium`, `radius.capsule` | 6, 12, 999 |
| `type.display` | Literata, 18 px, насыщенность 500 |
| `type.body`, `type.small` | Inter, 14 px и 13 px, насыщенность 500 |
| `panel.control`, `panel.height`, `panel.padding`, `panel.gap` | 32, 48, 8, 4 |
| `settings.body`, `settings.heading`, `settings.control` | 16, 32, 44 |
| `motion.fast`, `motion.base` | 140 мс, 220 мс |
| `motion.off` | выключенные анимации |

Кривая в токенах не хранится. При `motion.off` декоративный переход либо получает длительность 0, либо не запускается. Переключатель и заливки: [MATERIALS.md](MATERIALS.md).

## Настройки

Файл: `$XDG_CONFIG_HOME/nayori/settings.json`, иначе `~/.config/nayori/settings.json`. Схема версии 1. Сервис читает файл при старте, меняет значения сразу и пишет после паузы 250 мс. Неизвестные ключи сохраняются. Окно настроек — `FloatingWindow`, его создаёт `SettingsController`. Страницы отдают действия сигналами. Запись, восстановление и состав страниц: [SETTINGS.md](SETTINGS.md).

История посещений разделов — `services/settings/SettingsUsage.qml`, файл `$XDG_STATE_HOME/nayori/settings-usage.json` (иначе `~/.local/state/nayori/settings-usage.json`). Её создаёт контроллер настроек. В `settings.json` она не входит.

## Поверхности

`ScreenPanels` на каждом экране собирает нижние острова и верхний Dynamic Island. Нижние компоненты лежат в `islands/` и своего `PanelWindow` не имеют. Окна слоя — в `surfaces/panel/ScreenPanels.qml`.

| Namespace | Окно |
|---|---|
| `nayori-workspaces`, `nayori-apps`, `nayori-status` | три нижних острова, слой Overlay |
| `nayori-edge-top`, `nayori-edge-workspaces`, `nayori-edge-apps`, `nayori-edge-status` | узкие полосы автоскрытия |
| `nayori-island` | Dynamic Island, до 792×662 с ограничением по экрану, верхний край |
| `nayori-launcher-list` | карточка результатов под островом |
| `nayori-launcher-dismiss` | щелчок мимо поиска |
| `nayori-start` | меню Пуск |
| `nayori-reserve-top`, `nayori-reserve-bottom` | `exclusiveZone` под окна |
| `nayori-canvas` | обои, динамическое размытие и затемнение с виджетами, слой Background |
| `nayori-overview` | размытая копия в фоне обзора |
| `nayori-clipboard` | журнал буфера |
| `nayori-companion` | Naomi |

Нижние острова и Dynamic Island стоят с `ExclusionMode.Ignore`. Место у краёв отдаёт `ReservedSpace`. Клавиатуру верхний остров берёт на время поиска (`Exclusive`) и раскрытия (`OnDemand`) и отпускает в покое. Поведение островов, автоскрытие и полный экран: [PANEL.md](PANEL.md). Жест лисы, уведомления и раскладка капсулы: [ISLAND_INTERACTION.md](ISLAND_INTERACTION.md). Музыка и текст песни: [MUSIC_LYRICS.md](MUSIC_LYRICS.md).

Маршрут верхнего острова между мониторами считает `services/ui/IslandRouting.js`. Имя выхода (`screen.name`) связывает снимок niri, обои и перенос острова. Полный экран читает `FullscreenGuard`: один на основной экран в `surfaces/ShellSession.qml`, по одному в `ScreenPanels` и в окне Naomi.

Лаунчер ищет приложения по `DesktopEntries` и запускает `execute()`. Оценка строки живёт в `services/Apps.qml`. Файлы и папки ищет `services/launcher/` в домашней папке и каталогах XDG, вне потока интерфейса. Команда появляется только у запроса с префиксом `>` и запускается списком аргументов, без оболочки. Меню Пуск создаёт свой экземпляр каталога и свой `SessionActions` для блокировки, выхода и питания.

Уведомления рисует остров. Обычный запуск имя `org.freedesktop.Notifications` не занимает. Пока настройка приёма не сохранена, `NAYORI_NOTIFICATIONS=1` поднимает второй процесс `services/island/NotificationHost.qml`. Выбор в разделе «Уведомления» после этого важнее переменной. В том процессе окно `nayori-notify-grab` сохраняет картинку уведомления в PNG. Список, история и прочтение живут в `$XDG_STATE_HOME/nayori/notifications.json`, иначе в `~/.local/state/nayori/notifications.json`. В файл не попадают картинки и действия. Записи старше 90 дней удаляются. Показ, «Не беспокоить» и источники применяет `NotificationPolicy.js`, в том числе к внутренним уведомлениям. Протокол: [ISLAND_INTERACTION.md](ISLAND_INTERACTION.md).

Буфер: сервис в оболочке, окно на экранах, пока журнал открыт. Поведение: [CLIPBOARD.md](CLIPBOARD.md).

## Canvas и обзор

`WallpaperManager` хранит `canvas.json` и выбирает картинку по имени выхода. На каждый экран, пока фон включён, есть `WallpaperWindow` (`nayori-canvas`, `exclusiveZone: 0`, пустая маска ввода). `DesktopBlur` определяет наличие окон активного рабочего пространства этого выхода по EventStream Niri. `StaticRenderer` смешивает обои с готовой копией из `OverviewBlur`; общий слой затемнения в `WallpaperWindow` покрывает также виджеты. Настройки эффекта принадлежат `SettingsService`. Файл, режимы, растворение и слой обзора описаны в [CANVAS.md](CANVAS.md).

Обзор — второе фоновое окно. `OverviewBlur` готовит размытую копию обоев в `$XDG_CACHE_HOME/nayori/overview` (иначе `~/.cache/nayori/overview`), пока Canvas включён. При открытии обзора `OverviewWindow` (`nayori-overview`) показывает её вместе с виджетами. Резкая картинка и виджеты находятся на `nayori-canvas`, который закреплён в backdrop; подложка рабочих столов прозрачна. Прозрачный слой рабочего стола обрабатывает ввод.

## Naomi

Персонаж — окно `surfaces/companion/CompanionWindow.qml`. Оболочка создаёт его через `LazyLoader`, когда настройки прочитаны, Naomi включена и `probeScreen` есть. `exclusiveZone` равен 0. Рисунок, облако и поглаживание: [NAOMI.md](NAOMI.md).

Контракта `Presence` в дереве нет. Капсула и нижние острова место под персонажа не держат.

## Границы

- Поток событий и очередь действий держит `services/niri/Niri.qml`. Острова вызывают `focusWorkspace` и `focusWindow`. `reloadConfig` вызывает `OverviewRule`.
- Страница настроек пишет настройки сигналом. Файл пишет `SettingsService`. Файл обоев пишет `WallpaperManager`.
- Цвет в niri и в Strata уходит после расчёта токенов. Экстрактор обоев эти файлы не пишет.
- `noctalia.kdl` сценарии акцента и обзора не меняют.
- Плагинного хоста и каталога плагинов нет.
- Экран блокировки использует `WlSessionLock` и PAM. `SessionActions` вызывает IPC `lock.lock`; сигналы logind и сон обрабатывает `services/lock/LockService.qml`. Тема SDDM использует тот же `AuthView` и снимок рассчитанных цветов и обоев. Установка — в [LOCKSCREEN.md](LOCKSCREEN.md).


## Подтверждение действий

`PolkitService` в `surfaces/ShellSession.qml` по умолчанию не регистрирует агент: ключ `polkitAgent` выключен. После включения он проверяет имя `org.freedesktop.PolicyKit1.AuthenticationAgent` на шинах и только потом создаёт `Quickshell.Services.Polkit.PolkitAgent`. Регистрация и проверка пароля остаются у polkit и `polkit-agent-helper-1`. Чужой агент не останавливается. Диалог и блокировка используют выбранный основной экран. Подробности — [POLKIT.md](POLKIT.md).

## Bluetooth

`ShellSession` владеет общим `services/system/BluetoothService.qml`: меню `StatusIsland` и страница настроек используют его модель. Динамический `BluetoothBackend.qml` получает состояния через `Quickshell.Bluetooth`; событийный `scripts/bluetooth-bridge.py` на PyGObject/Gio дополняет API результатами операций и агентом сопряжения BlueZ. Состояние не опрашивается внешними командами. Видимость значка хранится в существующем `SettingsService`. Подробности и проверки — [Bluetooth](BLUETOOTH.md).

## Obsidian Quick Capture

`ShellSession` владеет одним `services/quickcapture/QuickCaptureService.qml`: JSON Lines связывает его с локальным Python-worker. Общий черновик передаётся существующей цепочкой ScreenPanels → MorphingIsland → IslandDashboard → ShelfPage → QuickCapture. Настройки проходят через SettingsController/SettingsService; `inbox.open`/`inbox.close` управляют маршрутом и фокусом существующего острова. Контракт хранения и проверки: [QUICK_CAPTURE.md](QUICK_CAPTURE.md).

## Менеджер горячих клавиш

`SettingsController` владеет `services/keybinds/KeybindService.qml`. Python-адаптеры
читают Niri и Kitty, анализируют области действия и конфликты. Запись Niri
делегируется `niri_config_apply.py`; UI держит только черновик. Метаданные
пользовательских биндов находятся рядом с узлом KDL, а не во втором хранилище.
IPC `apps` запускает пять ролей приложений через общий SettingsService и Apps.
Контракт и ограничения: [KEYBINDS.md](KEYBINDS.md).

## Мониторинг системы

Общий `services/system/SystemMonitor.qml` принадлежит `ShellRoot`. Dynamic Island передаёт его четвёртой вкладке «Система», а `SystemReader` виджетов рабочего стола использует адаптер того же снимка. Одна подписка любого экрана включает worker; последняя отписка останавливает его. Лиса использует общий `CpuSampler` без запуска полного worker. Источники, профили питания и ограничения описаны в [SYSTEM_MONITOR.md](SYSTEM_MONITOR.md).

## Экран запуска

`shell.qml` читает `StartupCache`, фиксирует сохранённую палитру, создаёт общий
`StartupState` и Overlay-поверхности `surfaces/startup/StartupWindow.qml` на всех
мониторах. Только после их первого кадра загружается `surfaces/ShellSession.qml`. Они ждут настроек,
палитры, Niri и первых кадров обоев, панелей и Dynamic Island; после затухания
поверхности удаляются. Прежняя `SessionEntrance` при запуске не подключена.
Условия готовности, ошибки и ограничения: [STARTUP_SPLASH.md](STARTUP_SPLASH.md).


## Desktop Visualizer

Одна `VisualizerService` в основной сессии использует SettingsService
(`desktopVisualizers`) и выбор StageSession. `VisualizerLayer` находится внутри
Canvas, фона Overview и уменьшенной сцены существующего редактора. Оригинальные
SpectrumField/AuraField и шейдеры Ryoku отделены от настроек и ввода. Системная
подписка `AudioReaction.systemConsumer` держит общий монитор выхода независимо
от MPRIS. Состав, лицензии, протокол и ограничения: [VISUALIZERS.md](VISUALIZERS.md).
