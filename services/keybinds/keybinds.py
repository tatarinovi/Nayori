#!/usr/bin/env python3
"""Keybind adapters and conflict analysis. No actions are executed by inspection.

Niri persistence goes through niri_config_apply, including backups/validation.
Managed metadata is a comment beside the bind, never a parallel config store.
"""
import base64
import ctypes
import ctypes.util
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "system"))
import niri_config_apply as config

CATEGORIES = ["Windows", "Focus", "Move", "Resize", "Workspaces", "Displays",
              "Apps", "Shell", "Media", "Hardware", "Mouse", "Custom"]
SHELL_ACTIONS = {
    "launcher.toggle": "Лаунчер", "start.toggle": "Пуск", "clipboard.toggle": "Буфер обмена",
    "settings.open": "Настройки", "lock.lock": "Блокировка",
    "capture.screenshot": "Снимок экрана", "capture.record": "Запись экрана",
    "inbox.open": "Быстрая заметка", "musicstage.toggle": "Музыкальная сцена",
    "apps.terminal": "Терминал по умолчанию", "apps.browser": "Браузер по умолчанию",
    "apps.files": "Файловый менеджер по умолчанию", "apps.editor": "Редактор по умолчанию",
    "apps.notes": "Заметки по умолчанию",
}
NIRI_ACTIONS = ["close-window", "fullscreen-window", "toggle-window-floating", "toggle-overview",
                "focus-column-left", "focus-column-right", "focus-window-up", "focus-window-down",
                "focus-workspace-up", "focus-workspace-down", "focus-workspace-previous",
                "move-column-left", "move-column-right", "move-window-up", "move-window-down",
                "center-column", "expand-column-to-available-width", "power-off-monitors"]
MODIFIERS = {"ctrl": "Ctrl", "control": "Ctrl", "super": "Super", "win": "Super",
             "alt": "Alt", "shift": "Shift", "mod": "Mod", "mod5": "Mod5",
             "iso_level3_shift": "Mod5", "iso_level5_shift": "ISO_Level5_Shift"}
META = re.compile(r'// nayori-keybind:([A-Za-z0-9_=-]+)[ \t]*\r?\n[ \t]*$')


