# Дорожная карта

Карта текущего дерева. Корень `shell.qml` собирает рабочую оболочку: панели на каждом экране, Dynamic Island, обои, настройки и связанные сервисы. Подробности поверхностей лежат в своих документах, здесь только состав и дыры.

[Архитектура](ARCHITECTURE.md) описывает текущий `shell.qml`: каталогов `state/` и `character/` в ней нет. Дальше по дереву:

- [Панель и Dynamic Island](PANEL.md)
- [Лиса и уведомления](ISLAND_INTERACTION.md)
- [Музыка и тексты](MUSIC_LYRICS.md)
- [Настройки](SETTINGS.md)
- [Материалы](MATERIALS.md)
- [Canvas](CANVAS.md)
- [Буфер обмена](CLIPBOARD.md)
- [Naomi](NAOMI.md)
- [Naomi v3](NAOMI_SPRITE.md)
- [Аудит angelOS](ANGELOS_AUDIT.md)

Пометки те же. **Подтверждено** — сверено с файлом. **Предположение** — вывод, которого код прямо не записывает. **Рекомендация** — правило работы, не утверждённая фаза. **Не проверено** — этим проходом не смотрелось.

## Как устроена работа рядом с живой сессией

**Подтверждено.** Quickshell 0.3.2, справка `qs` и `qs kill` от 27 октября 2026.

- Каталог с `shell.qml` запускается как `qs -p <путь>`. Флаг `-n` выходит сразу, если такой путь уже запущен
- Список этого пути: `qs list -p <путь>`
- Остановка этого пути: `qs kill -p <путь>` или `qs kill --pid <pid>` с pid из списка
- Без `-p`, `-c`, `--pid` или `-i` справка выбирает конфиг `default`. Каталог `~/.config/quickshell` пуст, своего `shell.qml` там нет. Команда `qs kill` без этих флагов путь Nayori не выбирает

Команды этой копии:

```sh
qs -p /home/katamy/Projects/nayori -n
qs list -p /home/katamy/Projects/nayori
qs kill -p /home/katamy/Projects/nayori
```

**Подтверждено.** Автозапуск прочитан из `~/.config/niri/cfg/autostart.kdl`, строка 4. Репозиторий этот файл не содержит.

```
spawn-at-startup "env" "NAYORI_NOTIFICATIONS=1" "qs" "-p" "/home/katamy/Projects/nayori"
```

Строки `spawn-at-startup "noctalia"` в файле нет.

**Подтверждено.** Запущенная оболочка сама пишет два фрагмента рядом с `config.kdl` и добавляет `include`. `services/niri/niri_accent.py` кладёт акцент в `nayori-accent.kdl` и не трогает `noctalia.kdl`. `services/niri/niri_overview.py` кладёт правило фона обзора в `nayori-overview.kdl`. Если niri не принимает текст, прежний `config.kdl` возвращается из памяти. Оба выключателя стоят на странице «Интеграции»; в `services/settings/SettingsService.qml` по умолчанию `niriColorIntegration` и `strataThemeIntegration` равны true. Тема Strata пишется в `~/.config/strata/themes/nayori.toml` (`services/strata/StrataTheme.qml`).

В живом `~/.config/niri/config.kdl` сейчас стоят такие строки:

```
include "nayori-accent.kdl"
include "nayori-overview.kdl"

include "noctalia.kdl"
include "nayori-accent.kdl"
```

**Подтверждено.** Страница «Автозапуск» через `services/system/autostart_tool.py` меняет пользовательские `.desktop` в `$XDG_CONFIG_HOME/autostart`. Системные файлы скрипт не удаляет. Строку `spawn-at-startup` niri эта страница не пишет.

**Рекомендация.** Без отдельного согласия не редактировать `~/.config/niri`, `~/.config/noctalia`, greetd, автозапуск niri и пользовательские службы. Не ставить и не снимать пакеты. Не вызывать `qs kill` без `-p` или `--pid`, полученного из `qs list -p`. Фрагменты акцента и обзора пишет сама оболочка. Ручная правка остального KDL к этому не добавляется.

**Не проверено.** Запущен ли сейчас процесс Nayori или Noctalia: `qs list` из этой среды не открыл `/run/user/1000/quickshell`. Файл greetd не читался. В `~/.config/niri/cfg/keybinds.kdl` клавиши громкости и яркости по-прежнему вызывают `qs -c noctalia-shell`. Это конфиг сессии, не дерево репозитория.

## Что лежит в дереве

**Подтверждено.** В корне есть `.git`. Отдельного `LICENSE` нет.

### Панель, Пуск, лаунчер, остров

`shell.qml` строит `surfaces/panel/ScreenPanels.qml` через `Variants` по `Quickshell.screens`. Имя `probeScreen` в `shell.qml` — первый экран списка, `Quickshell.screens[0]`.

Нижние острова остались в `islands/` и подключены из `ScreenPanels.qml`:

- Рабочие столы: `islands/workspaces/WorkspacesIsland.qml`, namespace `nayori-workspaces`
- Окна: `islands/apps/AppsIsland.qml`, namespace `nayori-apps`
- Трей, сеть и звук: `islands/status/StatusIsland.qml`, namespace `nayori-status`

