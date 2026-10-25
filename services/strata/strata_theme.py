#!/usr/bin/env python3
"""Write Nayori's resolved colors into a Strata theme file.

AngelOS does this with scripts/strata-theme.py build PALETTE.json, which
writes ~/.config/strata/themes/angelos.toml. Strata watches that directory and
reloads the file when it changes. Selecting the theme is settings.toml
(`theme`, `mode`), and only while Strata is not running: a running Strata
writes its own settings back over the file.

This is the same file shape and the same two steps, using Nayori tokens only.
Strata's surface key paints the sidebar, the path bar, and the preview. Nayori's
surface token is the light raised gray, so those regions used to split away from
the file list. They now use the background neutral, the same fill as the file
list (Strata's background key). accent and accentSoft stay on selection and
syntax. No second palette is generated. The write is skipped when the text is
unchanged.

  strata_theme.py build --json '{...}' [--config-dir DIR]
  strata_theme.py build PALETTE.json
"""

import argparse
import json
import os
import re
import shutil
import sys
from pathlib import Path

THEME_ID = "nayori"
THEME_NAME = "nayori.toml"
ORDER = (
    "background",
    "surface",
    "muted",
    "highlight",
    "border",
    "text",
    "dim_text",
    "accent",
    "danger",
    "syntax_keyword",
    "syntax_string",
    "syntax_constant",
    "syntax_type",
    "syntax_preprocessor",
)
TOKEN_KEYS = (
    "background",
    "surface",
    "surfaceAlt",
    "text",
    "textMuted",
    "accent",
    "accentSoft",
    "secondary",
)

NOT_INSTALLED = "Strata не установлен. Тема не записана"
NO_CONFIG = "Каталог настроек Strata не найден. Тема не записана"
BAD_COLORS = "Не удалось прочитать цвета темы Strata"
WRITE_ERROR = "Не удалось записать тему Strata"
SETTINGS_MISSING = "Файл настроек Strata не найден. Цвета записаны в\u00a0файл темы"
RUNNING_NOTICE = "Strata открыт, тема в\u00a0настройках не переключена. Цвета записаны в\u00a0файл темы"


def fail(message):
    return {
        "ok": False,
        "changed": False,
        "path": "",
        "applied": False,
        "notice": "",
        "error": message,
    }


def config_dir(explicit):
    if explicit:
        return Path(explicit)
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "strata"


def find_binary(explicit):
    if explicit is not None:
        path = Path(explicit)
        return path if path.is_file() else None
    for candidate in (Path.home() / ".local/bin/strata", Path("/usr/bin/strata")):
        if candidate.is_file():
            return candidate
    found = shutil.which("strata")
    return Path(found) if found else None


def normalize_hex(value):
    text = str(value or "").strip()
    if text.startswith("#"):
        text = text[1:]
    if len(text) == 3:
        text = text[0] * 2 + text[1] * 2 + text[2] * 2
    elif len(text) == 8:
        text = text[2:]
    if len(text) != 6 or any(char not in "0123456789abcdefABCDEF" for char in text):
        return ""
    return "#" + text.upper()


def strata_colors(palette):
    # File list is Strata background. Sidebar, path bar, and preview are all
    # Strata surface (.sidebar, headerbar, .preview-pane). Nayori surface is the
    # light raised gray, which made those three a separate panel. AngelOS keeps
    # the sidebar on the desk family; the dark neutral here is background.
    # surfaceAlt stays on muted and border. accentSoft stays the selection.
    colors = {key: normalize_hex(palette.get(key)) for key in TOKEN_KEYS}
    if any(not colors[key] for key in TOKEN_KEYS):
        return None
    alt = colors["surfaceAlt"]
    accent = colors["accent"]
    soft = colors["accentSoft"]
    secondary = colors["secondary"]
    dim = colors["textMuted"]
    return {
        "background": colors["background"],
        "surface": colors["background"],
        "muted": alt,
        "highlight": soft,
        "border": alt,
        "text": colors["text"],
        "dim_text": dim,
        "accent": accent,
        "danger": secondary,
        "syntax_keyword": accent,
        "syntax_string": secondary,
        "syntax_constant": soft,
        "syntax_type": dim,
        "syntax_preprocessor": accent,
    }


