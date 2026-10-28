#!/usr/bin/env python3
"""Russian Textual wizard. No writes until the user applies the reviewed plan."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path
import sys

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts.installer.core import (
    CATALOG,
    Engine,
    InstallError,
    deselect_component,
    resolve_components,
)
from textual import on, work
from textual.theme import Theme
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical, VerticalScroll
from textual.widgets import (
    Button,
    Checkbox,
    Footer,
    Header,
    Input,
    Label,
    RichLog,
    SelectionList,
    Static,
)


class InstallerApp(App):
    TITLE = "NAYORI / установка"
    SUB_TITLE = "в твоём ритме"
    CSS = """
    Screen { background: #121217; color: #f0e9db; }
    Header { background: #443d4e; color: #c0afd1; }
    Footer { background: #443d4e; }
    #banner { height: 4; padding: 1 2; color: #c0afd1; text-style: bold; }
    #body { height: 1fr; padding: 0 2; }
    #categories { width: 22; padding-right: 1; }
    .category { width: 100%; margin-bottom: 1; }
    #center { width: 1fr; }
    #description { overflow-y: auto; width: 28; border: round #80758c; padding: 1; margin-left: 1; }
    SelectionList { height: 1fr; border: round #80758c; }
    Input { border: round #80758c; }
    Button { background: #443d4e; border: none; color: #f0e9db; }
    Button:hover, Button:focus { background: #80758c; }
    Button.-primary { background: #c0afd1; color: #121217; }
    #nav Button { min-width: 8; width: auto; padding: 0 1; }
    #nav { height: 3; padding: 0 2; align-horizontal: right; }
    #counter { width: 1fr; padding: 1 0; color: #c0afd1; }
    #review { height: 1fr; }
    #review-text { height: auto; padding: 1; }
    #log { border: round #80758c; height: 1fr; }
    #notice { color: #d5cec4; padding: 1; }
    #export-path { display: none; }
    .hidden { display: none; }
    Screen.compact #body { padding: 0 1; }
    Screen.compact #body { layout: vertical; }
    Screen.compact #categories { width: 100%; height: 2; layout: horizontal; overflow-x: auto; }
    Screen.compact .category { width: auto; min-width: 12; margin: 0 1 0 0; }
    Screen.compact #description { width: 100%; height: 4; margin: 0; padding: 0 1; }
    Screen.compact #center { width: 100%; height: 1fr; }
    Screen.compact #banner { height: 2; padding: 0 1; }
    Screen.compact #notice { height: 1; padding: 0 1; }
    Screen.compact #nav { height: 2; padding: 0 1; }
    """
    BINDINGS = [
        ("q", "quit_safe", "Выход"),
        ("escape", "back", "Назад"),
        ("ctrl+d", "diagnose", "Диагностика"),
        ("ctrl+c", "cancel_install", "Остановить"),
    ]
    steps = [
        "Добро пожаловать",
        "Компоненты",
        "Приложения",
        "Интеграции",
        "Проверка плана",
        "Установка",
        "Результат",
    ]

    def __init__(self, dry_run=False, diagnose=False, engine=None):
        super().__init__()
        self.register_theme(
            Theme(
                name="nayori",
                primary="#c0afd1",
                secondary="#80758c",
                accent="#c0afd1",
                background="#121217",
                foreground="#f0e9db",
                surface="#1f1c25",
                panel="#443d4e",
                success="#b9c9b0",
                warning="#dec594",
                error="#e8a4b2",
            )
        )
        self.theme = "nayori"
        self.dry_run = dry_run
        self.start_diagnose = diagnose
        self.engine = engine or Engine()
        self.engine.runner.interactive = self.interactive
        self.engine.log = self.log_message
        self.components = set()
        self.apps = set()
        self.step = 0
        self.category = "Системные"
        self.refreshing = False
        self.displayed = set()
        self.plan = None
        self.running = False
        self.diagnostic_mode = False
        self.report = []
        self.installed_packages = set()

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("", id="banner")
        with Horizontal(id="body"):
            with VerticalScroll(id="categories"):
                for index, category in enumerate(
                    dict.fromkeys(a["category"] for a in CATALOG["apps"].values())
                ):
                    yield Button(category, id=f"category-{index}", classes="category")
            with Vertical(id="center"):
                yield Input(placeholder="Поиск приложений…", id="search")
                yield SelectionList(id="choices")
                with VerticalScroll(id="review"):
                    yield Static("", id="review-text", markup=False)
                yield Checkbox("Полное обновление системы: pacman -Syu", id="update")
                yield Checkbox(
                    "Сохранить изменённые файлы в бэкап и заменить", id="overwrite"
                )
                yield Checkbox(
                    "План проверен. Применить выбранные изменения", id="approve"
                )
                yield Input(
                    placeholder="Абсолютный путь отчёта .json", id="export-path"
                )
                yield RichLog(id="log", wrap=True, markup=False)
            yield Static("", id="description", markup=False)
        yield Static("", id="notice")
        with Horizontal(id="nav"):
            yield Label("", id="counter")
            yield Button("Назад", id="back")
            yield Button("Диагностика", id="diagnose")
            yield Button("Далее", id="next", variant="primary")
        yield Footer()

    def on_mount(self):
        self.on_resize()
        self.render_step()
        self.load_package_status()
        if self.start_diagnose:
            self.action_diagnose()

    @work(group="package-status")
    async def load_package_status(self):
        code, output = await asyncio.to_thread(
            self.engine.runner.capture, ["pacman", "-Qq"]
        )
        if not code:
            self.installed_packages = set(output.splitlines())
            if self.step == 2 and not self.diagnostic_mode:
                self.fill_choices()

    def on_resize(self, event=None):
        self.screen.set_class(self.size.width < 110, "compact")
        if self.is_mounted and (self.size.width < 80 or self.size.height < 24):
            self.query_one("#notice", Static).update(
                "Увеличьте терминал до 80×24 для продолжения."
            )
            self.query_one("#next", Button).disabled = True

    def show(self, identifier, visible):
        self.query_one("#" + identifier).display = visible

    def render_step(self):
        self.diagnostic_mode = False
        self.query_one("#banner", Static).update(
            f"{self.step + 1:02d} / 07   {self.steps[self.step]}"
            + ("  ·  ПРОСМОТР" if self.dry_run else "")
        )
        selection = self.step in (1, 2, 3)
        for identifier in ("choices", "description"):
            self.show(identifier, selection)
        for identifier in ("categories", "search"):
            self.show(identifier, self.step == 2)
        self.show("review", self.step in (0, 4, 6))
        self.show("log", self.step in (5, 6))
        for identifier in ("update", "overwrite", "approve"):
            self.show(identifier, self.step == 4 and not self.dry_run)
        self.show("export-path", False)
        self.query_one("#back", Button).disabled = self.step in (0, 5)
        self.query_one("#next", Button).disabled = self.step == 5
        self.query_one("#diagnose", Button).disabled = self.running
        self.query_one("#next", Button).label = (
            ("Показать план" if self.dry_run else "Установить")
            if self.step == 4
            else ("Закрыть" if self.step == 6 else "Далее")
        )
        self.query_one("#notice", Static).update(
            "Tab — переход · Space — выбор · Esc — назад. Все дополнительные компоненты выключены."
        )
        if selection:
            self.fill_choices()
        if self.step == 0:
            self.query_one("#review-text", Static).update(
                "NAYORI\n\nЛичная оболочка Linux. Установка в твоём ритме.\n\n"
                "Выберите компоненты и приложения. Перед установкой будет показан полный план.\n"
                "Конфиги niri подготавливаются отдельно и проверяются до замены.\n"
                "Предыдущая версия оболочки и существующие файлы сохраняются.\n\n"
                "Пакеты устанавливаются через pacman и существующий paru/yay.\n"
                "Службы, текущая сессия и другие оболочки автоматически не переключаются.\n\n"
                "Диагностика доступна по Ctrl+D. Восстановление и откат — на экране диагностики."
            )
        elif self.step == 4:
            self.query_one("#approve", Checkbox).value = False
            self.query_one("#overwrite", Checkbox).value = False
            self.query_one("#review-text", Static).update(
                "Проверка пакетов и текущей установки…"
            )
            self.query_one("#next", Button).disabled = True
            self.prepare_plan()
        self.update_count()

    def fill_choices(self):
        choices = self.query_one("#choices", SelectionList)
        self.refreshing = True
        choices.clear_options()
        search = self.query_one("#search", Input).value.casefold()
        items = []
        if self.step == 2:
            for key, value in CATALOG["apps"].items():
                if (
                    value["category"] == self.category
                    and search in (value["label"] + key).casefold()
                ):
                    items.append(
                        (
                            value["label"]
                            + (
                                " · установлен"
                                if key in self.installed_packages
                                else ""
                            )
                            + (" · AUR" if value["source"] == "aur" else ""),
                            key,
                            key in self.apps,
                        )
                    )
        else:
            for key, value in CATALOG["components"].items():
                if (key in ("nayori", "niri")) == (self.step == 1):
                    items.append((value["label"], key, key in self.components))
        self.displayed = {item[1] for item in items}
        choices.add_options(items)
        if items:
            choices.highlighted = 0
        self.refreshing = False
        self.describe()

    @on(SelectionList.SelectionHighlighted)
    def describe(self, event=None):
        choices = self.query_one("#choices", SelectionList)
        if choices.highlighted is None or not choices.option_count:
            return
        key = choices.get_option_at_index(choices.highlighted).value
        item = (CATALOG["apps"] if self.step == 2 else CATALOG["components"])[key]
        description = item["description"]
        if item.get("requires"):
            description += "\n\nТребует: " + ", ".join(
                CATALOG["components"][dep]["label"] for dep in item["requires"]
            )
        description += "\n\nПакеты: " + ", ".join(item.get("packages", []))
        self.query_one("#description", Static).update(description)

    @on(SelectionList.SelectionToggled)
    def toggle(self, event):
        if self.refreshing:
            return
        chosen = set(self.query_one("#choices", SelectionList).selected)
        if self.step == 2:
            self.apps = (self.apps - self.displayed) | chosen
        else:
            previous = set(self.components)
            before = self.components & self.displayed
            removed = before - chosen
            updated = set(self.components)
            for key in removed:
                updated = deselect_component(updated, key)
            updated.update(chosen - before)
            try:
                self.components = resolve_components(updated)
            except InstallError as error:
                self.notify(str(error), severity="error")
            self.fill_choices()
            added = self.components - updated
            if added:
                self.notify("Добавлены зависимости: " + ", ".join(sorted(added)))
            removed_dependents = previous - self.components - removed
            if removed and removed_dependents:
                self.notify("Связанные компоненты сняты вместе с зависимостью")
        self.update_count()

    def update_count(self):
        self.query_one("#counter", Label).update(
            f"Компонентов: {len(self.components)} · приложений: {len(self.apps)}"
        )

    @on(Input.Changed, "#search")
    def search(self):
        if self.step == 2:
            self.fill_choices()

    @on(Button.Pressed)
    async def button(self, event):
        key = event.button.id
        if key.startswith("category-"):
            self.category = str(event.button.label)
            self.fill_choices()
        elif key == "diagnose":
            self.action_diagnose()
        elif key == "back":
            self.action_back()
        elif key == "next":
            if self.diagnostic_mode:
                try:
                    path = Path(
                        self.query_one("#export-path", Input).value
                    ).expanduser()
                    if not path.is_absolute():
                        raise InstallError("Укажите абсолютный путь отчёта")
                    # Export is an explicit write; never overwrite an existing report.
                    with path.open("x") as stream:
                        json.dump(self.report, stream, ensure_ascii=False, indent=2)
                    self.notify(f"Отчёт: {path}")
                except (OSError, InstallError) as error:
                    self.notify(str(error), severity="error")
            elif self.step == 6:
                self.exit()
            elif self.step == 4:
                if self.dry_run:
                    self.step = 6
                    self.render_step()
                    self.query_one("#review-text", Static).update(
                        "План просмотрен. Изменения не выполнялись."
                    )
                elif self.query_one("#approve", Checkbox).value:
                    if (
                        self.plan["modified"]
                        and not self.query_one("#overwrite", Checkbox).value
                    ):
                        self.notify(
                            "Есть изменённые файлы: подтвердите бэкап и замену.",
                            severity="warning",
                        )
                        return
                    self.step = 5
                    self.render_step()
                    self.install()
                else:
                    self.notify(
                        "Сначала подтвердите итоговый план.", severity="warning"
                    )
            else:
                self.step += 1
                self.render_step()
        elif key in ("recover", "rollback") and not self.running:
            self.recover(key == "rollback")

    def action_back(self):
        if self.running:
            return
        if self.diagnostic_mode:
            self.query("#recover, #rollback").remove()
            self.render_step()
        elif self.step not in (0, 5, 6):
            self.step -= 1
            self.render_step()

    def action_quit_safe(self):
        if self.running:
            self.action_cancel_install()
        else:
            self.exit()

    def action_cancel_install(self):
        if self.running:
            self.engine.cancelled = True
            self.notify(
                "Остановка после текущей пакетной операции. Не закрывайте терминал."
            )
        else:
            self.exit()

    def interactive(self, argv):
        with self.suspend():
            import subprocess

            print("\nNayori: " + " ".join(argv), flush=True)
            return subprocess.call(argv)

    def package_error(self, package):
        with self.suspend():
            answer = (
                input(f"Ошибка {package}. [r] повтор / [s] пропуск / [c] отмена: ")
                .strip()
                .lower()
            )
        return {"r": "retry", "c": "cancel"}.get(answer, "skip")

    def log_message(self, text):
        self.call_from_thread(self.query_one("#log", RichLog).write, text)

    @work(exclusive=True)
    async def prepare_plan(self):
        try:
            self.plan = await asyncio.to_thread(
                self.engine.preflight, self.components.copy(), self.apps.copy()
            )
            lines = [
                "КОМПОНЕНТЫ: " + ", ".join(self.plan["components"]),
                "ПРИЛОЖЕНИЯ: " + ", ".join(self.plan["apps"]),
                "\nПАКЕТЫ:",
            ]
            for pkg, item in self.plan["packages"].items():
                status = (
                    "установлен"
                    if item["installed"]
                    else ("доступен" if item["available"] else "НЕДОСТУПЕН")
                )
                lines.append(f"  {pkg} · {item['source']} · {status}")
            lines += [
                "\nПУТИ:",
                *self.plan["paths"],
                "\nРЕЗЕРВНЫЕ КОПИИ: рядом с заменяемыми файлами, .*.nayori-backup-<транзакция>.",
                "Версии: releases/<версия>; переключение current атомарное.",
                "sudo: только pacman и выбранная интеграция SDDM. AUR — от текущего пользователя.",
                "Пакеты при откате не удаляются.",
            ]
            if "niri" in self.components:
                lines.append(
                    "Весь существующий niri будет сохранён и заменён проверенным комплектом."
                )
            if "sddm" in self.components:
                lines.append(
                    "SDDM: /usr/share/sddm/themes/nayori, /var/lib/nayori-sddm; журнал /var/lib/nayori-installer."
                )
            if "sddm-select" in self.components:
                lines.append("SDDM: /etc/sddm.conf.d/90-nayori.conf → Current=nayori.")
            lines += [
                "\nИЗМЕНЁННЫЕ ФАЙЛЫ:",
                *self.plan["modified"],
                "\nПРОБЛЕМЫ:",
                *self.plan["problems"],
            ]
            if (
                any(
                    item["source"] == "aur" and not item["installed"]
                    for item in self.plan["packages"].values()
                )
                and not self.engine.runner.helper()
            ):
                lines.append(
                    "Нет paru/yay: AUR будет пропущен. Установите helper самостоятельно по инструкции https://github.com/Morganamilo/paru#installation"
                )
            if self.engine.pending():
                lines.append(
                    "НЕЗАВЕРШЁННАЯ ТРАНЗАКЦИЯ: сначала восстановите её через диагностику."
                )
            self.query_one("#review-text", Static).update("\n".join(lines))
            self.query_one("#next", Button).disabled = bool(
                self.engine.pending()
            ) or not (self.components or self.apps)
        except Exception as error:
            self.query_one("#review-text", Static).update(str(error))

    @work(thread=True, exclusive=True)
    def install(self):
        self.running = True
        self.engine.cancelled = False
        try:
            update, overwrite = self.call_from_thread(
                lambda: (
                    self.query_one("#update", Checkbox).value,
                    self.query_one("#overwrite", Checkbox).value,
                )
            )
            self.engine.apply(
                self.components.copy(),
                self.apps.copy(),
                update=update,
                allow_modified=overwrite,
                on_package_error=self.package_error,
            )
            result = "Установка завершена. Подробности и возможные пропуски — в журнале.\nПерезапустите Nayori вручную, когда будет удобно."
        except Exception as error:
            self.log_message("ОШИБКА: " + str(error))
            result = "Установка не завершена полностью. Проверьте журнал и диагностику."
        finally:
            self.running = False
        self.call_from_thread(self.finish, result)

    def finish(self, result):
        self.step = 6
        self.render_step()
        self.query_one("#review-text", Static).update(result)

    def action_diagnose(self):
        if self.running:
            return
        self.diagnostic_mode = True
        self.query_one("#banner", Static).update("NAYORI / диагностика · только чтение")
        for identifier in (
            "categories",
            "search",
            "choices",
            "description",
            "update",
            "approve",
            "overwrite",
            "log",
        ):
            self.show(identifier, False)
        self.show("review", True)
        self.show("export-path", not self.dry_run)
        self.query_one("#back", Button).disabled = False
        self.query_one("#next", Button).label = "Экспорт JSON"
        self.query_one("#next", Button).disabled = self.dry_run
        self.query_one("#review-text", Static).update("Диагностика…")
        self.diagnostics()

    @work(exclusive=True)
    async def diagnostics(self):
        self.report = await asyncio.to_thread(self.engine.diagnose)
        if not self.diagnostic_mode:
            return
        self.query_one("#review-text", Static).update(
            "\n\n".join(
                f"{r['status'].upper()} · {r['title']}\n{r['detail']}"
                for r in self.report
            )
        )
        self.query("#recover, #rollback").remove()
        if not self.dry_run:
            await self.query_one("#nav").mount(
                Button("Восстановить", id="recover"), Button("Откат", id="rollback")
            )
        self.query_one("#notice", Static).update(
            "Проверка PAM статическая; пароль не запрашивается. Экспорт — только по указанному пути."
        )

    @work(thread=True, exclusive=True)
    def recover(self, rollback):
        self.running = True
        try:
            with self.suspend():
                print(
                    "Восстановление вернёт файлы до последней установки. Правки будут сохранены рядом. Пакеты останутся."
                )
                answer = input("Введите ВОССТАНОВИТЬ для подтверждения: ")
            if answer == "ВОССТАНОВИТЬ":
                self.engine.restore(allow_modified=True, rollback=rollback)
        except Exception as error:
            self.call_from_thread(self.notify, str(error), severity="error")
        finally:
            self.running = False
        self.call_from_thread(self.action_diagnose)


def main():
    parser = argparse.ArgumentParser(description="Nayori — TUI установщик")
    parser.add_argument(
        "--dry-run", action="store_true", help="Просмотр плана без записи и установки"
    )
    parser.add_argument("--diagnose", action="store_true", help="Открыть диагностику")
    args = parser.parse_args()
    InstallerApp(args.dry_run, args.diagnose).run()


if __name__ == "__main__":
    main()
