#!/usr/bin/env python3
"""Surgically edit a niri config and roll it back.

This module can write the config file it is pointed at. apply_changes() never
reloads a running niri session. live_reload() is the only function that runs
`niri msg action load-config-file`, and tests must not call it.

Reads of `niri msg -j outputs` happen only from fetch_outputs().
"""

import hashlib
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

MAX_BYTES = 1_000_000
MAX_FILES = 32
CONFIRM_SECONDS = 15
PROTECTED_NAMES = {"noctalia.kdl", "nayori-accent.kdl", "nayori-overview.kdl"}
BACKUP_MODE = 0o600

TRANSFORMS = (
    "normal", "90", "180", "270",
    "flipped", "flipped-90", "flipped-180", "flipped-270",
)
SCROLL_METHODS = ("no-scroll", "two-finger", "edge", "on-button-down")
ACCEL_PROFILES = ("flat", "adaptive")
CLICK_METHODS = ("button-areas", "clickfinger")
TAP_MAPS = ("left-right-middle", "left-middle-right")
TRACK_LAYOUTS = ("global", "window")
VRR_MODES = ("off", "on", "on-demand")

OUTPUT_FIELDS = {
    "mode", "scale", "transform", "position", "off", "variable-refresh-rate",
    "focus-at-startup",
}
MOUSE_FIELDS = {
    "off", "natural-scroll", "left-handed", "middle-emulation",
    "accel-speed", "accel-profile", "scroll-method", "scroll-factor",
}
TOUCHPAD_FIELDS = MOUSE_FIELDS | {
    "tap", "dwt", "dwtp", "drag", "drag-lock", "click-method",
    "tap-button-map", "disabled-on-external-mouse", "scroll-button",
    "scroll-button-lock",
}
KEYBOARD_FIELDS = {
    "layout", "variant", "options", "repeat-delay", "repeat-rate",
    "track-layout", "numlock",
}
FLAG_FIELDS = {
    "off", "natural-scroll", "left-handed", "middle-emulation", "tap", "dwt",
    "dwtp", "drag-lock", "disabled-on-external-mouse", "scroll-button-lock",
}
DEVICE_SECTIONS = {"mouse": MOUSE_FIELDS, "touchpad": TOUCHPAD_FIELDS}


class ApplyError(Exception):
    pass


class ParseError(ApplyError):
    pass


def view_config_path():
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "niri" / "config.kdl"


def niri_config_path():
    override = os.environ.get("NIRI_CONFIG", "").strip()
    if override:
        return Path(override)
    return view_config_path()


def paths_differ(left, right):
    try:
        return left.resolve() != right.resolve()
    except OSError:
        return str(left) != str(right)


def niri_binary():
    return shutil.which("niri")


def fail(message, **extra):
    payload = {
        "ok": False,
        "changed": False,
        "error": message,
        "warnings": extra.get("warnings") or [],
        "backups": extra.get("backups") or [],
        "pending": None,
        "rolledBack": extra.get("rolledBack", False),
    }
    payload.update({key: value for key, value in extra.items() if key not in payload})
    return payload


def _hash_bytes(data):
    return hashlib.sha256(data).hexdigest()


def atomic_write(path, data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    parent = path.parent
    fd, tmp = tempfile.mkstemp(dir=str(parent), prefix="." + path.name + ".nayori-")
    replaced = False
    try:
        os.write(fd, data)
        os.fsync(fd)
        os.close(fd)
        fd = -1
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
        replaced = True
    finally:
        if fd >= 0:
            try:
                os.close(fd)
            except OSError:
                pass
        if not replaced:
            try:
                os.unlink(tmp)
            except OSError:
                pass


def write_backup(path, data):
    stamp = time.strftime("%Y%m%d%H%M%S") + "-" + secrets.token_hex(3)
    dest = path.parent / (".%s.nayori-backup-%s" % (path.name, stamp))
    fd = os.open(str(dest), os.O_WRONLY | os.O_CREAT | os.O_EXCL, BACKUP_MODE)
    try:
        os.write(fd, data)
        os.fsync(fd)
    finally:
        os.close(fd)
    return dest


def pending_path(root):
    return root.parent / (".%s.nayori-pending.json" % root.name)


def load_pending(root):
    path = pending_path(root)
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict) or not data.get("id"):
        return None
    return data


