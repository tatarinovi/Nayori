# AGENTS.md — Nayori

## Контекст и архитектура

- Nayori — самостоятельная оболочка Quickshell/QML для Niri/Wayland, не compositor и не полноценная DE. Точка входа `shell.qml` собирает сервисы и состояние сессии; сборка перед запуском не нужна. Сначала проверь существующий код, `docs/ARCHITECTURE.md` и профильный документ в `docs/`: roadmap может отставать.
- `services/` владеет данными и системными действиями; `surfaces/` и `islands/` отображают состояние. Используй существующие `services/niri/Niri.qml` (EventStream и очередь IPC), `SettingsService`, `WallpaperManager` и роли `tokens/Tokens.qml`, не создавая второй источник истины. Не все сервисы — singleton.
- Основной ввод лаунчера встроен в верхний Dynamic Island; `surfaces/launcher/LauncherWindow.qml` не является живой точкой входа. Нижние острова собираются на каждый экран в `surfaces/panel/ScreenPanels.qml`. Сохраняй компактный стиль, фокус/Escape, per-monitor настройки и отключение анимаций.
- Настройки — `$XDG_CONFIG_HOME/nayori/settings.json`, обои — отдельный `canvas.json`. Сохраняй неизвестные ключи и совместимость схемы; настройки пишет `SettingsService`, а не UI. Состояние сессии не является настройками.
- Naomi опциональна; не меняй её согласованный спрайт без задачи на редизайн. Не копируй GPL/AGPL-код или ресурсы angelOS; проверяй лицензии заимствований.

## Безопасность рабочей сессии

- Перед правками проверь `git status --short`; не перезаписывай чужие изменения. Без явного разрешения не изменяй активные конфиги Niri и других оболочек, SDDM/PAM/polkit/systemd, не устанавливай пакеты, не запускай реальное применение установщика, logout/reboot и не останавливай чужие процессы.
- Обычный запуск Nayori сам может записать фрагменты `nayori-accent.kdl`, `nayori-overview.kdl`, include в конфиг Niri и тему Strata. Не запускай конкурирующую оболочку или демон уведомлений ради теста. Существующие интеграции не отключай и не расширяй их запись без согласования.
- Изменения Niri-конфига должны сохранять копию, применяться атомарно, проходить `niri validate -c` и откатываться при ошибке; изменения экранов требуют подтверждения с автоматическим возвратом. Тестируй на фикстурах и mock-командах, не применяя конфигурацию к живой сессии.
- Для диагностики Quickshell всегда указывай абсолютный путь: `qs list -p "$(pwd -P)"`; IPC: `qs ipc -p "$(pwd -P)" call launcher toggle`. `qs -p "$(pwd -P)" -n` не делает конкурентный запуск безопасным. Не захватывай занятое имя `org.freedesktop.Notifications` и не выполняй `qs kill` без проверки и разрешения.
- `install.sh` — Bash-bootstrap для Python/gum TUI, а не Python/Textual. `./install.sh --dry-run` и `--diagnose` требуют Arch/pacman, интерактивный терминал и уже установленные Python/gum; тесты не должны выполнять настоящий installer apply.

## Проверки

Из корня репозитория после изменений запускай:

```bash
git diff --check
bash scripts/ci-lint.sh
bash scripts/ci-tests.sh unit
dbus-run-session -- bash scripts/ci-tests.sh smoke
```

- CI-зависимости перечислены в `.github/workflows/ci.yml`; CI запускает тесты непривилегированным пользователем (есть проверки отказа доступа). Линтер использует `/usr/lib/qt6/bin/qmllint` с отключёнными `missing-property` и `uncreatable-type` из-за неполных Quickshell qmltypes.
- Для узкой проверки запускай конкретный тест, например `node tests/monitor-layout.cjs`, `python3 tests/niri-config-apply.py` или `bash scripts/check-island.sh`. Полный состав наборов — `scripts/ci-tests.sh`; отдельные QML-стенды и их особенности — `tests/smoke/README.md`. Относительные symlink в `tests/smoke/` нужны для импортов Quickshell.
- Smoke-набор отключает Wayland/Niri, использует offscreen Qt, временные XDG-каталоги и отдельную D-Bus-сессию. Он не проверяет физический ввод, layer-shell, несколько реальных мониторов или GPU-blur. Живые Wayland-проверки и тесты с системными побочными эффектами проводи только изолированно и с разрешения.
- При изменении поведения обнови профильный документ в `docs/`, добавь регрессионные тесты, включая сбойный сценарий; в итоговом отчёте укажи выполненные команды и непроверенные ограничения.
