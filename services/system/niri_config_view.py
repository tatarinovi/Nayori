#!/usr/bin/env python3
"""Read niri config and keyboard layouts. This script never writes."""

import json
import os
import re
import subprocess
from pathlib import Path

MAX_BYTES = 1_000_000
MAX_TEXT = 4000
MAX_BINDS = 300


def config_path():
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "niri" / "config.kdl"


def inside(root, path):
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def strip_comments(text):
    lines = []
    for line in text.splitlines():
        quote = False
        index = 0
        kept = []
        while index < len(line):
            char = line[index]
            if char == '"':
                quote = not quote
                kept.append(char)
            elif char == "\\" and quote:
                kept.append(line[index:index + 2])
                index += 2
                continue
            elif not quote and line.startswith("//", index):
                break
            else:
                kept.append(char)
            index += 1
        lines.append("".join(kept))
    return "\n".join(lines)


def blocks(text, keyword):
    results = []
    pattern = re.compile(r"(^|[\s{])" + re.escape(keyword) + r"\s*\{")
    for match in pattern.finditer(text):
        start = match.end() - 1
        depth = 0
        quote = False
        index = start
        while index < len(text):
            char = text[index]
            if char == '"':
                quote = not quote
            elif not quote and char == "{":
                depth += 1
            elif not quote and char == "}":
                depth -= 1
                if depth == 0:
                    results.append(text[start + 1:index].strip())
                    break
            index += 1
    return results


def parse_binds(body):
    entries = []
    index = 0
    size = len(body)
    while index < size and len(entries) < MAX_BINDS:
        while index < size and body[index].isspace():
            index += 1
        if index >= size:
            break
        start = index
        quote = False
        while index < size:
            char = body[index]
            if char == '"':
                quote = not quote
            elif not quote and char == "{":
                break
            index += 1
        header = body[start:index].strip()
        if index >= size or body[index] != "{":
            break
        depth = 0
        quote = False
        index += 1
        action_start = index
        closed = False
        while index < size:
            char = body[index]
            if char == '"':
                quote = not quote
            elif not quote and char == "{":
                depth += 1
            elif not quote and char == "}":
                if depth == 0:
                    action = body[action_start:index].strip()
                    index += 1
                    closed = True
                    break
                depth -= 1
            index += 1
        if not closed or not header or header.startswith("/-"):
            continue
        keys = header.split()[0]
        if not keys or keys.startswith("//"):
            continue
        title = ""
        title_match = re.search(r'hotkey-overlay-title="([^"]*)"', header)
        if title_match:
            title = title_match.group(1)
        action_name = action.strip().rstrip(";").split()[0] if action.strip() else ""
        entries.append({"keys": keys, "title": title, "action": action_name})
    return entries


def clip(text):
    cleaned = text.strip()
    if len(cleaned) <= MAX_TEXT:
        return cleaned
    return cleaned[:MAX_TEXT].rstrip() + "\n…"


def read_tree(start):
    root = start.parent
    warnings = []
    files = []
    queue = [start]
    seen = set()
    while queue and len(files) < 32:
        path = queue.pop(0)
        try:
            real = path.resolve()
        except OSError:
            warnings.append(f"Не удалось открыть {path.name}")
            continue
        if real in seen or not inside(root, real):
            if real not in seen and not inside(root, real):
                warnings.append(f"Пропущен include вне каталога niri: {path.name}")
            continue
        seen.add(real)
        try:
            if real.stat().st_size > MAX_BYTES:
                warnings.append(f"Файл слишком большой и пропущен: {real.name}")
                continue
            text = real.read_text(encoding="utf-8", errors="replace")
        except OSError:
            warnings.append(f"Не удалось прочитать {real.name}")
            continue
        files.append((real, text))
        stripped = strip_comments(text)
        for match in re.finditer(r'^\s*include\s+"([^"]+)"', stripped, re.M):
            queue.append((real.parent / match.group(1)))
    return files, warnings


def layouts():
    if not os.environ.get("NIRI_SOCKET", "").strip():
        return {"available": False, "text": "Сокет niri не задан. Текущие раскладки не прочитаны"}
    try:
        result = subprocess.run(
            ["niri", "msg", "-j", "keyboard-layouts"],
            capture_output=True, text=True, timeout=2, check=False,
        )
    except FileNotFoundError:
        return {"available": False, "text": "Команда niri не найдена"}
    except subprocess.TimeoutExpired:
        return {"available": False, "text": "niri не ответил вовремя"}
    if result.returncode != 0:
        message = (result.stderr or result.stdout or "").strip()
        return {"available": False, "text": message or "niri не вернул раскладки"}
    raw = result.stdout.strip()
    try:
        raw = json.dumps(json.loads(raw), ensure_ascii=False, indent=2)
    except json.JSONDecodeError:
        pass
    return {"available": True, "text": clip(raw)}


def main():
    path = config_path()
    payload = {
        "ok": False,
        "error": "",
        "warnings": [],
        "binds": [],
        "mouse": "",
        "keyboard": "",
        "touchpad": "",
        "layout": "",
        "layouts": layouts(),
    }
    if not path.is_file():
        payload["error"] = "Файл конфигурации niri не найден"
        print(json.dumps(payload, ensure_ascii=False))
        return
    files, warnings = read_tree(path)
    payload["warnings"] = warnings
    binds = []
    mouse, keyboard, touchpad, layout = [], [], [], []
    for _file, text in files:
        stripped = strip_comments(text)
        for body in blocks(stripped, "binds"):
            binds.extend(parse_binds(body))
        mouse.extend(blocks(stripped, "mouse"))
        keyboard.extend(blocks(stripped, "keyboard"))
        touchpad.extend(blocks(stripped, "touchpad"))
        layout.extend(blocks(stripped, "layout"))
    payload["ok"] = True
    payload["binds"] = binds[:MAX_BINDS]
    payload["mouse"] = clip("\n\n".join(mouse))
    payload["keyboard"] = clip("\n\n".join(keyboard))
    payload["touchpad"] = clip("\n\n".join(touchpad))
    payload["layout"] = clip("\n\n".join(layout))
    print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