def save_pending(root, data):
    atomic_write(pending_path(root), json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def clear_pending(root):
    path = pending_path(root)
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def inside_dir(root, path):
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def quote_string(value):
    if not isinstance(value, str):
        raise ApplyError("Ожидалась строка")
    if len(value) > 512:
        raise ApplyError("Строка слишком длинная")
    pieces = ['"']
    for char in value:
        if char == "\\":
            pieces.append("\\\\")
        elif char == '"':
            pieces.append('\\"')
        elif char == "\n":
            raise ApplyError("Перенос строки в значении не поддерживается")
        elif ord(char) < 32:
            raise ApplyError("В значении есть управляющий символ")
        else:
            pieces.append(char)
    pieces.append('"')
    return "".join(pieces)


def format_number(value):
    number = float(value)
    if not (number == number) or number in (float("inf"), float("-inf")):
        raise ApplyError("Число не подходит")
    if abs(number - round(number)) < 1e-9:
        return str(int(round(number)))
    text = ("%.4f" % number).rstrip("0").rstrip(".")
    return text


def _skip_ignored(text, index, newlines=True):
    size = len(text)
    while index < size:
        if text.startswith("/*", index):
            end = text.find("*/", index + 2)
            if end < 0:
                raise ParseError("Незакрытый комментарий")
            index = end + 2
            continue
        if text.startswith("//", index):
            end = text.find("\n", index)
            index = size if end < 0 else end
            continue
        char = text[index]
        if char in " \t\r":
            index += 1
            continue
        if char == "\n" and newlines:
            index += 1
            continue
        if char == "\\" and index + 1 < size and text[index + 1] == "\n":
            index += 2
            continue
        break
    return index


def _parse_string(text, index):
    size = len(text)
    if text.startswith("r", index):
        cursor = index + 1
        hashes = 0
        while cursor < size and text[cursor] == "#":
            hashes += 1
            cursor += 1
        if cursor >= size or text[cursor] != '"':
            raise ParseError("Неразобранная строка")
        cursor += 1
        closer = '"' + ("#" * hashes)
        end = text.find(closer, cursor)
        if end < 0:
            raise ParseError("Незакрытая строка")
        return ("string", text[cursor:end]), end + len(closer)
    if index >= size or text[index] != '"':
        raise ParseError("Неразобранная строка")
    cursor = index + 1
    chars = []
    while cursor < size:
        char = text[cursor]
        if char == '"':
            return ("string", "".join(chars)), cursor + 1
        if char == "\\":
            if cursor + 1 >= size:
                raise ParseError("Незакрытая строка")
            escaped = text[cursor + 1]
            mapping = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"'}
            if escaped not in mapping:
                raise ParseError("Неизвестное экранирование в строке")
            chars.append(mapping[escaped])
            cursor += 2
            continue
        if char == "\n":
            raise ParseError("Перенос внутри строки")
        chars.append(char)
        cursor += 1
    raise ParseError("Незакрытая строка")


def _parse_number(text, index):
    size = len(text)
    start = index
    if index < size and text[index] in "+-":
        index += 1
    if index >= size or not text[index].isdigit():
        return None
    while index < size and text[index].isdigit():
        index += 1
    if index < size and text[index] == ".":
        fraction = index + 1
        if fraction < size and text[fraction].isdigit():
            index = fraction
            while index < size and text[index].isdigit():
                index += 1
    raw = text[start:index]
    try:
        numeric = float(raw)
    except ValueError:
        return None
    return ("number", numeric, raw), index


def _ident_char(char):
    return char not in " \t\r\n{}[]()=;,\"#"


def _parse_ident(text, index):
    size = len(text)
    start = index
    if index < size and text[index] == "/" and text.startswith(("/-", "//", "/*"), index):
        raise ParseError("Комментарий вместо имени")
    while index < size and _ident_char(text[index]):
        if text[index] == "/" and index + 1 < size and text[index + 1] in "/*":
            break
        index += 1
    if index == start:
        raise ParseError("Пустое имя узла")
    return text[start:index], index


def _keyword_value(token):
    if token == "true":
        return ("bool", True)
    if token == "false":
        return ("bool", False)
    if token == "null":
        return ("null", None)
    return ("ident", token)


def _parse_value(text, index):
    index = _skip_ignored(text, index, newlines=False)
    if index >= len(text):
        raise ParseError("Нет значения")
    if text[index] == '"':
        return _parse_string(text, index)
    if text[index] == "r" and index + 1 < len(text) and text[index + 1] in '#"':
        return _parse_string(text, index)
    number = _parse_number(text, index)
    if number is not None:
        return number
    ident, index = _parse_ident(text, index)
    return _keyword_value(ident), index


def _skip_type(text, index):
    if index >= len(text) or text[index] != "(":
        return index
    depth = 0
    quote = False
    while index < len(text):
        char = text[index]
        if char == '"' and not quote:
            quote = True
        elif char == '"' and quote:
            quote = False
        elif not quote and char == "(":
            depth += 1
        elif not quote and char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    raise ParseError("Незакрытая аннотация типа")


def parse_node(text, index):
    size = len(text)
    index = _skip_ignored(text, index, newlines=False)
    start = index
    name, index = _parse_ident(text, index)
    content_end = index
    # A trailing comment is not part of the node. Only a real type annotation
    # extends the span past the name.
    looked = _skip_ignored(text, index, newlines=False)
    typed = _skip_type(text, looked)
    if typed != looked:
        index = typed
        content_end = index
    args = []
    props = []
    children = None
    brace = None
    close = None
    while index < size:
        index = _skip_ignored(text, index, newlines=False)
        if index >= size:
            break
        char = text[index]
        if char in "\n;":
            if char == ";":
                index += 1
            break
        if char == "{":
            children, brace, close, index = _parse_children(text, index)
            content_end = index
            break
        if char == "}":
            break
        if char == "/" and text.startswith(("//", "/*"), index):
            break
        if _ident_char(char) or char in "+-":
            number = _parse_number(text, index) if char in "+-" or char.isdigit() else None
            if number is not None and char in "+-" or char.isdigit():
                value, index = number
                args.append(value)
                content_end = index
                continue
            ident, next_index = _parse_ident(text, index)
            probe = _skip_ignored(text, next_index, newlines=False)
            if probe < size and text[probe] == "=":
                value, index = _parse_value(text, probe + 1)
                props.append((ident, value))
                content_end = index
                continue
            args.append(_keyword_value(ident))
            index = next_index
            content_end = index
            continue
        if char in "\"r":
            value, index = _parse_value(text, index)
            args.append(value)
            content_end = index
            continue
        raise ParseError("Неразобранный фрагмент около «%s»" % text[index:index + 12].replace("\n", " "))
    return {
        "name": name,
        "start": start,
        "content_end": content_end,
        "end": index,
        "args": args,
        "props": props,
        "children": children,
        "brace": brace,
        "close": close,
        "commented": False,
    }, index


def _parse_children(text, brace):
    index = brace + 1
    nodes = []
    size = len(text)
    while index < size:
        index = _skip_ignored(text, index, newlines=True)
        if index >= size:
            raise ParseError("Незакрытая скобка")
        if text[index] == "}":
            return nodes, brace, index, index + 1
        commented = False
        if text.startswith("/-", index):
            commented = True
            index = _skip_ignored(text, index + 2, newlines=True)
            if index >= size:
                raise ParseError("Комментарий / - без узла")
        node, index = parse_node(text, index)
        node["commented"] = commented
        nodes.append(node)
    raise ParseError("Незакрытая скобка")


def parse_document(text):
    index = 0
    if text.startswith("\ufeff"):
        raise ParseError("Файл начинается с BOM. Nayori его не меняет")
    nodes = []
    size = len(text)
    while index < size:
        index = _skip_ignored(text, index, newlines=True)
        if index >= size:
            break
        if text[index] == "}":
            raise ParseError("Лишняя закрывающая скобка")
        commented = False
        if text.startswith("/-", index):
            commented = True
            index = _skip_ignored(text, index + 2, newlines=True)
            if index >= size:
                raise ParseError("Комментарий / - без узла")
        node, index = parse_node(text, index)
        node["commented"] = commented
        nodes.append(node)
    return nodes


def _string_args(node):
    return [value[1] for value in node["args"] if value[0] == "string"]


def _prop_map(node):
    return {name: value for name, value in node["props"]}


def _active_children(node, name=None):
    if not node or node.get("children") is None:
        return []
    found = []
    for child in node["children"]:
        if child["commented"]:
            continue
        if name is None or child["name"] == name:
            found.append(child)
    return found


def _require_one(nodes, label):
    if len(nodes) > 1:
        raise ApplyError("Несколько узлов «%s». Nayori не выбирает один из них и файл не меняет" % label)
    return nodes[0] if nodes else None


def _line_indent_before(text, index):
    start = text.rfind("\n", 0, index) + 1
    line = text[start:index]
    return line[:len(line) - len(line.lstrip(" \t"))]


def _child_indent(text, parent):
    for child in _active_children(parent):
        start = child["start"]
        line_start = text.rfind("\n", 0, start) + 1
        prefix = text[line_start:start]
        if prefix.strip() == "":
            return prefix
    base = _line_indent_before(text, parent["start"])
    return base + "    "


def _number_value(node):
    for value in node["args"]:
        if value[0] == "number":
            return value[1]
    return None


def _string_value(node):
    strings = _string_args(node)
    return strings[0] if strings else None


def _flag_enabled(node):
    if node is None:
        return False
    for value in node["args"]:
        if value[0] == "bool":
            return value[1] is True
    return True


def _bool_arg(node):
    if node is None:
        return None
    for value in node["args"]:
        if value[0] == "bool":
            return value[1]
    return None


def remove_node(text, node):
    start = node["start"]
    end = node["content_end"]
    line_start = text.rfind("\n", 0, start) + 1
    line_break = text.find("\n", end)
    line_end = len(text) if line_break < 0 else line_break + 1
    prefix = text[line_start:start]
    suffix = text[end:line_end]
    comment = suffix.lstrip(" \t")
    if prefix.strip() == "" and (suffix.strip() == "" or comment.startswith("//") or comment.startswith("/*")):
        if suffix.strip() == "":
            return text[:line_start] + text[line_end:]
        kept = prefix + suffix.lstrip(" \t")
        if not kept.endswith("\n") and line_break >= 0:
            kept += "\n"
        return text[:line_start] + kept + text[line_end:]
    return text[:start] + text[end:]


def replace_node(text, node, rendered):
    return text[:node["start"]] + rendered + text[node["content_end"]:]


def insert_child_line(text, parent, rendered):
    if parent.get("close") is None:
        raise ApplyError("У блока «%s» нет скобок. Nayori не переписывает его целиком" % parent["name"])
    indent = _child_indent(text, parent)
    close = parent["close"]
    addition = indent + rendered + "\n"
    return text[:close] + addition + text[close:]


def _navigate(nodes, names):
    current_nodes = nodes
    parent = None
    for name in names:
        parent = _require_one(
            [node for node in current_nodes if node["name"] == name and not node["commented"]],
            name,
        )
        if parent is None:
            return None
        current_nodes = parent["children"] or []
    return parent


def ensure_path(text, names):
    nodes = parse_document(text)
    current = nodes
    parent = None
    built = text
    for depth, name in enumerate(names):
        found = [node for node in current if node["name"] == name and not node["commented"]]
        node = _require_one(found, name)
        if node is None:
            if parent is None:
                if built and not built.endswith("\n"):
                    built += "\n"
                built += name + " {\n}\n"
            else:
                indent = _child_indent(built, parent)
                raw = indent + name + " {\n" + indent + "}\n"
                built = built[:parent["close"]] + raw + built[parent["close"]:]
            nodes = parse_document(built)
            parent = _navigate(nodes, names[:depth + 1])
            if parent is None:
                raise ApplyError("Не удалось добавить блок «%s»" % name)
            current = parent["children"] or []
            continue
        if node.get("children") is None:
            raise ApplyError("Блок «%s» записан без скобок. Nayori не переписывает его целиком" % name)
        parent = node
        current = node["children"]
    return built, parent


def set_child(text, parent, rendered_name, rendered):
    found = _active_children(parent, rendered_name)
    if len(found) > 1:
        raise ApplyError(
            "В блоке «%s» несколько строк %s. Файл не изменён" % (parent["name"], rendered_name)
        )
    if rendered is None:
        if not found:
            return text
        return remove_node(text, found[0])
    if not found:
        return insert_child_line(text, parent, rendered)
    current = text[found[0]["start"]:found[0]["content_end"]]
    if current == rendered:
        return text
    return replace_node(text, found[0], rendered)


def _output_nodes(nodes, name):
    found = []
    for node in nodes:
        if node["commented"] or node["name"] != "output":
            continue
        if name in _string_args(node):
            found.append(node)
    return found


def _append_output(text, name, lines):
    if text and not text.endswith("\n"):
        text += "\n"
    block = "output " + quote_string(name) + " {\n"
    for line in lines:
        block += "    " + line + "\n"
    block += "}\n"
    return text + block


def _output_state(node):
    children = {child["name"]: child for child in _active_children(node)}
    position = None
    if "position" in children:
        props = _prop_map(children["position"])
        x_value = props.get("x")
        y_value = props.get("y")
        if x_value and x_value[0] == "number" and y_value and y_value[0] == "number":
            position = {"x": int(x_value[1]), "y": int(y_value[1])}
    vrr = "off"
    if "variable-refresh-rate" in children:
        demand = _prop_map(children["variable-refresh-rate"]).get("on-demand")
        if demand and demand[0] == "bool" and demand[1] is True:
            vrr = "on-demand"
        else:
            vrr = "on"
    extra = sorted(set(children) - OUTPUT_FIELDS)
    return {
        "mode": _string_value(children["mode"]) if "mode" in children else None,
        "scale": _number_value(children["scale"]) if "scale" in children else None,
        "transform": _string_value(children["transform"]) if "transform" in children else None,
        "position": position,
        "off": "off" in children,
        "vrr": vrr,
        "focusAtStartup": "focus-at-startup" in children,
        "extra": extra,
    }


def _device_state(node, fields):
    children = {child["name"]: child for child in _active_children(node)} if node else {}
    state = {}
    for field in sorted(fields):
        child = children.get(field)
        if field in FLAG_FIELDS:
            state[field] = child is not None
        elif field == "drag":
            state[field] = _bool_arg(child)
        elif field in ("accel-speed", "scroll-factor"):
            state[field] = _number_value(child) if child else None
        elif field == "scroll-button":
            state[field] = int(_number_value(child)) if child and _number_value(child) is not None else None
        else:
            state[field] = _string_value(child) if child else None
    if node:
        state["extra"] = sorted(set(children) - fields)
    else:
        state["extra"] = []
    return state


def _keyboard_state(node):
    children = {child["name"]: child for child in _active_children(node)} if node else {}
    xkb = children.get("xkb")
    xkb_children = {child["name"]: child for child in _active_children(xkb)} if xkb else {}
    numlock = children.get("numlock")
    enabled = False
    if numlock is not None:
        enabled = _flag_enabled(numlock)
    return {
        "layout": _string_value(xkb_children["layout"]) if "layout" in xkb_children else None,
        "variant": _string_value(xkb_children["variant"]) if "variant" in xkb_children else None,
        "options": _string_value(xkb_children["options"]) if "options" in xkb_children else None,
        "model": _string_value(xkb_children["model"]) if "model" in xkb_children else None,
        "rules": _string_value(xkb_children["rules"]) if "rules" in xkb_children else None,
        "repeat-delay": int(_number_value(children["repeat-delay"])) if "repeat-delay" in children and _number_value(children["repeat-delay"]) is not None else None,
        "repeat-rate": int(_number_value(children["repeat-rate"])) if "repeat-rate" in children and _number_value(children["repeat-rate"]) is not None else None,
        "track-layout": _string_value(children["track-layout"]) if "track-layout" in children else None,
        "numlock": enabled,
        "extra": sorted((set(children) - {"xkb", "repeat-delay", "repeat-rate", "track-layout", "numlock"}) | (set(xkb_children) - {"layout", "variant", "options", "model", "rules"})),
    }


def _include_paths(text, parent):
    paths = []
    for node in parse_document(text):
        if node["commented"] or node["name"] != "include":
            continue
        strings = _string_args(node)
        if strings:
            paths.append(parent / strings[0])
    return paths


def collect_files(root):
    warnings = []
    base = root.parent
    files = []
    queue = [root]
    seen = set()
    while queue and len(files) < MAX_FILES:
        path = queue.pop(0)
        try:
            real = path.resolve()
        except OSError:
            warnings.append("Не удалось открыть %s" % path.name)
            continue
        if real in seen:
            continue
        if not inside_dir(base, real):
            warnings.append("Пропущен include вне каталога niri: %s" % path.name)
            continue
        seen.add(real)
        try:
            if not real.is_file():
                warnings.append("Include не является файлом: %s" % path.name)
                continue
            if real.stat().st_size > MAX_BYTES:
                warnings.append("Файл слишком большой и пропущен: %s" % real.name)
                continue
            text = real.read_text(encoding="utf-8")
        except OSError:
            warnings.append("Не удалось прочитать %s" % real.name)
            continue
        try:
            nodes = parse_document(text)
        except ParseError as error:
            warnings.append("%s: %s" % (real.name, error))
            files.append({"path": real, "text": text, "nodes": None, "protected": real.name in PROTECTED_NAMES})
            continue
        files.append({
            "path": real,
            "text": text,
            "nodes": nodes,
            "protected": real.name in PROTECTED_NAMES,
        })
        for include in _include_paths(text, real.parent):
            queue.append(include)
    return files, warnings


def _section_node(files, section):
    found = []
    for entry in files:
        if not entry["nodes"]:
            continue
        for node in entry["nodes"]:
            if node["commented"] or node["name"] != "input" or node.get("children") is None:
                continue
            for child in _active_children(node, section):
                found.append((entry, node, child))
    return found


def read_config(path):
    path = Path(path)
    payload = {
        "ok": False,
        "error": "",
        "warnings": [],
        "config": str(path),
        "viewConfig": str(view_config_path()),
        "readerMismatch": paths_differ(path, view_config_path()) if path.exists() else False,
        "validateAvailable": niri_binary() is not None,
        "outputs": [],
        "mouse": None,
        "touchpad": None,
        "keyboard": None,
        "pending": _public_pending(load_pending(path)) if path.parent.exists() else None,
        "confirmSeconds": CONFIRM_SECONDS,
    }
    if not path.is_file():
        payload["error"] = "Файл конфигурации niri не найден"
        return payload
    try:
        files, warnings = collect_files(path)
    except OSError:
        payload["error"] = "Не удалось прочитать конфигурацию niri"
        return payload
    payload["warnings"] = warnings
    for entry in files:
        if not entry["nodes"]:
            continue
        for node in entry["nodes"]:
            if node["commented"] or node["name"] != "output":
                continue
            names = _string_args(node)
            if not names:
                continue
            state = _output_state(node)
            state.update({
                "name": names[0],
                "file": str(entry["path"]),
                "editable": not entry["protected"],
                "lockedReason": "Файл %s Nayori не меняет" % entry["path"].name if entry["protected"] else "",
            })
            payload["outputs"].append(state)
    for section in ("mouse", "touchpad"):
        found = _section_node(files, section)
        fields = DEVICE_SECTIONS[section]
        if not found:
            payload[section] = _device_state(None, fields)
            payload[section]["editable"] = True
            payload[section]["lockedReason"] = ""
            payload[section]["present"] = False
            continue
        entry, _input, child = found[-1]
        state = _device_state(child, fields)
        state["editable"] = not entry["protected"] and len(found) == 1
        state["present"] = True
        if entry["protected"]:
            state["lockedReason"] = "Блок %s записан в %s. Nayori этот файл не меняет" % (section, entry["path"].name)
        elif len(found) > 1:
            state["lockedReason"] = "Несколько блоков %s. Nayori не выбирает один из них" % section
            state["editable"] = False
        else:
            state["lockedReason"] = ""
        payload[section] = state
    keyboards = _section_node(files, "keyboard")
    if not keyboards:
        state = _keyboard_state(None)
        state.update({"editable": True, "lockedReason": "", "present": False})
    else:
        entry, _input, child = keyboards[-1]
        state = _keyboard_state(child)
        state["present"] = True
        state["editable"] = not entry["protected"] and len(keyboards) == 1
        if entry["protected"]:
            state["lockedReason"] = "Блок keyboard записан в %s. Nayori этот файл не меняет" % entry["path"].name
        elif len(keyboards) > 1:
            state["lockedReason"] = "Несколько блоков keyboard. Nayori не выбирает один из них"
        else:
            state["lockedReason"] = ""
    payload["keyboard"] = state
    payload["ok"] = True
    return payload


def _public_pending(data):
    if not data:
        return None
    return {
        "id": data.get("id"),
        "deadlineMs": data.get("deadlineMs"),
        "seconds": CONFIRM_SECONDS,
    }


def _check_output_name(name):
    if not isinstance(name, str) or not name.strip():
        raise ApplyError("Не указано имя монитора")
    cleaned = name.strip()
    if len(cleaned) > 128 or any(char in cleaned for char in "\n\"{}") or cleaned != name:
        raise ApplyError("Имя монитора содержит неподдерживаемый символ")
    return cleaned


def _check_mode(value):
    if value is None:
        return None
    if not isinstance(value, str):
        raise ApplyError("Режим должен быть строкой, например 1920x1080@60")
    text = value.strip()
    if text == "":
        return None
    parts = text.split("@", 1)
    size = parts[0].split("x")
    if len(size) != 2 or not all(piece.isdigit() and 0 < int(piece) <= 20000 for piece in size):
        raise ApplyError("Режим нужен в виде 1920x1080 или 1920x1080@60")
    if len(parts) == 2:
        refresh = parts[1]
        if not refresh or refresh.count(".") > 1:
            raise ApplyError("Частота в режиме записана не так, как ждёт niri")
        whole, _, fraction = refresh.partition(".")
        if not whole.isdigit() or (fraction and not fraction.isdigit()):
            raise ApplyError("Частота в режиме записана не так, как ждёт niri")
    return text


def _check_scale(value):
    if value is None:
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ApplyError("Масштаб должен быть числом")
    if number < 0.1 or number > 10:
        raise ApplyError("Масштаб здесь можно задать от 0,1 до 10")
    return number


def _check_position(value):
    if value is None:
        return None
    if not isinstance(value, dict):
        raise ApplyError("Положение задаётся числами X и Y")
    try:
        x_value = int(value.get("x"))
        y_value = int(value.get("y"))
    except (TypeError, ValueError):
        raise ApplyError("Положение X и Y должны быть целыми числами")
    for number in (x_value, y_value):
        if abs(number) > 100000:
            raise ApplyError("Положение слишком далеко от нуля")
    if float(value.get("x")) != x_value or float(value.get("y")) != y_value:
        raise ApplyError("Положение X и Y должны быть целыми числами")
    return x_value, y_value


def _check_choice(value, choices, label):
    if value is None or value == "":
        return None
    if value not in choices:
        raise ApplyError("%s: niri принимает %s" % (label, ", ".join(choices)))
    return value


def _check_unit_interval(value, label):
    if value is None or value == "":
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ApplyError("%s должно быть числом" % label)
    if number < -1 or number > 1:
        raise ApplyError("%s задаётся от −1 до 1" % label)
    return number


def _check_scroll_factor(value):
    if value is None or value == "":
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ApplyError("Множитель прокрутки должен быть числом")
    if number < 0 or number > 100:
        raise ApplyError("Множитель прокрутки задаётся от 0 до 100")
    return number


def _check_int_range(value, label, upper):
    if value is None or value == "":
        return None
    try:
        number = int(value)
    except (TypeError, ValueError):
        raise ApplyError("%s должно быть целым числом" % label)
    if isinstance(value, float) and not value.is_integer():
        raise ApplyError("%s должно быть целым числом" % label)
    if number < 0 or number > upper:
        raise ApplyError("%s задаётся от 0 до %s" % (label, upper))
    return number


def _render_output_field(field, value):
    if field == "mode":
        checked = _check_mode(value)
        return None if checked is None else "mode " + quote_string(checked)
    if field == "scale":
        checked = _check_scale(value)
        return None if checked is None else "scale " + format_number(checked)
    if field == "transform":
        checked = _check_choice(value, TRANSFORMS, "Поворот")
        return None if checked is None else "transform " + quote_string(checked)
    if field == "position":
        checked = _check_position(value)
        if checked is None:
            return None
        return "position x=%d y=%d" % checked
    if field == "off":
        return "off" if value is True else None
    if field == "variable-refresh-rate":
        if value in (None, "", "off", False):
            return None
        if value == "on":
            return "variable-refresh-rate"
        if value == "on-demand":
            return "variable-refresh-rate on-demand=true"
        raise ApplyError("Переменная частота: выключена, включена или по запросу окна")
    raise ApplyError("Параметр монитора «%s» эта страница не записывает" % field)


def _render_device_field(field, value):
    if field not in MOUSE_FIELDS | TOUCHPAD_FIELDS:
        raise ApplyError("Параметр «%s» эта страница не записывает" % field)
    if field in FLAG_FIELDS:
        if value is True:
            return field
        if value is False or value is None:
            return None
        raise ApplyError("«%s» можно только включить или убрать" % field)
    if field == "drag":
        if value is True:
            return "drag true"
        if value is False:
            return "drag false"
        if value is None or value == "":
            return None
        raise ApplyError("Перетаскивание можно включить, выключить или не задавать")
    if field == "accel-speed":
        number = _check_unit_interval(value, "Скорость")
        return None if number is None else "accel-speed " + format_number(number)
    if field == "scroll-factor":
        number = _check_scroll_factor(value)
        return None if number is None else "scroll-factor " + format_number(number)
    if field == "accel-profile":
        checked = _check_choice(value, ACCEL_PROFILES, "Профиль ускорения")
        return None if checked is None else "accel-profile " + quote_string(checked)
    if field == "scroll-method":
        checked = _check_choice(value, SCROLL_METHODS, "Прокрутка")
        return None if checked is None else "scroll-method " + quote_string(checked)
    if field == "click-method":
        checked = _check_choice(value, CLICK_METHODS, "Способ нажатия")
        return None if checked is None else "click-method " + quote_string(checked)
    if field == "tap-button-map":
        checked = _check_choice(value, TAP_MAPS, "Кнопки касания")
        return None if checked is None else "tap-button-map " + quote_string(checked)
    if field == "scroll-button":
        number = _check_int_range(value, "Кнопка прокрутки", 65535)
        return None if number is None else "scroll-button %d" % number
    raise ApplyError("Параметр «%s» эта страница не записывает" % field)


def _render_keyboard_field(field, value):
    if field in ("layout", "variant", "options"):
        if value is None:
            return None
        if not isinstance(value, str):
            raise ApplyError("Поле «%s» должно быть строкой" % field)
        return field + " " + quote_string(value)
    if field == "repeat-delay":
        number = _check_int_range(value, "Задержка повтора", 10000)
        return None if number is None else "repeat-delay %d" % number
    if field == "repeat-rate":
        number = _check_int_range(value, "Частота повтора", 255)
        return None if number is None else "repeat-rate %d" % number
    if field == "track-layout":
        checked = _check_choice(value, TRACK_LAYOUTS, "Область раскладки")
        return None if checked is None else "track-layout " + quote_string(checked)
    if field == "numlock":
        if value is True:
            return "numlock"
        return None
    raise ApplyError("Параметр клавиатуры «%s» эта страница не записывает" % field)


def _semantic_output_same(current, field, value):
    if field == "mode":
        wanted = None if value in (None, "") else value
        return current.get("mode") == wanted
    if field == "scale":
        have = current.get("scale")
        if value is None:
            return have is None
        try:
            number = float(value)
        except (TypeError, ValueError):
            return False
        return have is not None and abs(float(have) - number) < 1e-9
    if field == "transform":
        wanted = None if value in (None, "") else value
        return current.get("transform") == wanted
    if field == "position":
        have = current.get("position")
        if value is None:
            return have is None
        try:
            return have == {"x": int(value.get("x")), "y": int(value.get("y"))}
        except (AttributeError, TypeError, ValueError):
            return False
    if field == "off":
        return bool(current.get("off")) is (value is True)
    if field == "variable-refresh-rate":
        wanted = "off" if value in (None, "", False, "off") else value
        return current.get("vrr") == wanted
    return False


def _file_for_output(files, name):
    matches = []
    for entry in files:
        if not entry["nodes"]:
            continue
        nodes = _output_nodes(entry["nodes"], name)
        if nodes:
            matches.append((entry, nodes[-1]))
    return matches


def assign_primary(files, name):
    """Keep focus-at-startup on one output and drop it from the other editable blocks."""
    name = _check_output_name(name)
    for entry in files:
        if not entry["protected"] or not entry["nodes"]:
            continue
        for node in entry["nodes"]:
            if node["commented"] or node["name"] != "output":
                continue
            args = _string_args(node)
            if not args or args[0] == name:
                continue
            if "focus-at-startup" in {child["name"] for child in _active_children(node)}:
                raise ApplyError(
                    "Строка focus-at-startup записана в %s. Nayori этот файл не меняет" % entry["path"].name
                )
    updated = {}
    found = False
    for entry in files:
        if entry["protected"] or entry["nodes"] is None:
            continue
        names = []
        for node in entry["nodes"]:
            if node["commented"] or node["name"] != "output":
                continue
            args = _string_args(node)
            if args:
                names.append(args[0])
        text = updated.get(entry["path"], entry["text"])
        original = text
        for output_name in names:
            nodes = parse_document(text)
            current = _output_nodes(nodes, output_name)
            if not current:
                continue
            if output_name == name:
                found = True
                rendered = "focus-at-startup"
            else:
                rendered = None
            text = set_child(text, current[-1], "focus-at-startup", rendered)
        if text != original:
            updated[entry["path"]] = text
    if found:
        return updated
    for entry in files:
        if not entry["protected"] or not entry["nodes"]:
            continue
        for node in entry["nodes"]:
            if node["commented"] or node["name"] != "output":
                continue
            args = _string_args(node)
            if args and args[0] == name:
                raise ApplyError("Блок output для «%s» записан в %s. Nayori этот файл не меняет" % (
                    name, entry["path"].name
                ))
    main = files[0]
    text = updated.get(main["path"], main["text"])
    updated[main["path"]] = _append_output(text, name, ["focus-at-startup"])
    return updated


def transform_output(files, name, fields):
    unknown = set(fields) - OUTPUT_FIELDS
    if unknown:
        raise ApplyError("Параметр монитора «%s» эта страница не записывает" % ", ".join(sorted(unknown)))
    name = _check_output_name(name)
    matches = _file_for_output(files, name)
    target = None
    target_node = None
    for entry, node in matches:
        if not entry["protected"]:
            target = entry
            target_node = node
    if matches and target is None:
        raise ApplyError("Блок output для «%s» записан в %s. Nayori этот файл не меняет" % (
            name, matches[-1][0]["path"].name
        ))
    current = _output_state(target_node) if target_node else {
        "mode": None, "scale": None, "transform": None, "position": None, "off": False, "vrr": "off",
    }
    changes = []
    for field, value in fields.items():
        if _semantic_output_same(current, field, value):
            continue
        changes.append((field, _render_output_field(field, value)))
    if not changes:
        return {}
    if target is None:
        text = files[0]["text"]
        path = files[0]["path"]
        lines = [rendered for _field, rendered in changes if rendered]
        updated = _append_output(text, name, lines)
        # Removals on a missing block are a no-op; a creation with only removals
        # should not invent an empty block.
        if not lines:
            return {}
        return {path: updated}
    text = target["text"]
    for field, rendered in changes:
        actual = "variable-refresh-rate" if field == "variable-refresh-rate" else field
        nodes = parse_document(text)
        found = _output_nodes(nodes, name)
        if not found:
            if rendered is None:
                continue
            text = _append_output(text, name, [rendered])
            continue
        parent = found[-1]
        if rendered is None:
            text = set_child(text, parent, actual, None)
        else:
            text = set_child(text, parent, actual, rendered)
    if text == target["text"]:
        return {}
    return {target["path"]: text}


def _input_host(files):
    hosts = []
    for entry in files:
        if not entry["nodes"]:
            continue
        inputs = [node for node in entry["nodes"] if node["name"] == "input" and not node["commented"]]
        if len(inputs) > 1:
            raise ApplyError("В %s несколько блоков input. Файл не изменён" % entry["path"].name)
        if inputs:
            hosts.append((entry, inputs[0]))
    if len(hosts) > 1:
        raise ApplyError("Несколько блоков input. Nayori не выбирает один из них и файл не меняет")
    return hosts[0] if hosts else None


def _device_same(state, field, value):
    current = state.get(field)
    if field in FLAG_FIELDS:
        return bool(current) is (value is True)
    if field == "drag":
        if value in (None, ""):
            return current is None
        if value is True:
            return current is True
        if value is False:
            return current is False
        return False
    if field in ("accel-speed", "scroll-factor"):
        if value in (None, ""):
            return current is None
        try:
            return current is not None and abs(float(current) - float(value)) < 1e-9
        except (TypeError, ValueError):
            return False
    if field == "scroll-button":
        if value in (None, ""):
            return current is None
        try:
            return current == int(value)
        except (TypeError, ValueError):
            return False
    if value in (None, ""):
        return current in (None, "")
    return current == value


def _device_child(host, section):
    if not host:
        return None
    _entry, node = host
    found = _active_children(node, section)
    return found[-1] if found else None


def transform_device(files, section, fields):
    allowed = DEVICE_SECTIONS.get(section)
    if not allowed:
        raise ApplyError("Раздел «%s» эта страница не записывает" % section)
    unknown = set(fields) - allowed
    if unknown:
        raise ApplyError("Параметр «%s» niri в этом блоке не поддерживает, поэтому он не записан" % ", ".join(sorted(unknown)))
    host = _input_host(files)
    if host and host[0]["protected"]:
        raise ApplyError("Блок input записан в %s. Nayori этот файл не меняет" % host[0]["path"].name)
    state = _device_state(_device_child(host, section), allowed)
    fields = {key: value for key, value in fields.items() if not _device_same(state, key, value)}
    if not fields:
        return {}
    rendered = [(field, _render_device_field(field, value)) for field, value in fields.items()]
    if host is None:
        lines = [line for _field, line in rendered if line]
        if not lines:
            return {}
        text = files[0]["text"]
        if text and not text.endswith("\n"):
            text += "\n"
        body = "input {\n    %s {\n" % section
        for line in lines:
            body += "        " + line + "\n"
        body += "    }\n}\n"
        return {files[0]["path"]: text + body}
    entry, _input = host
    text = entry["text"]
    for field, line in rendered:
        text, parent = ensure_path(text, ["input", section])
        text = set_child(text, parent, field, line)
    if text == entry["text"]:
        return {}
    return {entry["path"]: text}


def _keyboard_same(current, field, value):
    have = current.get(field)
    if field == "numlock":
        return bool(have) is (value is True)
    if field in ("repeat-delay", "repeat-rate"):
        if value in (None, ""):
            return have is None
        try:
            return have == int(value)
        except (TypeError, ValueError):
            return False
    if value in (None, ""):
        return have in (None, "")
    return have == value


def transform_keyboard(files, fields):
    unknown = set(fields) - KEYBOARD_FIELDS
    if unknown:
        raise ApplyError("Параметр клавиатуры «%s» эта страница не записывает" % ", ".join(sorted(unknown)))
    host = _input_host(files)
    if host and host[0]["protected"]:
        raise ApplyError("Блок input записан в %s. Nayori этот файл не меняет" % host[0]["path"].name)
    current = _keyboard_state(_device_child(host, "keyboard"))
    fields = {key: value for key, value in fields.items() if not _keyboard_same(current, key, value)}
    if not fields:
        return {}
    xkb_fields = {key: fields[key] for key in ("layout", "variant", "options") if key in fields}
    direct = {key: fields[key] for key in ("repeat-delay", "repeat-rate", "track-layout", "numlock") if key in fields}
    if host is None:
        lines_direct = [(key, _render_keyboard_field(key, value)) for key, value in direct.items()]
        lines_xkb = [(key, _render_keyboard_field(key, value)) for key, value in xkb_fields.items()]
        if not any(line for _key, line in lines_direct + lines_xkb):
            return {}
        text = files[0]["text"]
        if text and not text.endswith("\n"):
            text += "\n"
        body = "input {\n    keyboard {\n"
        if any(line for _key, line in lines_xkb):
            body += "        xkb {\n"
            for _key, line in lines_xkb:
                if line:
                    body += "            " + line + "\n"
            body += "        }\n"
        for _key, line in lines_direct:
            if line:
                body += "        " + line + "\n"
        body += "    }\n}\n"
        return {files[0]["path"]: text + body}
    entry, _input = host
    text = entry["text"]
    if xkb_fields:
        text, parent = ensure_path(text, ["input", "keyboard", "xkb"])
        for field, value in xkb_fields.items():
            text = set_child(text, parent, field, _render_keyboard_field(field, value))
            text, parent = ensure_path(text, ["input", "keyboard", "xkb"])
    if direct:
        text, parent = ensure_path(text, ["input", "keyboard"])
        for field, value in direct.items():
            text = set_child(text, parent, field, _render_keyboard_field(field, value))
            text, parent = ensure_path(text, ["input", "keyboard"])
    if text == entry["text"]:
        return {}
    return {entry["path"]: text}


def plan_changes(path, changes):
    path = Path(path)
    if not isinstance(changes, dict) or not changes:
        raise ApplyError("Нет изменений")
    files, warnings = collect_files(path)
    if not files or files[0]["path"] != path.resolve():
        raise ApplyError("Не удалось прочитать конфигурацию niri")
    if files[0]["nodes"] is None:
        raise ApplyError(warnings[0] if warnings else "Конфигурацию не удалось разобрать. Файл не изменён")
    updated = {}
    if "output" in changes:
        output = changes["output"] or {}
        updated.update(transform_output(files, output.get("name"), output.get("set") or {}))
        files = _reload_planned(files, updated)
        if output.get("primary") is True:
            updated.update(assign_primary(files, output.get("primaryName") or output.get("name")))
    for section in ("mouse", "touchpad"):
        if section in changes:
            updated.update(transform_device(files, section, (changes[section] or {}).get("set") or {}))
            files = _reload_planned(files, updated)
    if "keyboard" in changes:
        updated.update(transform_keyboard(files, (changes["keyboard"] or {}).get("set") or {}))
    return files, updated, warnings


def _reload_planned(files, updated):
    refreshed = []
    for entry in files:
        text = updated.get(entry["path"], entry["text"])
        try:
            nodes = parse_document(text)
        except ParseError as error:
            raise ApplyError("После правки файл не разбирается: %s" % error)
        refreshed.append({
            "path": entry["path"],
            "text": text,
            "nodes": nodes,
            "protected": entry["protected"],
        })
    return refreshed


def niri_validate(path):
    binary = niri_binary()
    if not binary:
        return None
    try:
        completed = subprocess.run(
            [binary, "validate", "-c", str(path)],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return completed.returncode == 0


def _pending_covers(pending, paths):
    if not pending:
        return False
    covered = {item.get("path") for item in pending.get("files") or []}
    return any(str(path) in covered for path in paths)


def _restore_files(originals):
    for path, data in originals.items():
        atomic_write(path, data)


def apply_changes(path, changes, now=None, validator=None, dangerous=None):
    path = Path(path)
    if path.name in PROTECTED_NAMES:
        return fail("Файл %s Nayori не меняет" % path.name)
    if not path.is_file():
        return fail("Файл конфигурации niri не найден")
    if validator is None and niri_binary() is None:
        return fail("Команда niri не найдена. Файл не изменён")
    try:
        _files, updated, warnings = plan_changes(path, changes)
    except ApplyError as error:
        return fail(str(error))
    except OSError:
        return fail("Не удалось прочитать конфигурацию niri")
    if not updated:
        pending = load_pending(path)
        return {
            "ok": True,
            "changed": False,
            "error": "",
            "warnings": warnings,
            "backups": [],
            "pending": _public_pending(pending),
            "rolledBack": False,
            "config": str(path),
        }
    output_change = "output" in (changes or {})
    is_dangerous = output_change if dangerous is None else bool(dangerous)
    pending = load_pending(path)
    originals = {}
    try:
        for file_path in updated:
            originals[file_path] = file_path.read_bytes()
    except OSError:
        return fail("Не удалось прочитать конфигурацию перед записью")
    if pending and _pending_covers(pending, updated) and not is_dangerous:
        return fail("Сначала подтвердите изменение экрана или дождитесь, пока Nayori его вернёт")
    backups = []
    try:
        if not (pending and is_dangerous and _pending_covers(pending, updated)):
            for file_path, original in originals.items():
                backups.append(str(write_backup(file_path, original)))
        for file_path, text in updated.items():
            atomic_write(file_path, text)
    except OSError:
        try:
            _restore_files(originals)
        except OSError:
            return fail(
                "Не удалось записать конфигурацию и вернуть прежний файл",
                backups=backups,
                warnings=warnings,
            )
        return fail("Не удалось записать конфигурацию. Прежний файл на месте", backups=backups, warnings=warnings)
    checker = validator if validator is not None else niri_validate
    valid = checker(path)
    if valid is None:
        try:
            _restore_files(originals)
        except OSError:
            return fail("Команда niri не найдена, и вернуть прежний файл не удалось", backups=backups)
        return fail("Команда niri не найдена. Файл не изменён", backups=backups, rolledBack=True)
    if not valid:
        try:
            _restore_files(originals)
        except OSError:
            return fail(
                "niri не принял конфигурацию, и вернуть прежний файл не удалось. Копия лежит рядом с файлом",
                backups=backups,
                warnings=warnings,
            )
        return fail(
            "niri не принял конфигурацию. Файл возвращён из копии",
            backups=backups,
            rolledBack=True,
            warnings=warnings,
        )
    public_pending = _public_pending(pending)
    if is_dangerous:
        moment = time.time() if now is None else float(now)
        if not (pending and _pending_covers(pending, updated)):
            pending = {
                "id": secrets.token_hex(8),
                "deadlineMs": int((moment + CONFIRM_SECONDS) * 1000),
                "files": [
                    {"path": str(file_path), "backup": backups[index], "sha256": _hash_bytes(originals[file_path])}
                    for index, file_path in enumerate(updated)
                ],
            }
        else:
            pending["deadlineMs"] = int((moment + CONFIRM_SECONDS) * 1000)
        try:
            save_pending(path, pending)
        except OSError:
            try:
                _restore_files(originals)
            except OSError:
                return fail("Не удалось запомнить копию для отката", backups=backups)
            return fail("Не удалось запомнить копию для отката. Файл возвращён", backups=backups, rolledBack=True)
        public_pending = _public_pending(pending)
    return {
        "ok": True,
        "changed": True,
        "error": "",
        "warnings": warnings,
        "backups": backups or [item.get("backup") for item in (pending or {}).get("files") or []],
        "pending": public_pending,
        "rolledBack": False,
        "config": str(path),
    }


def _restore_pending(root, pending):
    for item in pending.get("files") or []:
        source = Path(item.get("backup") or "")
        target = Path(item.get("path") or "")
        if not source.is_file() or not target:
            raise OSError("missing backup")
        data = source.read_bytes()
        if _hash_bytes(data) != item.get("sha256"):
            raise OSError("backup changed")
        atomic_write(target, data)


def confirm_pending(path, pending_id=None):
    path = Path(path)
    pending = load_pending(path)
    if not pending:
        return fail("Нет изменения экрана, которое нужно подтвердить")
    if pending_id and pending.get("id") != pending_id:
        return fail("Это подтверждение уже не подходит. Обновите страницу")
    try:
        clear_pending(path)
    except OSError:
        return fail("Не удалось закрыть подтверждение. Копия файла на месте")
    return {
        "ok": True,
        "changed": False,
        "error": "",
        "warnings": [],
        "backups": [item.get("backup") for item in pending.get("files") or []],
        "pending": None,
        "rolledBack": False,
        "config": str(path),
    }


def rollback_pending(path, pending_id=None):
    path = Path(path)
    pending = load_pending(path)
    if not pending:
        return fail("Нет изменения, которое можно вернуть")
    if pending_id and pending.get("id") != pending_id:
        return fail("Это подтверждение уже не подходит. Обновите страницу")
    try:
        _restore_pending(path, pending)
        clear_pending(path)
    except OSError:
        return fail("Не удалось вернуть прежний файл. Копия лежит рядом с конфигурацией")
    return {
        "ok": True,
        "changed": True,
        "error": "",
        "warnings": [],
        "backups": [item.get("backup") for item in pending.get("files") or []],
        "pending": None,
        "rolledBack": True,
        "config": str(path),
    }


def expire_pending(path, now=None):
    path = Path(path)
    pending = load_pending(path)
    if not pending:
        return {
            "ok": True,
            "changed": False,
            "error": "",
            "warnings": [],
            "backups": [],
            "pending": None,
            "rolledBack": False,
            "config": str(path),
        }
    moment = time.time() if now is None else float(now)
    deadline = float(pending.get("deadlineMs") or 0) / 1000.0
    if moment < deadline:
        return {
            "ok": True,
            "changed": False,
            "error": "",
            "warnings": [],
            "backups": [],
            "pending": _public_pending(pending),
            "rolledBack": False,
            "config": str(path),
        }
    return rollback_pending(path, pending.get("id"))


def live_reload():
    """Reload the running niri config. Tests must not call this."""
    if os.environ.get("NAYORI_NIRI_FORBID_LIVE") == "1":
        return fail("Перечитывание живой сессии отключено")
    binary = niri_binary()
    if not binary:
        return fail("Команда niri не найдена. Файл уже записан, сессия его не перечитала")
    try:
        completed = subprocess.run(
            [binary, "msg", "action", "load-config-file"],
            check=False,
            capture_output=True,
            text=True,
            timeout=3,
        )
    except subprocess.TimeoutExpired:
        return fail("niri не перечитал конфигурацию вовремя")
    except OSError:
        return fail("Не удалось попросить niri перечитать конфигурацию")
    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout or "").strip()
        return fail(message or "niri не перечитал конфигурацию")
    return {"ok": True, "changed": False, "error": "", "warnings": [], "backups": [], "pending": None, "rolledBack": False}


def _refresh_label(millihertz_or_hz):
    if isinstance(millihertz_or_hz, float) and not float(millihertz_or_hz).is_integer():
        hz = float(millihertz_or_hz)
    else:
        number = float(millihertz_or_hz)
        hz = number / 1000.0 if number >= 1000 else number
    if abs(hz - round(hz)) < 0.001:
        return str(int(round(hz)))
    return ("%.3f" % hz).rstrip("0").rstrip(".")


def _mode_key(width, height, refresh):
    return "%dx%d@%s" % (int(width), int(height), _refresh_label(refresh))


def parse_outputs_payload(payload):
    outputs = []
    raw = payload
    if isinstance(payload, dict):
        raw = payload.get("Outputs", payload.get("outputs", payload))
    items = []
    if isinstance(raw, dict):
        items = list(raw.values())
    elif isinstance(raw, list):
        items = raw
    for item in items:
        if not isinstance(item, dict):
            continue
        name = item.get("name") or ""
        modes = []
        for mode in item.get("modes") or []:
            if not isinstance(mode, dict):
                continue
            if "width" not in mode or "height" not in mode or "refresh_rate" not in mode:
                continue
            key = _mode_key(mode["width"], mode["height"], mode["refresh_rate"])
            modes.append({
                "key": key,
                "width": int(mode["width"]),
                "height": int(mode["height"]),
                "refresh": _refresh_label(mode["refresh_rate"]),
                "preferred": bool(mode.get("is_preferred") or mode.get("preferred")),
            })
        current = None
        index = item.get("current_mode")
        if isinstance(index, int) and 0 <= index < len(modes):
            current = modes[index]["key"]
        logical = item.get("logical") if isinstance(item.get("logical"), dict) else {}
        outputs.append({
            "name": name,
            "make": item.get("make") or "",
            "model": item.get("model") or "",
            "modes": modes,
            "currentMode": current,
            "vrrSupported": bool(item.get("vrr_supported")),
            "scale": logical.get("scale"),
            "x": logical.get("x"),
            "y": logical.get("y"),
            "transform": logical.get("transform") or "",
        })
    return outputs


def fetch_outputs():
    """Read connected outputs. Does not change the session."""
    binary = niri_binary()
    if not binary:
        return {"ok": False, "error": "Команда niri не найдена. Список режимов недоступен", "outputs": []}
    if not os.environ.get("NIRI_SOCKET", "").strip():
        return {"ok": False, "error": "Сокет niri не задан. Список режимов недоступен", "outputs": []}
    try:
        completed = subprocess.run(
            [binary, "msg", "-j", "outputs"],
            check=False,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "niri не ответил со списком режимов", "outputs": []}
    except OSError:
        return {"ok": False, "error": "Не удалось спросить у niri список режимов", "outputs": []}
    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout or "").strip()
        return {"ok": False, "error": message or "niri не отдал список режимов", "outputs": []}
    try:
        payload = json.loads(completed.stdout or "")
    except json.JSONDecodeError:
        return {"ok": False, "error": "niri вернул список режимов в неожиданном виде", "outputs": []}
    return {"ok": True, "error": "", "outputs": parse_outputs_payload(payload)}


