#!/usr/bin/env python3
"""Gum-based installer interface; the transactional engine remains independent."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
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


class Cancelled(Exception):
    pass


def quickshell_running(proc_root=Path("/proc")):
    """Conservatively avoid starting another Quickshell in the user's session."""
    for process in proc_root.iterdir():
        if not process.name.isdecimal():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            if (process / "comm").read_text().strip().lower() in {"qs", "quickshell"}:
                return True
        except FileNotFoundError:
            continue
        except OSError as error:
            raise InstallError(f"Не удалось проверить процессы Quickshell: {error}") from error
    return False


class Gum:
    def choose(self, title, labels, selected=(), multiple=False):
        argv = ["gum", "choose", "--header", title]
        if multiple:
            argv.append("--no-limit")
            for label in selected:
                argv.extend(["--selected", label])
        result = subprocess.run([*argv, *labels], stdout=subprocess.PIPE, text=True)
        if result.returncode:
            raise Cancelled()
        return [line for line in result.stdout.splitlines() if line]

    def confirm(self, question):
        return (
            subprocess.call(
                [
                    "gum",
                    "confirm",
                    "--default=false",
                    "--affirmative=Да",
                    "--negative=Нет",
                    question,
                ]
            )
            == 0
        )

    def input(self, prompt):
        result = subprocess.run(
            ["gum", "input", "--prompt", prompt], stdout=subprocess.PIPE, text=True
        )
        if result.returncode:
            raise Cancelled()
        return result.stdout.rstrip("\n")