def render(colors):
    lines = [
        "# nayori - written by nayori (services/strata/strata_theme.py)",
        'name = "nayori"',
    ]
    lines.extend(f'{key} = "{colors[key]}"' for key in ORDER)
    return "\n".join(lines) + "\n"


def atomic_write(path, text, tmp_name, mode=None):
    tmp = path.with_name(tmp_name)
    try:
        tmp.write_text(text)
        if mode is not None:
            tmp.chmod(mode)
        os.replace(tmp, path)
    except Exception:
        try:
            tmp.unlink()
        except OSError:
            pass
        raise


def write_if_changed(path, text, tmp_name, mode=None):
    if path.is_file():
        try:
            current = path.read_text()
        except OSError as error:
            raise OSError("read") from error
        if current == text:
            return False
    atomic_write(path, text, tmp_name, mode)
    return True


def strata_running(mode):
    if mode == "yes":
        return True
    if mode == "no":
        return False
    try:
        entries = list(Path("/proc").iterdir())
    except OSError:
        return True
    for entry in entries:
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            if Path(os.readlink(entry / "exe")).name == "strata":
                return True
        except OSError:
            continue
    return False


def setting(text, key):
    match = re.search(rf'(?m)^{key}\s*=\s*"([^"]*)"', text)
    return match.group(1) if match else None


def put(text, key, value):
    line = f'{key} = "{value}"'
    if re.search(rf"(?m)^{key}\s*=", text):
        return re.sub(rf"(?m)^{key}\s*=.*$", line, text, count=1)
    table = re.search(r"(?m)^\[", text)
    if table:
        return text[:table.start()] + line + "\n" + text[table.start():]
    suffix = "" if text.endswith("\n") or text == "" else "\n"
    return text + suffix + line + "\n"


def select_theme(settings_path, running):
    if not settings_path.is_file():
        return False, False, SETTINGS_MISSING
    try:
        text = settings_path.read_text()
    except OSError as error:
        raise OSError("read") from error
    if setting(text, "theme") == THEME_ID and setting(text, "mode") in (None, "theme"):
        return True, False, ""
    if running:
        return False, False, RUNNING_NOTICE
    updated = put(put(text, "mode", "theme"), "theme", THEME_ID)
    changed = write_if_changed(settings_path, updated, ".settings.toml.nayori", 0o600)
    return True, changed, ""


def load_palette(args):
    if args.json:
        raw = args.json
    elif args.palette:
        raw = Path(args.palette).read_text()
    else:
        return None
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        return None
    return parsed


def build(args):
    if find_binary(args.strata_bin) is None:
        return fail(NOT_INSTALLED)
    root = config_dir(args.config_dir)
    if not root.is_dir():
        return fail(NO_CONFIG)
    try:
        palette = load_palette(args)
    except (OSError, ValueError):
        return fail(BAD_COLORS)
    colors = strata_colors(palette or {})
    if colors is None:
        return fail(BAD_COLORS)
    theme_path = root / "themes" / THEME_NAME
    settings_path = root / "settings.toml"
    try:
        theme_path.parent.mkdir(exist_ok=True)
        theme_changed = write_if_changed(theme_path, render(colors), ".nayori.toml.tmp")
        applied, settings_changed, notice = select_theme(settings_path, strata_running(args.strata_running))
    except OSError:
        return fail(WRITE_ERROR)
    return {
        "ok": True,
        "changed": bool(theme_changed or settings_changed),
        "path": str(theme_path),
        "applied": applied,
        "notice": notice,
        "error": "",
    }


def main():
    parser = argparse.ArgumentParser(description="Write Nayori colors into a Strata theme")
    parser.add_argument("action", nargs="?", default="build")
    parser.add_argument("palette", nargs="?")
    parser.add_argument("--json", default="")
    parser.add_argument("--config-dir", default="")
    parser.add_argument("--strata-bin", default=None)
    parser.add_argument("--strata-running", choices=("auto", "yes", "no"), default="auto")
    args = parser.parse_args()
    if args.action != "build":
        result = fail(WRITE_ERROR)
    else:
        try:
            result = build(args)
        except Exception:
            result = fail(WRITE_ERROR)
    json.dump(result, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