def handle_request(request):
    if not isinstance(request, dict):
        return fail("Непонятный запрос")
    action = request.get("action")
    config = request.get("config") or str(niri_config_path())
    identity = request.get("id")
    try:
        if action == "read":
            result = read_config(config)
        elif action == "outputs":
            result = fetch_outputs()
        elif action == "apply":
            result = apply_changes(config, request.get("changes") or {})
        elif action == "confirm":
            result = confirm_pending(config, request.get("pendingId"))
        elif action == "rollback":
            result = rollback_pending(config, request.get("pendingId"))
        elif action == "expire":
            result = expire_pending(config, request.get("now"))
        elif action == "live":
            result = live_reload()
        else:
            result = fail("Неизвестное действие")
    except Exception:
        result = fail("Не удалось обработать запрос. Файл не изменён, если запись не началась")
    if identity is not None:
        result["id"] = identity
    result["action"] = action
    return result


def serve():
    for line in sys.stdin:
        text = line.strip()
        if not text:
            continue
        try:
            request = json.loads(text)
        except json.JSONDecodeError:
            request = None
        sys.stdout.write(json.dumps(handle_request(request), ensure_ascii=False) + "\n")
        sys.stdout.flush()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--serve":
        serve()
        return 0
    print("usage: niri_config_apply.py --serve", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
