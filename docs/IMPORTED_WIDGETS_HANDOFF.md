# Продолжение переноса — 12 ноября 2026

Предыдущая сохранённая точка: `87464b8` — `wip: port Ryoku widgets and rework desktop editor`.
После команды пользователя «Продолжай» дописана последняя группа из 20 адаптеров.
Нового коммита пользователь не просил; изменения остаются в рабочем дереве.

## Ограничения

- Тесты только в CI. Локальные тесты, lint, qmllint, рендеринг и запуск оболочки не выполнялись.
- Не запускать installer apply, действия питания, конкурирующую оболочку; не менять активные конфиги Ryoku/Niri.
- Сначала читать git status и AGENTS.md. Не запускать старые генераторы из /tmp поверх ручных правок.
- Подагенты текущими инструкциями не разрешены.

## Состояние

В каталоге 103 адаптера: ii 46, Shima 25, Python 32. Все записи Shima/Python
из закреплённого upstream-реестра реализованы. Осталось 60 ii и один алиас даты,
который не считается отдельным компонентом. `ported` означает реализацию,
не успешную проверку: выполнение CI и визуальная проверка ещё не подтверждены.

Последняя группа Shima: mediaControls, controls, todo, notes, timers, screenTime,
worldClock, userCard, newsTicker, customImage, editorial, imageConverter,
japaneseTypography, visualizer, shape, organicEdge.
Python: UserFace, NotesFace, MusicFaceLyrics, GithubFace.

## Изменения при продолжении

- Параметры задач/заметок/таймеров сохраняются через SettingsService на экземпляр.
- Общий ImportedWidgetRuntime передаёт реальные данные; token поколения отклоняет
  запоздалые ответы. Скрытые/удалённые экземпляры освобождают подписки и запросы.
- Учёт foreground-времени opt-in, с исключением idle; таймеры продолжают фазы по
  сохранённым timestamp и отправляют уведомления через существующую модель.
- GitHub использует реальные contributions, очищает данные при сбросе username,
  явный refresh обходит общий кэш. RSS/Atom, zoneinfo, локальные LRC/TXT и конвертация
  идут через один Python worker. Конвертация не перезаписывает существующие файлы.
- Яркость/nightlight/EasyEffects зависят от optional утилит; недоступные действия
  отключены. Network наблюдает только при наличии потребителей. Выбор изображения
  адаптирован на Qt FileDialog вместо обязательного Zenity.
- Удалены неиспользуемые общие стили Shima. Динамические цвета сохраняют explicit false.
- Геометрия Shima учитывает widgetScale и размеры оригинальных canvas.

## Нативный painter

Оригинальный CavaSpectrumPainter из `ryoku/shell/plugin/cavaspectrum.{cpp,hpp}`
не установлен как Ryoku.Blobs. Скопирован неизменённым из закреплённой ревизии
`2befae30e0e1e8d370a8fdb4489e84be529af1bd` в vendor/widgets/native с GPLv3.
Добавлен локальный QQmlExtensionPlugin и импорт Native.CavaSpectrumPainter.
`python3 scripts/build-widget-renderer.py` выполнен успешно: это сборка production
модуля, не тест и не запуск QML. .so игнорируется Git; исходники и qmltypes в дереве.
После смены ABI Qt пересобрать. CI собирает до проверок; installer собирает в stage
до хеширования/публикации, при ошибке текущий релиз не переключается.

## Проверки для CI

- tests/imported-widget-worker.py: mock RSS/Atom/GitHub, zones, lyrics, cache/refresh,
  конвертация, ошибки, timeout, гонка публикации, токены ответов; без реальной сети/команд.
- tests/smoke/WidgetRuntimeSmoke.qml: реальные методы runtime в testMode, stale reply,
  удаление, capabilities, завершение countdown, переход фокуса, безопасная маршрутизация.
- ImportedWidgetsSmoke.qml: весь каталог через mock runtime, CRUD задач, заметки,
  таймеры, данные, конвертер success/failure, освобождение подписок.
- imported-widgets.cjs: полный Shima/Python, геометрия, JSON-параметры и хеши исходников.
- installer.py: ошибка сборки не публикует версию, артефакт включается в manifest.
- Регрессии сетки/редактора из предыдущего этапа остаются для CI.

## Существовавшие правки пользователя

До продолжения уже были изменения GiB/MiB в docs/WIDGETS.md, WidgetLayout.js,
DesktopWidgetContentSmoke.qml, widget-layout.cjs. Они сохранены; в WidgetLayout
дополнительно подключён naturalBox для Shima. Другие новые изменения не откатывать.

## Дальше

Дождаться CI и исправить реальные сообщения о загрузке/поведении. Тесты локально
не запускать без отмены запрета. В изолированной разрешённой сессии ещё нужны
проверки ввода, GPU-эффектов и визуального совпадения. Пословная разметка lyrics и
пространственное извлечение яркости обоев остаются документированными ограничениями.
Оставшиеся ii — отдельный следующий объём, пользователь в последней команде просил
закончить Shima/Python.