Часы стоят в верхнем острове. Верхний остров — `surfaces/island/`, namespace `nayori-island`: часы, лиса (`surfaces/island/Fox.qml`, `FoxSprite.js`), музыка, погода, уведомления. Поведение — в [ISLAND_INTERACTION.md](ISLAND_INTERACTION.md) и [MUSIC_LYRICS.md](MUSIC_LYRICS.md). [PANEL.md](PANEL.md) описывает тот же спрайт `FoxSprite.js`.

Меню «Пуск» — `surfaces/panel/StartMenu.qml`, namespace `nayori-start`. Короткое нажатие Super читает `services/system/SuperTap.qml`. IPC: `qs ipc -p /home/katamy/Projects/nayori call start toggle`.

Лаунчер — `surfaces/launcher/`, каталог ярлыков `services/Apps.qml`. Открытие: `qs ipc -p /home/katamy/Projects/nayori call launcher toggle`. Оценка строки своя, запуск — `DesktopEntry.execute()`.

Видимые острова: слой Overlay, `ExclusionMode.Ignore`, свой `exclusiveZone` не задают. Место для окон задаёт отдельная прозрачная полоса `surfaces/settings/ReservedSpace.qml`: `exclusiveZone` равен отступу, namespace `nayori-reserve-top` и `nayori-reserve-bottom`. В `SettingsService.qml` отступы по умолчанию 0, и при нуле полоса скрыта (`visible: amount > 0`).

Макет, автоскрытие и мониторы — в [PANEL.md](PANEL.md).

### Настройки, токены, материалы

Настройки — `services/settings/SettingsService.qml` и окно `surfaces/settings/`. Файл `$XDG_CONFIG_HOME/nayori/settings.json`, иначе `~/.config/nayori/settings.json`. Каталога `state/` нет. Синглтона `Session` нет: открытые лаунчер, буфер и меню лежат свойствами `shell.qml`. Из терминала окно открывает `scripts/nayori-settings`.

Страницы звука, сети, Bluetooth и питания вызывают `services/system/` и модули Quickshell. Отдельной поверхности `surfaces/control/` нет. Флага «не беспокоить» в коде нет.

Токены — `tokens/Tokens.qml` и `tokens/AccentRoles.js`. В файле графит, лаванда `#C0AFD1`, пыльная роза, семейства Literata и Inter. Комментарий у `color.surface` всё ещё содержит слово «заглушки». Файлов шрифтов в репозитории нет. Акцент с обоев первого экрана считает `services/palette/AccentExtractor.qml`. Материалы Solid и Frosted Glass — в [MATERIALS.md](MATERIALS.md).

Хранение и страницы — в [SETTINGS.md](SETTINGS.md).

### Canvas, буфер, Naomi

Обои — `services/canvas/WallpaperManager.qml` и `surfaces/canvas/WallpaperWindow.qml`, namespace `nayori-canvas`, файл `canvas.json`. Контракт статической картинки — в [CANVAS.md](CANVAS.md).

Размытый фон обзора уже подключён в `shell.qml`: `services/canvas/OverviewBlur.qml`, `surfaces/canvas/OverviewWindow.qml`, namespace `nayori-overview`. Окно появляется, когда `OverviewRule.ruleLive`. Раздел «Обзор» в [CANVAS.md](CANVAS.md) описывает ту же размытую копию и include `nayori-overview.kdl`.

Журнал буфера — `services/clipboard/` и `surfaces/clipboard/`, namespace `nayori-clipboard`. История в `$XDG_STATE_HOME/nayori/clipboard`. Открытие и бинд — в [CLIPBOARD.md](CLIPBOARD.md).

Naomi — `surfaces/companion/`, окно `nayori-companion`. В настройках `companionEnabled` по умолчанию false. Облако, поглаживание и системные реплики — в [NAOMI.md](NAOMI.md). Облик `companionStyle: "layered"` — `surfaces/companion/NaomiSprite.qml` и [NAOMI_SPRITE.md](NAOMI_SPRITE.md). Файл `naomi-sprite-demo.qml` в корне запускается отдельно и в `shell.qml` не входит. `character/Presence.qml` нет.

### Niri и уведомления

`services/niri/Niri.qml` открывает `NIRI_SOCKET` и читает события. Клик по столу и окну шлёт фокус. Старт оболочки эти вызовы не делает.

Уведомления — `services/island/Notifications.qml`. Пока в настройках нет выбора, приём включается при `NAYORI_NOTIFICATIONS=1` на запуске. Сохранённый переключатель важнее переменной. Если имя D-Bus занято, процесс его не отбирает. Журнал живёт в памяти процесса: в `services/island/` записи в файл нет. Показ, «Не беспокоить» и источники описаны в [ISLAND_INTERACTION.md](ISLAND_INTERACTION.md) и [SETTINGS.md](SETTINGS.md).

Погода — один `services/weather/WeatherService.qml` на оболочку. Город и интервал лежат в `settings.json`.