class InstallerApp:
    def __init__(self, dry_run=False, diagnose=False, engine=None, gum=None):
        self.dry_run = dry_run
        self.start_diagnose = diagnose
        self.engine = engine or Engine()
        self.engine.log = lambda message: print(message, flush=True)
        self.gum = gum or Gum()
        self.components = set()
        self.apps = set()

    def choose_one(self, title, options):
        result = self.gum.choose(title, options)
        return result[0] if result else None

    def choose_components(self):
        labels = {
            f"{item['label']} [{key}]": key
            for key, item in CATALOG["components"].items()
        }
        try:
            selected = self.gum.choose(
                "Компоненты · Tab — отметить, Enter — продолжить",
                list(labels),
                [label for label, key in labels.items() if key in self.components],
                multiple=True,
            )
        except Cancelled:
            return
        chosen = {labels[label] for label in selected}
        updated = set(self.components)
        for key in self.components - chosen:
            updated = deselect_component(updated, key)
        updated.update(chosen - self.components)
        self.components = resolve_components(updated)
        if self.components - chosen:
            print(
                "Добавлены необходимые компоненты: "
                + ", ".join(sorted(self.components - chosen))
            )

    def choose_apps(self):
        code, output = self.engine.runner.capture(["pacman", "-Qq"])
        installed = set(output.splitlines()) if code == 0 else set()
        if code:
            print("Не удалось определить установленные приложения.")
        categories = list(
            dict.fromkeys(item["category"] for item in CATALOG["apps"].values())
        )
        while True:
            try:
                category = self.choose_one(
                    "Приложения · выберите категорию", [*categories, "Назад"]
                )
                if not category or category == "Назад":
                    return
                labels = {
                    f"{item['label']} [{item['source'] if item['source'] != 'auto' else 'repo/AUR'}]"
                    + (" [installed]" if set(item["packages"]) <= installed else ""): key
                    for key, item in CATALOG["apps"].items()
                    if item["category"] == category
                }
                if not labels:
                    print("Приложения не найдены.")
                    continue
                selected = self.gum.choose(
                    category + " · Tab — отметить, Enter — продолжить",
                    list(labels),
                    [label for label, key in labels.items() if key in self.apps],
                    multiple=True,
                )
                self.apps.difference_update(labels.values())
                self.apps.update(labels[label] for label in selected)
            except Cancelled:
                return

    def show_plan(self, plan):
        print("\nКОМПОНЕНТЫ: " + (", ".join(plan["components"]) or "нет"))
        print("ПРИЛОЖЕНИЯ: " + (", ".join(plan["apps"]) or "нет"))
        print("\nПАКЕТЫ:")
        for package, item in plan["packages"].items():
            status = (
                "установлен"
                if item["installed"]
                else "доступен"
                if item["available"]
                else "недоступен"
            )
            print(f"  {package} · {item['source']} · {status}")
        print("\nПУТИ:\n" + "\n".join(plan["paths"]))
        print(
            "\nРезервные копии создаются рядом с заменяемыми файлами. Пакеты при откате не удаляются."
        )
        if "niri" in plan["components"]:
            print(
                "Существующий каталог niri будет сохранён и заменён проверенным комплектом."
            )
        if "sddm" in plan["components"]:
            print("SDDM: /usr/share/sddm/themes/nayori и /var/lib/nayori-sddm.")
        if "sddm-select" in plan["components"]:
            print("SDDM: /etc/sddm.conf.d/90-nayori.conf → Current=nayori.")
        if plan["modified"]:
            print("\nИЗМЕНЁННЫЕ ФАЙЛЫ:\n" + "\n".join(plan["modified"]))
        if plan["problems"]:
            print("\nПРОБЛЕМЫ:\n" + "\n".join(plan["problems"]))
        if self.engine.pending():
            print(
                "\nЕсть незавершённая транзакция. Сначала восстановите её в диагностике."
            )
        print(
            "\npacman использует ответы по умолчанию (--noconfirm); sudo может запросить пароль."
        )

    def package_error(self, package):
        try:
            choice = self.choose_one(
                f"Не удалось установить {package}",
                ["Повторить", "Пропустить", "Остановить"],
            )
        except Cancelled:
            return "cancel"
        return {"Повторить": "retry", "Пропустить": "skip"}.get(choice, "cancel")

    def launch_available(self):
        launcher = self.engine.paths.bin / "nayori"
        current = self.engine.paths.base / "current"
        try:
            release = current.resolve(strict=True)
            return (
                launcher.is_file()
                and os.access(launcher, os.X_OK)
                and release.is_relative_to(self.engine.paths.base / "releases")
                and (release / "manifest.json").is_file()
            )
        except OSError:
            return False

    def launch_shell(self):
        if not self.launch_available():
            raise InstallError("Установленная версия Nayori не найдена.")
        if not os.environ.get("WAYLAND_DISPLAY"):
            raise InstallError("Для запуска нужна активная сессия Wayland.")
        if quickshell_running():
            raise InstallError(
                "Quickshell уже запущен. Проверьте работающую оболочку перед запуском Nayori."
            )
        subprocess.Popen(
            [str(self.engine.paths.bin / "nayori")],
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
        print("Запуск Nayori запрошен.", flush=True)

    def show_result(self, success, allow_launch=False):
        while True:
            print("\n" + ("Установка завершена." if success else "Установка не завершена."))
            print("Проверьте журнал и возможные пропуски выше.")
            options = []
            if success and allow_launch and self.launch_available():
                options.append("Запустить Nayori")
            options.extend(["Диагностика", "Вернуться в меню", "Закрыть"])
            try:
                choice = self.choose_one("Результат установки", options)
                if choice == "Запустить Nayori":
                    try:
                        self.launch_shell()
                    except (OSError, InstallError) as error:
                        print(f"Не удалось запустить Nayori: {error}")
                        continue
                    return True
                if choice == "Диагностика":
                    self.diagnostics()
                    continue
                return choice != "Вернуться в меню"
            except Cancelled:
                return True

    def review(self):
        if not self.components and not self.apps:
            print("Сначала выберите компоненты или приложения.")
            return
        plan = self.engine.preflight(self.components.copy(), self.apps.copy())
        self.show_plan(plan)
        if self.dry_run or self.engine.pending():
            return
        update = self.gum.confirm(
            "Обновить всю систему перед установкой (pacman -Syu)?"
        )
        print("Обновление системы: " + ("да" if update else "нет"), flush=True)
        overwrite = False
        if plan["modified"]:
            overwrite = self.gum.confirm(
                "Сохранить изменённые файлы в резервную копию и заменить их?"
            )
            if not overwrite:
                return
        if not self.gum.confirm("Применить показанный план?"):
            return
        self.engine.cancelled = False
        try:
            result = self.engine.apply(
                self.components.copy(),
                self.apps.copy(),
                update=update,
                allow_modified=overwrite,
                on_package_error=self.package_error,
            )
        except (OSError, ValueError, InstallError) as error:
            print(f"Установка не завершена: {error}")
            return self.show_result(False)
        requested = resolve_components(self.components)
        if "nayori" in requested and "nayori" not in result["components"]:
            print("Nayori не установлена: нужные пакеты недоступны или были пропущены.")
        allow_launch = "nayori" not in requested or "nayori" in result["components"]
        return self.show_result(True, allow_launch=allow_launch)

    def diagnostics(self):
        while True:
            report = self.engine.diagnose()
            for item in report:
                print(f"{item['status'].upper()} · {item['title']}\n{item['detail']}\n")
            actions = (
                ["Назад"]
                if self.dry_run
                else ["Экспорт JSON", "Восстановить", "Откат", "Назад"]
            )
            try:
                action = self.choose_one("Диагностика", actions)
                if not action or action == "Назад":
                    return
                if action == "Экспорт JSON":
                    path = Path(self.gum.input("Абсолютный путь отчёта: ")).expanduser()
                    if not path.is_absolute():
                        raise InstallError("Укажите абсолютный путь.")
                    with path.open("x") as stream:
                        json.dump(report, stream, ensure_ascii=False, indent=2)
                    print(f"Отчёт сохранён: {path}")
                else:
                    print(
                        "Прежние файлы будут восстановлены, последующие правки сохранены рядом. Пакеты останутся."
                    )
                    if self.gum.input("Введите ВОССТАНОВИТЬ: ") == "ВОССТАНОВИТЬ":
                        self.engine.restore(
                            allow_modified=True, rollback=action == "Откат"
                        )
            except Cancelled:
                return
            except (OSError, ValueError, InstallError) as error:
                print(f"Ошибка: {error}")

    def run(self):
        print(
            "\nNAYORI · УСТАНОВКА\nВыберите компоненты и проверьте план перед применением."
        )
        if self.start_diagnose:
            self.diagnostics()
        while True:
            try:
                choice = self.choose_one(
                    "Что сделать?",
                    [
                        "Компоненты",
                        "Приложения",
                        "Проверить план",
                        "Диагностика",
                        "Выход",
                    ],
                )
                if choice == "Компоненты":
                    self.choose_components()
                elif choice == "Приложения":
                    self.choose_apps()
                elif choice == "Проверить план":
                    if self.review():
                        return
                elif choice == "Диагностика":
                    self.diagnostics()
                else:
                    return
            except Cancelled:
                return
            except (OSError, ValueError, InstallError) as error:
                print(f"Ошибка: {error}")


def main():
    parser = argparse.ArgumentParser(description="Nayori — установщик")
    parser.add_argument(
        "--dry-run", action="store_true", help="Просмотр плана без записи и установки"
    )
    parser.add_argument("--diagnose", action="store_true", help="Открыть диагностику")
    args = parser.parse_args()
    try:
        InstallerApp(args.dry_run, args.diagnose).run()
    except KeyboardInterrupt:
        print(
            "\nУстановщик остановлен. При прерывании применения проверьте диагностику."
        )
        return 130
    return 0


if __name__ == "__main__":
    sys.exit(main())
