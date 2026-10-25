#!/usr/bin/env python3
"""List and edit XDG autostart entries. Never deletes system files."""

import json
import os
import re
import sys
import tempfile
from pathlib import Path

NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.desktop$")


def fail(message, code=1):
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))
    raise SystemExit(code)


def user_dir():
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "autostart"


def system_dirs():
    raw = os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg"
    return [Path(part) / "autostart" for part in raw.split(":") if part]


def user_file(name):
    if not NAME_RE.match(name):
        fail("Недопустимое имя файла автозапуска")
    root = user_dir().resolve()
    path = (root / name).resolve()
    if path.parent != root:
        fail("Недопустимый путь файла автозапуска")
    return path


def parse_desktop(text):
    fields = {}
    in_entry = False
    for raw in text.splitlines():
        line = raw.strip()
        if line == "[Desktop Entry]":
            in_entry = True
            continue
        if line.startswith("["):
            in_entry = False
            continue
        if not in_entry or not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        fields[key] = value
    return fields


def read_fields(path):
    try:
        return parse_desktop(path.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return None


def hidden(fields):
    return str(fields.get("Hidden", "")).strip().lower() == "true"


def write_fields(path, fields):
    path.parent.mkdir(mode=0o700, exist_ok=True)
    lines = ["[Desktop Entry]"]
    preferred = ["Type", "Version", "Name", "GenericName", "Comment", "Exec", "Icon", "Terminal", "Categories"]
    used = set()
    for key in preferred:
        if key in fields:
            lines.append(f"{key}={fields[key]}")
            used.add(key)
    for key in fields:
        if key in used or key == "Hidden":
            continue
        if "\n" in str(fields[key]) or "\r" in str(fields[key]):
            fail("Поле desktop-файла содержит перенос строки")
        lines.append(f"{key}={fields[key]}")
    if "Hidden" in fields:
        lines.append(f"Hidden={fields['Hidden']}")
    data = "\n".join(lines) + "\n"
    descriptor, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except Exception:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise
    os.chmod(path, 0o600)


def list_entries():
    warnings = []
    system = {}
    for directory in system_dirs():
        if not directory.is_dir():
            continue
        try:
            names = sorted(directory.glob("*.desktop"))
        except OSError as error:
            warnings.append(f"Не удалось прочитать {directory}: {error.strerror or error}")
            continue
        for path in names:
            if not NAME_RE.match(path.name):
                continue
            fields = read_fields(path)
            if fields is None:
                warnings.append(f"Не удалось прочитать {path.name}")
                continue
            system[path.name] = fields
    user = {}
    directory = user_dir()
    if directory.is_dir():
        try:
            names = sorted(directory.glob("*.desktop"))
        except OSError as error:
            warnings.append(f"Не удалось прочитать пользовательский автозапуск: {error.strerror or error}")
            names = []
        for path in names:
            if not NAME_RE.match(path.name):
                continue
            fields = read_fields(path)
            if fields is None:
                warnings.append(f"Не удалось прочитать {path.name}")
                continue
            user[path.name] = fields
    entries = []
    for name in sorted(set(system) | set(user)):
        fields = user.get(name, system.get(name, {}))
        entries.append({
            "fileName": name,
            "name": fields.get("Name") or name,
            "exec": fields.get("Exec") or "",
            "enabled": not hidden(fields),
            "userFile": name in user,
            "systemFile": name in system,
        })
    print(json.dumps({"ok": True, "entries": entries, "warnings": warnings}, ensure_ascii=False))


def set_enabled(name, enabled):
    path = user_file(name)
    fields = read_fields(path) if path.exists() else None
    if fields is None:
        source = None
        for directory in system_dirs():
            candidate = directory / name
            if candidate.is_file():
                source = read_fields(candidate)
                if source is not None:
                    break
        if source is None:
            if enabled:
                fail("Пользовательской записи нет, системная запись и так включена")
            fail("Запись автозапуска не найдена")
        fields = dict(source)
    fields["Hidden"] = "false" if enabled else "true"
    if "Type" not in fields:
        fields["Type"] = "Application"
    try:
        write_fields(path, fields)
    except OSError as error:
        fail(f"Не удалось записать {name}: {error.strerror or error}")
    print(json.dumps({"ok": True}, ensure_ascii=False))


def remove(name):
    path = user_file(name)
    if not path.exists():
        fail("Пользовательской записи нет. Системный файл не удаляется")
    try:
        path.unlink()
    except OSError as error:
        fail(f"Не удалось удалить {name}: {error.strerror or error}")
    print(json.dumps({"ok": True}, ensure_ascii=False))


def add(name, command):
    if not name or not command:
        fail("Нужны имя и команда")
    if any(char in name or char in command for char in "\n\r\x00"):
        fail("Имя и команда должны быть в одну строку")
    if len(name) > 80 or len(command) > 512:
        fail("Имя или команда слишком длинные")
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", name).strip("-") or "app"
    file_name = f"nayori-{slug}.desktop"
    path = user_file(file_name)
    index = 2
    while path.exists():
        file_name = f"nayori-{slug}-{index}.desktop"
        path = user_file(file_name)
        index += 1
        if index > 50:
            fail("Слишком много записей с таким именем")
    fields = {
        "Type": "Application",
        "Version": "1.0",
        "Name": name,
        "Exec": command,
        "X-Nayori-Autostart": "true",
        "Hidden": "false",
    }
    try:
        write_fields(path, fields)
    except OSError as error:
        fail(f"Не удалось добавить запись: {error.strerror or error}")
    print(json.dumps({"ok": True, "fileName": file_name}, ensure_ascii=False))


def main():
    if len(sys.argv) < 2:
        fail("Не указана операция")
    operation = sys.argv[1]
    if operation == "list":
        list_entries()
    elif operation == "enable" and len(sys.argv) == 3:
        set_enabled(sys.argv[2], True)
    elif operation == "disable" and len(sys.argv) == 3:
        set_enabled(sys.argv[2], False)
    elif operation == "remove" and len(sys.argv) == 3:
        remove(sys.argv[2])
    elif operation == "add" and len(sys.argv) == 4:
        add(sys.argv[2], sys.argv[3])
    else:
        fail("Неизвестная операция автозапуска")


if __name__ == "__main__":
    main()