Проверки лежат в `tests/` и `scripts/`. Список команд — в [README.md](../README.md), здесь он не повторён.

## Что закрыто не до конца

**Подтверждено.**

- Лаунчер ищет ярлыки `DesktopEntries` (`services/Apps.qml`) и добавляет строку поиска в интернете (`surfaces/launcher/Launcher.qml`, URL Google). Плейсхолдер поля говорит «Найти приложения, файлы, команды…». Индекса файлов и команд в `SearchResults.qml` нет. То же сказано в [PANEL.md](PANEL.md)
- `surfaces/settings/DisplayPage.qml`, `MousePage.qml`, `KeyboardPage.qml` и `ShortcutsPage.qml` читают сессию и прямо пишут: безопасная перезапись конфигурации niri с откатом не сделана
- `WindowsPage.qml` умеет перевести фокус на окно. Правила окон, рамки и зазоры страница не пишет. `AltTabPage.qml` показывает сочетания с Tab и не даёт их менять. `WorkspacesPage.qml` переходит на уже существующий стол и число столов не меняет
- `LockScreenPage.qml`: добавлены предпросмотр и собственная блокировка Wayland/PAM. Страница «Питание» вызывает IPC `lock.lock`. Экран входа поставляется отдельной темой SDDM; подключение описано в [LOCKSCREEN.md](LOCKSCREEN.md). Агента polkit в дереве нет. Строка `"polkit"` в `services/island/NotificationSources.js` — имя источника уведомления
- `LocalSendPage.qml` ищет установленное приложение и запускает его. Своего протокола передачи в дереве нет
- Конец [CANVAS.md](CANVAS.md) оставляет ручные проверки диалога, двух мониторов, отключения выхода и кликов по рабочему столу. Этим проходом они не повторялись

**Предположение.** Живое обтекание окон при ненулевом `topReserved` или `bottomReserved` код задаёт через `ReservedSpace.qml`. Смотрелся исходник, не сессия с отступом больше нуля.

## Чего в дереве нет

Прежняя карта описывала фазы до пробного окна и панели v0.1. Этих путей нет, и нумерованные фазы 0–9 текущим кодом не продолжаются.

- `state/Settings.qml`, `state/Session.qml`, `state/Niri.qml`
- namespace `nayori-probe-island`, `nayori-probe-workspaces`, `nayori-probe-apps`, `nayori-probe-status`
- `surfaces/control/`, `surfaces/desktop/`, `character/Presence.qml`
- Снимок `/tmp/nayori-bar-v01.png` как описание текущего низа. Часы стоят в верхнем острове, трей остаётся в `islands/status/`

[ARCHITECTURE.md](ARCHITECTURE.md) описывает уведомления как приём без захвата чужого имени: переменная действует, пока пользователь не выбрал приём в настройках. Там же описан собственный экран блокировки Wayland/PAM с отдельной темой SDDM.

## Что еще не закрыто

Это дыры, которые уже названы кодом или документом. Очередь из них не утверждена.

**Подтверждено.**

- Безопасная перезапись режимов экрана, мыши, клавиатуры и сочетаний niri с откатом. Четыре страницы настроек пишут, что её нет. Узкая запись `nayori-accent.kdl` и `nayori-overview.kdl` к этому не относится: она уже есть и откатывает только свой `include`
- Поиск файлов и команд в лаунчере. Плейсхолдер его обещает, каталог `services/Apps.qml` читает только ярлыки

**Рекомендация.** Не брать эти два пункта в работу без отдельного согласия. Ручной список в конце [CANVAS.md](CANVAS.md) и раздел «Контракт рендерера и v0.2» там же описывают проверки и будущий вид фона. v0.2 в дереве нет: рендерер v0.1 принимает статическую картинку.

## Лицензионные ворота

Ворота стоят перед любой вставкой чужого кода, включая «маленький кусок на вечер». Аудит отсылает сюда: [ANGELOS_AUDIT.md](ANGELOS_AUDIT.md).

1. Есть путь файла в конкретном коммите и имя проекта.
2. Лицензия прочитана по файлу `LICENSE`, `THIRD-PARTY.md` или заголовку. «В репозитории вроде MIT» воротами не считается.
3. Для MIT, ISC и Apache в репозитории Nayori сохраняется уведомление об авторском праве.
4. GPL-3.0 и AGPL-3.0 из клона angelOS (тема SDDM, тема Spicetify) в Nayori не попадают.
5. CC BY 4.0 берётся только вместе с атрибуцией и отдельным согласием. Сейчас такие иконки не нужны.
6. Файл из раздела «Unclear» в `THIRD-PARTY.md` не берётся.
7. Кусок длиннее пары строк копируется только если своя запись этой мысли заметно длиннее и хуже. По умолчанию приём пишется заново.
8. Noctalia этим аудитом не разбиралась. Её код теми же воротами не открыт.

Шрифт, иконка и иллюстрация проходят те же ворота, даже если это «просто ресурс». Своего `LICENSE` в корне Nayori нет: ворота про чужой фрагмент от этого не снимаются.
