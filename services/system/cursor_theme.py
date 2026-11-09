#!/usr/bin/env python3
"""Explicit, user-scoped cursor integration. Reading never changes the session."""
import base64
import configparser
import json
import os
import re
import shutil
import subprocess
import struct
import sys
import zlib
from pathlib import Path

import niri_config_apply as niri


def config_home():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")


def icon_roots():
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    roots = [Path.home() / ".icons", data / "icons"]
    roots.extend(Path(p) / "icons" for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":"))
    return roots


def cursor_previews(path):
    """Decode the first Xcursor frame per nominal size into bounded PNGs."""
    try:
        if path.stat().st_size > 4_000_000:
            return []
        data = path.read_bytes()
        if data[:4] != b"Xcur" or len(data) < 16:
            return []
        header, _version, count = struct.unpack_from("<III", data, 4)
        if count > 256 or header < 16 or header + count * 12 > len(data):
            return []
        previews = {}
        for index in range(count):
            kind, size, offset = struct.unpack_from("<III", data, header + index * 12)
            if kind != 0xfffd0002 or size in previews or not 1 <= size <= 256:
                continue
            length, image_kind, subtype, _version, width, height, _x, _y, _delay = struct.unpack_from("<9I", data, offset)
            if image_kind != kind or subtype != size or length < 36 or not (1 <= width <= 256 and 1 <= height <= 256):
                continue
            start = offset + length
            end = start + width * height * 4
            if end > len(data):
                continue
            raw = bytearray()
            for row in range(height):
                raw.append(0)  # PNG row: no filter.
                for col in range(width):
                    b, g, r, a = data[start + (row * width + col) * 4: start + (row * width + col + 1) * 4]
                    raw.extend((min(255, r * 255 // a) if a else 0,
                                min(255, g * 255 // a) if a else 0,
                                min(255, b * 255 // a) if a else 0, a))
            def chunk(name, payload):
                return struct.pack(">I", len(payload)) + name + payload + struct.pack(">I", zlib.crc32(name + payload))
            png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            png += chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
            previews[size] = {"size": size, "source": "data:image/png;base64," + base64.b64encode(png).decode()}
        return list(previews.values())
    except (OSError, ValueError, struct.error):
        return []


def themes():
    found = {}
    for base in icon_roots():
        if not base.is_dir():
            continue
        for folder in sorted(base.iterdir()):
            if folder.name in found or not (folder / "cursors").is_dir():
                continue
            if not re.fullmatch(r"[A-Za-z0-9._-]{1,128}", folder.name):
                continue
            label = folder.name
            ini = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                ini.read(folder / "index.theme")
                label = ini.get("Icon Theme", "Name", fallback=label)
            except (configparser.Error, UnicodeError):
                pass  # A missing display name does not invalidate cursor files.
            pointer = folder / "cursors/left_ptr"
            if not pointer.exists():
                pointer = folder / "cursors/default"
            found[folder.name] = {"key": folder.name, "label": label, "previews": cursor_previews(pointer)}
    return sorted(found.values(), key=lambda item: item["label"].casefold())


def read():
    theme, size = os.environ.get("XCURSOR_THEME", "default"), 24
    ini = configparser.ConfigParser(interpolation=None, strict=False)
    ini.read(config_home() / "gtk-3.0/settings.ini")
    theme = ini.get("Settings", "gtk-cursor-theme-name", fallback=theme)
    try:
        size = ini.getint("Settings", "gtk-cursor-theme-size", fallback=24)
    except ValueError:
        size = 24
    files, _ = niri.collect_files(niri.niri_config_path())
    for entry in files:
        for node in entry["nodes"] or []:
            if node["commented"] or node["name"] != "cursor":
                continue
            for child in niri._active_children(node):
                if child["name"] == "xcursor-theme":
                    theme = niri._string_value(child) or theme
                if child["name"] == "xcursor-size":
                    size = niri._number_value(child) or size
    return {"ok": True, "themes": themes(), "theme": theme, "size": size}


def ini_patch(text, section, values):
    """Keep unrelated lines, comments and case; replace only owned keys."""
    lines = text.splitlines(keepends=True)
    result, active, seen, exists = [], False, set(), False
    def missing():
        return [f"{key}={value}\n" for key, value in values.items() if key not in seen]
    for line in lines:
        match = re.match(r"\s*\[([^]]+)\]", line)
        if match:
            if active:
                result.extend(missing())
            active = match[1] == section
            exists |= active
        key = line.split("=", 1)[0].strip() if "=" in line else ""
        if active and key in values:
            if key not in seen:
                result.append(f"{key}={values[key]}\n")
                seen.add(key)
        else:
            result.append(line if line.endswith("\n") else line + "\n")
    if active:
        result.extend(missing())
    if not exists:
        result.extend([f"\n[{section}]\n", *missing()])
    return "".join(result)


def command(args, input_text=None):
    if not shutil.which(args[0]):
        return False
    try:
        return subprocess.run(args, input=input_text, text=True, capture_output=True, timeout=8).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def file_plan(theme, size):
    cfg = config_home()
    planned = {}
    def patch(path, section, values):
        if path.is_symlink():
            raise niri.ApplyError(f"{path}: символическая ссылка; файл не изменён")
        old = path.read_text() if path.exists() else ""
        planned[path] = ini_patch(old, section, values)
    for version in ("3.0", "4.0"):
        patch(cfg / f"gtk-{version}/settings.ini", "Settings", {
            "gtk-cursor-theme-name": theme, "gtk-cursor-theme-size": size})
    gtk2 = Path.home() / ".gtkrc-2.0"
    old = gtk2.read_text() if gtk2.exists() else ""
    old = re.sub(r"^\s*gtk-cursor-theme-(name|size)\s*=.*\n?", "", old, flags=re.MULTILINE)
    planned[gtk2] = old.rstrip("\n") + f'\ngtk-cursor-theme-name = "{theme}"\ngtk-cursor-theme-size = {size}\n'
    for base in icon_roots()[:2]:
        patch(base / "default/index.theme", "Icon Theme", {"Inherits": theme})
    env = cfg / "environment.d/90-nayori-cursor.conf"
    planned[env] = f"XCURSOR_THEME={theme}\nXCURSOR_SIZE={size}\n"
    resources = Path.home() / ".Xresources"
    old = resources.read_text() if resources.exists() else ""
    old = re.sub(r"^\s*Xcursor\.(theme|size)\s*:.*\n?", "", old, flags=re.MULTILINE)
    planned[resources] = old.rstrip("\n") + f"\nXcursor.theme: {theme}\nXcursor.size: {size}\n"
    return planned


def apply(theme, size, live=False, validator=None):
    changes = {"cursor": {"theme": theme, "size": size}}
    # Validate input and the whole include tree before touching any file.
    niri.plan_changes(niri.niri_config_path(), changes)
    size = int(size)
    if theme not in {item["key"] for item in themes()}:
        raise niri.ApplyError("Тема курсора не установлена")
    planned = file_plan(theme, size)
    originals, backups = {}, []
    for path in planned:
        if path.is_symlink():
            raise niri.ApplyError(f"{path}: символическая ссылка; файл не изменён")
        originals[path] = path.read_bytes() if path.exists() else None
    written = []
    try:
        for path, text in planned.items():
            if originals[path] == text.encode():
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            if originals[path] is not None:
                backups.append(str(niri.write_backup(path, originals[path])))
            niri.atomic_write(path, text)
            written.append(path)
        result = niri.apply_changes(niri.niri_config_path(), changes, validator=validator)
        if not result["ok"]:
            raise niri.ApplyError(result["error"])
    except (OSError, niri.ApplyError):
        for path in reversed(written):
            if originals[path] is None:
                path.unlink(missing_ok=True)
            else:
                niri.atomic_write(path, originals[path])
        raise
    warnings = []
    if live:
        commands = [
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme],
            ["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(size)],
            ["systemctl", "--user", "set-environment", f"XCURSOR_THEME={theme}", f"XCURSOR_SIZE={size}"],
            ["dbus-update-activation-environment", f"XCURSOR_THEME={theme}", f"XCURSOR_SIZE={size}"],
        ]
        for args in commands:
            if not command(args):
                warnings.append(f"Не удалось обновить {args[0]} в текущей сессии")
        if os.environ.get("DISPLAY") and not command(["xrdb", "-merge"], f"Xcursor.theme: {theme}\nXcursor.size: {size}\n"):
            warnings.append("Не удалось обновить ресурсы X11")
        # Niri watches its config; no second IPC client or forced reload is needed.
    return {**read(), "backups": backups + result["backups"], "warnings": warnings,
            "notice": "Курсор сохранён. Для уже открытых приложений может потребоваться перезапуск; для всей сессии — повторный вход."}


def main():
    try:
        request = json.loads(sys.argv[1]) if len(sys.argv) > 1 else {"action": "read"}
        if request.get("action") == "apply":
            result = apply(request.get("theme"), request.get("size"), live=True)
        else:
            result = read()
    except (OSError, ValueError, configparser.Error, niri.ApplyError) as error:
        result = {"ok": False, "error": str(error)}
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
