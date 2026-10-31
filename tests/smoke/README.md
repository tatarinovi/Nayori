# Smoke-стенды

Все отдельные QML-конфигурации для проверки Nayori собраны здесь. Запускайте конкретный файл из корня репозитория, например:

```sh
qs -p tests/smoke/IslandBehaviorSmoke.qml
bash scripts/check-island.sh
bash scripts/check-music.sh
bash scripts/check-canvas.sh
qs -p tests/smoke/ClipboardSmoke.qml
```

Quickshell ограничивает импорты каталогом конфигурации. Ссылки `tokens`, `services`, `surfaces`, `islands`, `assets`, `scripts` и `RealShell.qml` открывают стендам общие исходники и ресурсы без копирования. Ссылки `fake-audio.py` и `fake-lyrics-worker.py` ведут к искусственным источникам в `tests/`. Сохраняйте эти относительные ссылки при переносе репозитория. `RealShell.qml` используется только для проверки настоящей корневой конфигурации; для запуска стенда всегда указывайте его файл явно.

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