def digest(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def xkb_library():
    try:
        library = ctypes.CDLL(ctypes.util.find_library("xkbcommon") or "libxkbcommon.so.0")
        library.xkb_keysym_from_name.argtypes = [ctypes.c_char_p, ctypes.c_int]
        library.xkb_keysym_from_name.restype = ctypes.c_uint32
        return library
    except OSError:
        return None


XKB = xkb_library()


def canonical(keys, mod="Super", validate=False):
    parts = [part.strip() for part in str(keys).split("+")]
    if not parts or any(not part for part in parts):
        raise config.ApplyError("Укажите модификаторы и клавишу, например Super+Return")
    modifiers = []
    for part in parts[:-1]:
        modifier = MODIFIERS.get(part.lower())
        if modifier is None:
            raise config.ApplyError("Неизвестный модификатор: " + part)
        modifiers.append(mod if modifier == "Mod" else modifier)
    trigger = parts[-1]
    implicit = {"super_l": "Super", "super_r": "Super", "control_l": "Ctrl", "control_r": "Ctrl",
                "alt_l": "Alt", "alt_r": "Alt", "shift_l": "Shift", "shift_r": "Shift"}.get(trigger.lower())
    modifiers = [item for item in modifiers if item != implicit]
    mouse = re.fullmatch(r'(WheelScroll|TouchpadScroll)(Up|Down|Left|Right)|Mouse(Left|Right|Middle|Back|Forward)', trigger, re.I)
    symbol = XKB.xkb_keysym_from_name(trigger.encode(), 1) if XKB else 0
    if validate and not mouse and not symbol:
        raise config.ApplyError("Неизвестная клавиша XKB: " + trigger if XKB else "Библиотека xkbcommon недоступна")
    # XKB resolves aliases, but upper/lower letters denote the same niri binding.
    if len(trigger) == 1:
        trigger = trigger.lower()
        symbol = XKB.xkb_keysym_from_name(trigger.encode(), 1) if XKB else 0
    key = str(symbol) if symbol else trigger.lower()
    return "+".join(sorted(set(modifiers))) + ":" + key


def category(action, keys, source):
    if "\"apps\"" in action:
        return "Apps"
    if source == "Nayori":
        return "Shell"
    if re.search(r'(Mouse|Scroll)', keys, re.I):
        return "Mouse"
    if "brightness" in action or "Brightness" in keys or "touchpad" in action:
        return "Hardware"
    if re.search(r'wpctl|playerctl|Audio', action + keys):
        return "Media"
    if "monitor" in action or "output" in action:
        return "Displays"
    if "workspace" in action or "overview" in action:
        return "Workspaces"
    if re.search(r'width|height|resize', action):
        return "Resize"
    if action.startswith("focus-"):
        return "Focus"
    if action.startswith(("move-", "consume-", "expel-")):
        return "Move"
    if action.startswith("spawn"):
        return "Apps"
    return "Windows"


def shell_action(action):
    # Recognise only known IPC endpoints and known executable identities.
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[^\s;{}]+', action)
    decoded = []
    for token in tokens:
        try:
            decoded.append(json.loads(token) if token.startswith('"') else token)
        except ValueError:
            return ""
    if decoded and decoded[0] == "spawn-sh" and len(decoded) == 2:
        try:
            decoded = ["spawn"] + shlex.split(decoded[1])
        except ValueError:
            return ""
    if len(decoded) < 4 or decoded[0] != "spawn":
        return ""
    executable = Path(decoded[1]).name
    if executable == "qs" and "call" in decoded and "ipc" in decoded:
        # The project path is explicit; never label another shell's IPC as Nayori.
        if "-p" not in decoded:
            return ""
        pos = decoded.index("-p")
        if pos + 1 >= len(decoded):
            return ""
        target_path = Path(decoded[pos + 1])
        if target_path.name != "nayori" and target_path.resolve() != Path(__file__).resolve().parents[2]:
            return ""
        tail = decoded[decoded.index("call") + 1:]
    elif executable == "nayori" and decoded[2] == "ipc":
        tail = decoded[3:]
    else:
        return ""
    return ".".join(tail[:2]) if ".".join(tail[:2]) in SHELL_ACTIONS else ""


def metadata(entry, node):
    marker = node.get("marker_start", node["start"])
    match = META.search(entry["text"][:marker])
    if match:
        try:
            value = json.loads(base64.urlsafe_b64decode(match[1]).decode())
            if isinstance(value, dict) and value.get("version") == 1:
                return value, match.start()
        except (ValueError, UnicodeError):
            pass
    return {}, marker


def metadata_line(data):
    encoded = base64.urlsafe_b64encode(json.dumps(data, ensure_ascii=False).encode()).decode()
    return "// nayori-keybind:" + encoded + "\n"


def ordered_sections(files):
    """Includes merge at their position, rather than after all parent sections."""
    by_path = {entry["path"]: entry for entry in files}
    visits = 0

    def visit(entry, ancestors):
        nonlocal visits
        visits += 1
        if visits > 256:
            raise config.ApplyError("Слишком много повторных include. Файлы не изменены")
        if entry["path"] in ancestors:
            return
        ancestors = ancestors | {entry["path"]}
        for parent in entry["nodes"] or []:
            yield entry, parent
            if parent["name"] == "include" and not parent["commented"]:
                args = config._string_args(parent)
                if args:
                    target = Path(args[0]).expanduser()
                    target = (target if target.is_absolute() else entry["path"].parent / target).resolve()
                    if target in by_path:
                        yield from visit(by_path[target], ancestors)
    if files:
        yield from visit(files[0], set())


def niri_rows(files, mod="Super"):
    rows = []
    # Entries remain visible even if a later binds block overrides them.
    for entry, parent in ordered_sections(files):
        if parent["name"] != "binds":
            continue
        for node in parent["children"] or []:
            meta, _ = metadata(entry, node)
            action = entry["text"][node["brace"] + 1:node["close"]].strip() if node["brace"] is not None else ""
            endpoint = shell_action(action)
            source = "Nayori" if endpoint else "Niri"
            title = next((value[1] for key, value in node["props"] if key == "hotkey-overlay-title"), "")
            identity = str(entry["path"]) + ":" + str(node["start"])
            rows.append({
                "id": identity, "keys": node["name"], "title": meta.get("title") or title or SHELL_ACTIONS.get(endpoint) or action,
                "action": action, "source": source, "adapter": "niri", "scope": "global",
                "category": meta.get("category") or category(action, node["name"], source),
                "enabled": not (parent["commented"] or node["commented"]),
                "editable": not parent["commented"] and not entry["protected"]
                    and os.access(entry["path"], os.W_OK) and os.access(entry["path"].parent, os.W_OK),
                "custom": meta.get("custom") is True,
                "defaultKeys": meta.get("defaultKeys", node["name"]),
                "path": str(entry["path"]), "revision": digest(entry["text"]),
                "kind": meta.get("kind", ""), "value": meta.get("value", ""),
                "reason": "Защищённый фрагмент конфигурации" if entry["protected"] else "",
                "block": str(entry["path"]) + ":" + str(parent["start"]),
            })
    latest = {}
    for row in rows:
        if not row["enabled"]:
            continue
        try:
            key = canonical(row["keys"], mod)
        except config.ApplyError:
            continue
        for earlier in latest.get(key, []):
            if earlier["block"] != row["block"]:
                earlier["active"] = False
                earlier["shadowedBy"] = row["title"]
        latest.setdefault(key, []).append(row)
    # The same include may be referenced twice; one editor targets its one span.
    return list({row["id"]: row for row in rows}.values())


class NiriAdapter:
    def read(self, path, chosen_mod=None):
        files, warnings = config.collect_files(Path(path), allow_external=True)
        if not files:
            raise config.ApplyError("Конфигурация niri не найдена")
        modifier, explicit = mod_key(files)
        return niri_rows(files, modifier if explicit else chosen_mod or modifier), warnings, files


class KittyAdapter:
    """Only explicitly declared map directives, never the terminal's defaults."""
    def read(self, config_home):
        rows, warnings, seen = [], [], set()

        def visit(path):
            path = path.resolve()
            if path in seen:
                return
            seen.add(path)
            if len(seen) > 32:
                warnings.append("Kitty: достигнут предел include")
                return
            try:
                if path.stat().st_size > config.MAX_BYTES:
                    raise ValueError("слишком большой файл")
                lines = path.read_text().splitlines()
            except (OSError, ValueError) as error:
                warnings.append("Kitty: " + str(error))
                return
            for number, line in enumerate(lines, 1):
                try:
                    parts = shlex.split(line, comments=True)
                except ValueError:
                    warnings.append(f"Kitty: не разобрана строка {number}")
                    continue
                if parts and parts[0] == "include" and len(parts) == 2:
                    expanded = Path(os.path.expandvars(parts[1])).expanduser()
                    expanded = expanded if expanded.is_absolute() else path.parent / expanded
                    if any(char in str(expanded) for char in "*?["):
                        warnings.append("Kitty: шаблон include не раскрыт: " + str(expanded))
                    else:
                        visit(expanded)
                elif len(parts) >= 3 and parts[0] == "map" and not parts[1].startswith("--"):
                    keys = parts[1].replace("kitty_mod", "Ctrl+Shift")
                    # kitty_mod may be customised: don't assert its default is active.
                    if "kitty_mod" in parts[1]:
                        warnings.append("Kitty: kitty_mod требует проверки в настройках терминала")
                        keys = parts[1]
                    rows.append({"id": f"kitty:{path}:{number}", "keys": keys, "title": " ".join(parts[2:]),
                                 "action": " ".join(parts[2:]), "source": "Kitty", "adapter": "kitty", "category": "Apps",
                                 "scope": "application:kitty", "enabled": parts[2] not in ("no_op", "discard_event"),
                                 "editable": False, "custom": False, "defaultKeys": "", "path": str(path),
                                 "reason": "Сочетание внутри окна Kitty; редактируется в kitty.conf"})
        start = Path(config_home) / "kitty/kitty.conf"
        if start.is_file():
            visit(start)
        return rows, warnings


def mod_key(files):
    found = None
    # Preserve include positionality for input overrides too.
    for entry, node in ordered_sections(files):
        if node["name"] == "input" and not node["commented"]:
            for child in config._active_children(node):
                if child["name"] == "mod-key" and child["args"]:
                    value = str(child["args"][0][1])
                    found = MODIFIERS.get(value.lower(), "Super")
    if found:
        return found, True
    # The reader cannot know whether niri is nested. Explicit choice in the UI.
    return "Super", False


def conflicts(rows, mod="Super"):
    groups, found = {}, []
    for row in rows:
        if not row.get("enabled") or row.get("active") is False:
            continue
        for keys in row.get("aliases", [row["keys"]]):
            try:
                key = canonical(keys, mod)
            except config.ApplyError:
                continue
            groups.setdefault(key, []).append(row)
    for group in groups.values():
        for i, left in enumerate(group):
            for right in group[i + 1:]:
                # A global bind consumes a key even while an app has focus; two
                # different applications do not overlap with each other.
                global_pair = left["scope"] == right["scope"] == "global" and not (left.get("phase") == "tap" or right.get("phase") == "tap")
                overlap = "global" in (left["scope"], right["scope"])
                if not global_pair and not overlap:
                    continue
                found.append({"keys": left["keys"], "ids": [left["id"], right["id"]],
                              "actions": [left["title"], right["title"]], "sources": [left["source"], right["source"]],
                              "severity": "confirmed" if global_pair else "potential",
                              "reason": "Одинаковое глобальное сочетание" if global_pair else "Глобальное сочетание может перехватить клавишу приложения",
                              "suggestion": "Измените одно сочетание или отключите пользовательское"})
    for row in rows:
        if not row.get("enabled") or row.get("active") is False or row.get("scope") != "global":
            continue
        try:
            reserved = any(canonical(row["keys"], mod) == canonical("Ctrl+Alt+F" + str(number)) for number in range(1, 13))
        except config.ApplyError:
            reserved = False
        if reserved:
            found.append({"keys": row["keys"], "ids": [row["id"]], "actions": [row["title"], "Переключение виртуальной консоли"],
                          "sources": [row["source"], "Система"], "severity": "potential",
                          "reason": "Система может перехватить переключение VT", "suggestion": "Выберите другую комбинацию"})
    return found


def snapshot(path, chosen_mod=None):
    rows, warnings, files = NiriAdapter().read(path, chosen_mod)
    home = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    external, extra = KittyAdapter().read(home)
    rows.extend(external)
    bound = {shell_action(row["action"]) for row in rows if row["adapter"] == "niri"}
    for endpoint, title in SHELL_ACTIONS.items():
        if endpoint not in bound and endpoint != "start.toggle":
            rows.append({"id": "registry:" + endpoint, "keys": "", "title": title,
                         "action": endpoint, "source": "Nayori", "adapter": "registry", "scope": "global",
                         "category": "Apps" if endpoint.startswith("apps.") else "Shell", "enabled": False, "editable": True,
                         "custom": False, "defaultKeys": ""})
    warnings.extend(extra)
    actual_mod, explicit = mod_key(files)
    actual_mod = actual_mod if explicit else (chosen_mod or actual_mod)
    return {"ok": True, "rows": rows, "warnings": warnings, "conflicts": conflicts(rows, actual_mod),
            "revision": {str(item["path"]): digest(item["text"]) for item in files},
            "mod": actual_mod, "modExplicit": explicit, "validateAvailable": config.niri_binary() is not None,
            "config": str(path), "categories": [name for name in CATEGORIES if any(row["category"] == name for row in rows)],
            "shellActions": [{"key": key, "label": title} for key, title in SHELL_ACTIONS.items()],
            "niriActions": [{"key": name, "label": name} for name in NIRI_ACTIONS]}


def custom_action(kind, value):
    if not isinstance(value, str) or not value.strip() or len(value) > 4000 or any(ord(char) < 32 for char in value):
        raise config.ApplyError("Укажите параметры действия без переносов строк")
    if kind in ("app", "command"):
        try:
            argv = shlex.split(value)
        except ValueError:
            raise config.ApplyError("Проверьте кавычки в команде") from None
        if not argv:
            raise config.ApplyError("Команда пуста")
        return "spawn " + " ".join(config.quote_string(arg) for arg in argv) + ";"
    if kind == "url":
        if not re.match(r'^https?://[^\s]+$', value):
            raise config.ApplyError("Укажите URL с http:// или https://")
        return 'spawn "xdg-open" ' + config.quote_string(value) + ";"
    if kind == "shell" and value in SHELL_ACTIONS:
        target, method = value.split(".")
        project = str(Path(__file__).resolve().parents[2])
        return 'spawn "qs" "ipc" "-p" ' + config.quote_string(project) + ' "call" ' + config.quote_string(target) + " " + config.quote_string(method) + ";"
    if kind == "niri" and value in NIRI_ACTIONS:
        return value + ";"
    raise config.ApplyError("Выберите поддерживаемое действие")


def ensure_free(files, keys, exclude=None, chosen_mod=None):
    modifier, explicit = mod_key(files)
    modifier = modifier if explicit else chosen_mod or modifier
    wanted = canonical(keys, modifier)
    for row in niri_rows(files, modifier):
        if row["id"] == exclude or not row["enabled"] or row.get("active") is False:
            continue
        if canonical(row["keys"], modifier) == wanted:
            raise config.ApplyError("Комбинация занята: " + row["title"] + " · " + row["source"] + ". Сначала измените её")


def plan_niri_changes(files, warnings, request):
    if warnings or any(entry["nodes"] is None for entry in files):
        raise config.ApplyError("Не все include прочитаны. Исправьте ошибки и обновите список")
    revision = request.get("revision")
    if revision != {str(entry["path"]): digest(entry["text"]) for entry in files}:
        raise config.ApplyError("Конфигурация изменилась снаружи. Обновите список")
    operation = request.get("operation")
    chosen_mod = request.get("mod", "Super")
    if chosen_mod not in ("Super", "Alt"):
        raise config.ApplyError("Выберите значение Mod для текущего сеанса")
    row = next((item for item in niri_rows(files) if item["id"] == request.get("id")), None)
    if operation != "create" and (not row or not row["editable"]):
        raise config.ApplyError("Сочетание недоступно для изменения. Обновите список")
    if operation == "create":
        entry = files[0]
        keys = str(request.get("keys", "")).strip()
        canonical(keys, validate=True)
        ensure_free(files, keys, chosen_mod=chosen_mod)
        title = request.get("title", "").strip()
        if not title:
            raise config.ApplyError("Укажите название сочетания")
        config.quote_string(title)
        kind, value = request.get("kind"), request.get("value")
        action = custom_action(kind, value)
        meta = {"version": 1, "custom": True, "uid": uuid.uuid4().hex, "defaultKeys": keys,
                "title": title, "category": request.get("category", "Custom"), "kind": kind, "value": value}
        if meta["category"] not in CATEGORIES:
            raise config.ApplyError("Неизвестная категория")
        disabled = "/- " if request.get("enabled") is False else ""
        addition = metadata_line(meta) + "    " + disabled + keys + " hotkey-overlay-title=" + config.quote_string(title) + " { " + action + " }\n"
        text = entry["text"]
        blocks = [node for node in entry["nodes"] if node["name"] == "binds" and not node["commented"] and node["close"] is not None]
        if blocks:
            close = blocks[-1]["close"]
            text = text[:close] + "\n    " + addition + text[close:]
        else:
            text += ("" if text.endswith("\n") else "\n") + "binds {\n    " + addition + "}\n"
        return {entry["path"]: text}
    entry = next(item for item in files if str(item["path"]) == row["path"])
    node = next(node for parent in entry["nodes"] if parent["name"] == "binds"
                for node in parent["children"] or [] if str(entry["path"]) + ":" + str(node["start"]) == row["id"])
    meta, metadata_start = metadata(entry, node)
    text = entry["text"]
    if operation == "delete":
        if not row["custom"]:
            raise config.ApplyError("Удалять можно только пользовательские сочетания")
        return {entry["path"]: text[:metadata_start] + text[node["content_end"]:]}
    if operation == "toggle":
        if not row["custom"]:
            raise config.ApplyError("Отключать можно только пользовательские сочетания")
        start = node["marker_start"]
        if node["commented"]:
            ensure_free(files, row["keys"], row["id"], chosen_mod)
        replacement = "" if node["commented"] else "/- "
        return {entry["path"]: text[:start] + replacement + text[node["start"]:]}
    if operation not in ("rebind", "reset", "update"):
        raise config.ApplyError("Неизвестное изменение сочетания")
    if operation == "update" and not row["custom"]:
        raise config.ApplyError("Менять параметры можно только у пользовательского действия")
    keys = row["defaultKeys"] if operation == "reset" else str(request.get("keys", "")).strip()
    canonical(keys, validate=True)
    if keys != node["name"]:
        ensure_free(files, keys, row["id"], chosen_mod)
    role = request.get("appRole", "")
    if role and ("apps." + role not in SHELL_ACTIONS or row["category"] != "Apps"):
        raise config.ApplyError("Приложение нельзя назначить этому действию")
    if keys == node["name"] and not role and operation != "update":
        return {}
    if not meta:
        meta = {"version": 1, "defaultKeys": node["name"]}
    if operation == "update":
        title = request.get("title", "").strip()
        if not title or request.get("category") not in CATEGORIES:
            raise config.ApplyError("Укажите название и категорию")
        config.quote_string(title)
        kind, value = request.get("kind"), request.get("value")
        rendered_action = custom_action(kind, value)
        meta.update({"title": title, "category": request["category"], "kind": kind, "value": value})
        if kind != row["kind"] or value != row["value"]:
            children = config._active_children(node)
            if len(children) != 1:
                raise config.ApplyError("Структура пользовательского действия изменилась. Обновите список")
            action_node = children[0]
            text = text[:action_node["start"]] + rendered_action.rstrip(";") + text[action_node["content_end"]:]
        header = text[node["name_end"]:node["brace"]]
        title_pattern = r'hotkey-overlay-title\s*=\s*"(?:\\.|[^"\\])*"'
        replacement = "hotkey-overlay-title=" + config.quote_string(title)
        updated_header, count = re.subn(title_pattern, lambda _match: replacement, header, count=1)
        if not count:
            updated_header = header + replacement + " "
        text = text[:node["name_end"]] + updated_header + text[node["brace"]:]
    elif role:
        children = config._active_children(node)
        if len(children) != 1 or children[0]["name"] not in ("spawn", "spawn-sh"):
            raise config.ApplyError("Неоднозначное действие. Создайте отдельное сочетание приложения")
        action_node = children[0]
        rendered_action = custom_action("shell", "apps." + role)
        if text[action_node["content_end"]:action_node["content_end"] + 1] == ";":
            rendered_action = rendered_action.rstrip(";")
        text = text[:action_node["start"]] + rendered_action + text[action_node["content_end"]:]
    # Preserve header properties and comments. An explicitly chosen application
    # role replaces just the spawn node; ordinary rebinds only change the name.
    rendered = config.quote_string(keys) if text[node["start"]] == '"' else keys
    text = text[:node["start"]] + rendered + text[node["name_end"]:]
    if operation == "update" and metadata_start != node["marker_start"]:
        text = text[:metadata_start] + metadata_line(meta) + config._line_indent_before(entry["text"], node["start"]) + text[node["marker_start"]:]
    elif metadata_start == node["marker_start"]:
        text = text[:metadata_start] + metadata_line(meta) + config._line_indent_before(entry["text"], node["start"]) + text[metadata_start:]
    return {entry["path"]: text}


def handle(request):
    path = config.niri_config_path()
    action = request.get("action")
    try:
        if action == "read":
            return snapshot(path, request.get("mod"))
        if action == "preview":
            rows = request.get("rows", [])
            if len(rows) > 5000:
                raise config.ApplyError("Слишком много сочетаний")
            return {"ok": True, "conflicts": conflicts(rows, request.get("mod", "Super"))}
        if action == "apply":
            validation_error = []

            def validate(candidate):
                binary = config.niri_binary()
                if not binary:
                    return None
                try:
                    result = subprocess.run([binary, "validate", "-c", str(candidate)],
                                            capture_output=True, text=True, timeout=5, check=False)
                    if result.returncode:
                        validation_error.append((result.stderr or result.stdout).strip()[:4000])
                    return result.returncode == 0
                except (OSError, subprocess.TimeoutExpired) as error:
                    validation_error.append(str(error))
                    return False

            result = config.apply_changes(path, {"keybinds": request.get("change", {})}, validator=validate)
            if not result["ok"] and validation_error:
                result["error"] += "\n" + "\n".join(validation_error)
            return result
        if action == "live":
            return config.live_reload()
        raise config.ApplyError("Неизвестный запрос")
    except (config.ApplyError, OSError, ValueError, TypeError, KeyError) as error:
        return {"ok": False, "error": str(error)}


def serve():
    for line in sys.stdin:
        try:
            request = json.loads(line)
            result = handle(request)
        except (ValueError, TypeError, AttributeError) as error:
            request, result = {}, {"ok": False, "error": str(error)}
        result["action"] = request.get("action", "")
        result["serial"] = request.get("serial")
        result["draft"] = request.get("draft", False)
        print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    serve()
