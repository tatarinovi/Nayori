#!/usr/bin/env python3
"""Write Nayori's resolved accent into a Nayori-owned niri fragment.

The five accent colors go to nayori-accent.kdl beside config.kdl. That file is
included after noctalia.kdl. This machine's niri 26.04 (8ed0da4) merges layout
and recent-windows in source order: a later include replaces only the color
keys it sets (merge_color_gradient for focus-ring, border, tab-indicator and
insert-hint; merge_clone for recent-windows highlight). noctalia.kdl is never
written and its include line is never changed. --apply re-reads config.kdl
immediately before inserting the nayori include, writes through a temporary
file that is removed before return, then validates. If validation fails, the
previous text is written back from memory. No backup file is kept. It does not
reload the compositor. Without --apply it only prints the plan.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

MAX_BYTES = 1_000_000
MAX_FILES = 64

MISSING = "Файл конфигурации niri не найден"
NO_ACCENT = "В конфигурации niri нет цвета акцента"
BAD_ACCENT = "Не удалось прочитать цвет акцента niri"
READ_ERROR = "Не удалось прочитать конфигурацию niri"
WRITE_ERROR = "Не удалось записать цвет акцента niri"
INVALID = "Конфигурация niri не приняла цвет акцента. Прежний текст возвращён"
OUTSIDE = "Цвет акцента niri лежит вне каталога конфигурации"

FRAGMENT_NAME = "nayori-accent.kdl"
NOCTALIA_NAME = "noctalia.kdl"
ACCENT_NODES = (
    "layout.focus-ring.active-color",
    "layout.border.active-color",
    "layout.tab-indicator.active-color",
    "layout.insert-hint.color",
    "recent-windows.highlight.active-color",
)
HINT_NODE = "layout.insert-hint.color"

COLOR_RE = re.compile(
    r'"(\s*)(#[0-9A-Fa-f]{8}|#[0-9A-Fa-f]{6}|#[0-9A-Fa-f]{4}|#[0-9A-Fa-f]{3})(\s*)"'
)


def fail(message):
    return {"ok": False, "changed": False, "accent": "", "error": message, "fields": [], "backups": []}


def accent_rgb(value):
    # Qt hands opaque colors to QML as #AARRGGBB. Niri file colors are separate.
    text = str(value or "").strip()
    if text.startswith("#"):
        text = text[1:]
    if len(text) == 3:
        text = text[0] * 2 + text[1] * 2 + text[2] * 2
    elif len(text) == 8:
        text = text[2:]
    if len(text) != 6 or any(c not in "0123456789abcdefABCDEF" for c in text):
        return ""
    return text.upper()


def split_niri_color(token):
    body = token[1:]
    if len(body) == 3:
        return (body[0] * 2 + body[1] * 2 + body[2] * 2).upper(), ""
    if len(body) == 4:
        return (body[0] * 2 + body[1] * 2 + body[2] * 2).upper(), (body[3] * 2).upper()
    if len(body) == 6:
        return body.upper(), ""
    if len(body) == 8:
        return body[:6].upper(), body[6:].upper()
    return "", ""


def is_accent(name, stack):
    parent = stack[-1] if stack else ""
    if name == "active-color" and parent in ("focus-ring", "border", "tab-indicator"):
        return "layout" in stack
    if name == "active-color" and parent == "highlight":
        return "recent-windows" in stack
    if name == "color" and parent == "insert-hint":
        return "layout" in stack
    return False


class Parser:
    def __init__(self, text):
        self.s = text
        self.n = len(text)
        self.i = 0
        self.steps = 0
        self.pending_slash = False
        self.replacements = []
        self.fields = []
        self.includes = []
        self.include_spans = []
        self.blocked = False

    def tick(self):
        self.steps += 1
        if self.steps > 1_000_000:
            raise RuntimeError("loop")

    def peek(self):
        return self.s[self.i] if self.i < self.n else ""

    def skip_string(self):
        if self.peek() != '"':
            return
        self.i += 1
        while self.i < self.n:
            self.tick()
            char = self.s[self.i]
            if char == "\\":
                self.i += 2
                continue
            self.i += 1
            if char == '"':
                return

    def read_ident(self):
        if self.i >= self.n:
            return ""
        char = self.s[self.i]
        if not (char.isascii() and (char.isalpha() or char == "_")):
            return ""
        start = self.i
        self.i += 1
        while self.i < self.n:
            self.tick()
            char = self.s[self.i]
            if char.isascii() and (char.isalnum() or char in "_-"):
                self.i += 1
            else:
                break
        return self.s[start:self.i]

    def next_item(self):
        slash = False
        while self.i < self.n:
            self.tick()
            char = self.s[self.i]
            if char in " \t\r\n;":
                self.i += 1
                continue
            if self.s.startswith("//", self.i):
                while self.i < self.n and self.s[self.i] != "\n":
                    self.i += 1
                continue
            if self.s.startswith("/-", self.i):
                slash = True
                self.i += 2
                continue
            self.pending_slash = slash
            if char == "}":
                return "close"
            return "node"
        self.pending_slash = slash
        return "end"

    def read_node_tail(self):
        while self.i < self.n:
            self.tick()
            start = self.i
            char = self.s[self.i]
            if char in " \t\r":
                self.i += 1
                continue
            if char == "\n":
                probe = self.i + 1
                while probe < self.n and self.s[probe] in " \t\r":
                    probe += 1
                if probe < self.n and self.s[probe] == "{":
                    self.i = probe
                    return "block"
                return "line"
            if self.s.startswith("//", self.i):
                while self.i < self.n and self.s[self.i] != "\n":
                    self.i += 1
                continue
            if self.s.startswith("/-", self.i):
                self.i += 2
                self.skip_value()
                continue
            if char == "{":
                return "block"
            if char in "};":
                return "line"
            if char == '"':
                self.skip_string()
                continue
            if char == "=":
                self.i += 1
                continue
            if char.isascii() and (char.isalpha() or char == "_"):
                self.read_ident()
                continue
            if char in "+-" or char.isdigit() or char == ".":
                self.i += 1
                while self.i < self.n and self.s[self.i] not in " \t\r\n{};\"=/":
                    self.i += 1
                continue
            if self.i == start:
                self.i += 1
        return "line"

    def skip_value(self):
        while self.i < self.n and self.s[self.i] in " \t\r":
            self.i += 1
        if self.i >= self.n:
            return
        if self.s[self.i] == '"':
            self.skip_string()
            return
        if self.s[self.i] == "{":
            self.i += 1
            depth = 1
            quote = False
            while self.i < self.n and depth:
                self.tick()
                char = self.s[self.i]
                if quote:
                    if char == "\\":
                        self.i += 2
                        continue
                    if char == '"':
                        quote = False
                    self.i += 1
                    continue
                if char == '"':
                    quote = True
                elif char == "{":
                    depth += 1
                elif char == "}":
                    depth -= 1
                self.i += 1
            return
        self.i += 1
        while self.i < self.n and self.s[self.i] not in " \t\r\n{};":
            self.i += 1

    def take_color(self, name, stack, arg_start, arg_end, ignoring):
        if ignoring or not is_accent(name, stack):
            return
        segment = self.s[arg_start:arg_end]
        match = COLOR_RE.search(segment)
        if not match:
            self.blocked = True
            return
        token = match.group(2)
        rgb, alpha = split_niri_color(token)
        if not rgb:
            self.blocked = True
            return
        new = "#" + self.rgb + alpha
        start = arg_start + match.start(2)
        end = arg_start + match.end(2)
        changed = token.upper() != new.upper()
        node = ".".join(stack + [name])
        self.fields.append({
            "node": node,
            "from": token,
            "to": new,
            "changed": changed,
        })
        if changed:
            self.replacements.append((start, end, new))

    def take_include(self, name_at, arg_start, arg_end, ignoring):
        if ignoring:
            return
        match = re.search(r'"((?:\\.|[^"\\])*)"', self.s[arg_start:arg_end])
        if not match:
            return
        raw = match.group(1)
        out = []
        index = 0
        while index < len(raw):
            if raw[index] == "\\" and index + 1 < len(raw):
                out.append(raw[index + 1])
                index += 2
            else:
                out.append(raw[index])
                index += 1
        spec = "".join(out).strip()
        if spec:
            self.includes.append(spec)
            self.include_spans.append({
                "spec": spec,
                "start": name_at,
                "insert_at": line_after(self.s, arg_end),
            })

    def walk(self, stack, ignoring):
        while self.i < self.n:
            self.tick()
            kind = self.next_item()
            slash = self.pending_slash
            if kind == "end":
                return
            if kind == "close":
                self.i += 1
                if stack:
                    return
                continue
            name_at = self.i
            name = self.read_ident()
            if not name:
                if self.peek() not in " \t\r\n;":
                    self.i += 1
                continue
            arg_start = self.i
            tail = self.read_node_tail()
            arg_end = self.i
            node_ignoring = ignoring or slash
            if name == "include":
                self.take_include(name_at, arg_start, arg_end, node_ignoring)
            else:
                self.take_color(name, stack, arg_start, arg_end, node_ignoring)
            if tail == "block" and self.peek() == "{":
                self.i += 1
                stack.append(name)
                self.walk(stack, node_ignoring)
                if stack:
                    stack.pop()

    def apply(self, rgb):
        self.rgb = rgb
        self.walk([], False)
        if self.blocked:
            return self.s, True
        if not self.replacements:
            return self.s, False
        parts = []
        last = 0
        for start, end, new in self.replacements:
            parts.append(self.s[last:start])
            parts.append(new)
            last = end
        parts.append(self.s[last:])
        return "".join(parts), False


def apply_text(text, rgb):
    parser = Parser(text)
    new_text, blocked = parser.apply(rgb)
    return {
        "text": text if blocked else new_text,
        "blocked": blocked,
        "fields": [] if blocked else parser.fields,
        "includes": parser.includes,
    }


def resolve_include(base_file, spec):
    if spec.startswith("~/"):
        spec = str(Path.home()) + spec[1:]
    path = Path(spec)
    if not path.is_absolute():
        path = base_file.parent / path
    return path


def inside(root, path):
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (OSError, ValueError):
        return False


def read_text(path):
    data = path.read_bytes()
    if len(data) > MAX_BYTES:
        raise OSError("large")
    return data.decode("utf-8")


def line_after(text, end):
    index = end
    while index < len(text) and text[index] != "\n":
        index += 1
    if index < len(text) and text[index] == "\n":
        return index + 1
    return index


def include_name(spec):
    return Path(str(spec).replace("\\", "/")).name


def refuse_noctalia(path):
    if Path(path).name == NOCTALIA_NAME:
        raise OSError("noctalia")


def fragment_path(config):
    return config.parent / FRAGMENT_NAME


def fragment_document(rgb, alpha):
    solid = "#" + rgb
    hint = "#" + rgb + alpha
    return (
        "layout {\n"
        "    focus-ring {\n"
        '        active-color "' + solid + '"\n'
        "    }\n"
        "    border {\n"
        '        active-color "' + solid + '"\n'
        "    }\n"
        "    tab-indicator {\n"
        '        active-color "' + solid + '"\n'
        "    }\n"
        "    insert-hint {\n"
        '        color "' + hint + '"\n'
        "    }\n"
        "}\n"
        "\n"
        "recent-windows {\n"
        "    highlight {\n"
        '        active-color "' + solid + '"\n'
        "    }\n"
        "}\n"
    )


def ensure_nayori_include(text):
    # Later include wins on this niri. Keep the line after noctalia.kdl and
    # do not rewrite that include. A nayori include that already sits later
    # is left untouched.
    parser = Parser(text)
    parser.apply("000000")
    last_noctalia = None
    nayori_after = False
    nayori_any = False
    for span in parser.include_spans:
        name = include_name(span["spec"])
        if name == NOCTALIA_NAME:
            last_noctalia = span["insert_at"]
            nayori_after = False
        elif name == FRAGMENT_NAME:
            nayori_any = True
            if last_noctalia is None or span["start"] >= last_noctalia:
                nayori_after = True
    if last_noctalia is not None:
        if nayori_after:
            return text, False
        line = 'include "' + FRAGMENT_NAME + '"\n'
        return text[:last_noctalia] + line + text[last_noctalia:], True
    if nayori_any:
        return text, False
    suffix = "" if text.endswith("\n") or text == "" else "\n"
    return text + suffix + 'include "' + FRAGMENT_NAME + '"\n', True


def render_fragment(path, rgb, alpha):
    if not path.is_file():
        return fragment_document(rgb, alpha), False, False
    current = read_text(path)
    parsed = apply_text(current, rgb)
    if parsed["blocked"]:
        return current, True, True
    have = {field["node"] for field in parsed["fields"]}
    if set(ACCENT_NODES) <= have:
        return parsed["text"], True, False
    file_alpha = alpha
    for field in parsed["fields"]:
        if field["node"] == HINT_NODE:
            _, file_alpha = split_niri_color(field["from"])
    return fragment_document(rgb, file_alpha), True, False


def prepare(config, rgb):
    config = Path(config)
    if not config.is_file():
        return fail(MISSING)
    if config.name == NOCTALIA_NAME:
        return fail(WRITE_ERROR)
    root = config.parent.resolve()
    fragment = fragment_path(config)
    if not inside(root, fragment):
        return fail(OUTSIDE)
    seen = set()
    found = False
    blocked = False
    sources = {}
    alpha = ""

    def visit(path):
        nonlocal found, blocked, alpha
        if len(seen) > MAX_FILES:
            raise OSError("many")
        try:
            path = path.resolve()
        except OSError as error:
            raise OSError("read") from error
        if path in seen:
            return
        if path.name == FRAGMENT_NAME and not path.is_file():
            return
        seen.add(path)
        if not path.is_file():
            raise OSError("missing-include")
        parsed = apply_text(read_text(path), rgb)
        if parsed["blocked"]:
            blocked = True
        for field in parsed["fields"]:
            found = True
            sources[field["node"]] = field["from"]
            if field["node"] == HINT_NODE:
                _, alpha = split_niri_color(field["from"])
        for spec in parsed["includes"]:
            child = resolve_include(path, spec)
            if child.name == FRAGMENT_NAME and not child.is_file():
                continue
            visit(child)

    try:
        visit(config)
        config_text = read_text(config)
        edited_config, include_changed = ensure_nayori_include(config_text)
        fragment_text, fragment_existed, fragment_blocked = render_fragment(fragment, rgb, alpha)
    except UnicodeError:
        return fail(READ_ERROR)
    except OSError:
        return fail(READ_ERROR)

    if blocked or fragment_blocked:
        return fail(BAD_ACCENT)
    if not found and not fragment_existed:
        return fail(NO_ACCENT)

    hint_alpha = alpha
    probe = apply_text(fragment_text, rgb)
    for field in probe["fields"]:
        if field["node"] == HINT_NODE:
            _, hint_alpha = split_niri_color(field["from"])
    fields = []
    for node in ACCENT_NODES:
        suffix = hint_alpha if node == HINT_NODE else ""
        fields.append({
            "file": FRAGMENT_NAME,
            "node": node,
            "from": sources.get(node, ""),
            "to": "#" + rgb + suffix,
        })
    current_fragment = read_text(fragment) if fragment_existed else None
    fragment_changed = current_fragment != fragment_text
    return {
        "ok": True,
        "changed": bool(fragment_changed or include_changed),
        "accent": "#" + rgb,
        "error": "",
        "fields": fields,
        "backups": [],
        "_root": root,
        "_config": config.resolve(),
        "_rgb": rgb,
        "_fragment": fragment,
        "_fragment_text": fragment_text,
        "_fragment_existed": fragment_existed,
        "_fragment_changed": fragment_changed,
        "_config_text": edited_config,
        "_include_changed": include_changed,
    }


def plan(config, rgb):
    return prepare(config, rgb)


def atomic_write(path, text):
    # Same-directory temp so replace is atomic. The temp name is gone before return.
    refuse_noctalia(path)
    data = text.encode("utf-8")
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix="." + path.name + ".nayori-")
    replaced = False
    try:
        os.write(fd, data)
        os.fsync(fd)
        os.close(fd)
        fd = -1
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


def validate(config):
    completed = subprocess.run(
        ["niri", "validate", "-c", str(config)],
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0


def undo(written, created, previous):
    for path in reversed(written):
        refuse_noctalia(path)
        if path in created:
            if path.exists():
                path.unlink()
        elif path in previous:
            atomic_write(path, previous[path])


def commit(plan_result, skip_validate):
    # Read again here so an include added by another writer is preserved.
    fresh = prepare(plan_result["_config"], plan_result["_rgb"])
    if not fresh.get("ok"):
        return fresh
    if not fresh.get("changed"):
        public = {key: fresh[key] for key in ("ok", "changed", "accent", "error", "fields")}
        public["backups"] = []
        return public
    config = fresh["_config"]
    fragment = fresh["_fragment"]
    written = []
    created = []
    previous = {}
    try:
        refuse_noctalia(config)
        refuse_noctalia(fragment)
        if fresh["_fragment_changed"]:
            if fresh["_fragment_text"] == "" and fresh["_fragment_existed"]:
                raise OSError("empty")
            if fresh["_fragment_existed"]:
                previous[fragment] = read_text(fragment)
            else:
                created.append(fragment)
            atomic_write(fragment, fresh["_fragment_text"])
            written.append(fragment)
        if fresh["_include_changed"]:
            # Immediate re-read: keep every other line, including a launcher bind.
            latest = read_text(config)
            edited, include_changed = ensure_nayori_include(latest)
            if include_changed:
                previous[config] = latest
                atomic_write(config, edited)
                written.append(config)
        if not skip_validate and not validate(config):
            undo(written, created, previous)
            result = fail(INVALID)
            result["backups"] = []
            return result
    except OSError:
        try:
            undo(written, created, previous)
        except OSError:
            pass
        result = fail(WRITE_ERROR)
        result["backups"] = []
        return result
    public = {key: fresh[key] for key in ("ok", "changed", "accent", "error", "fields")}
    public["changed"] = bool(written)
    public["backups"] = []
    return public


def main():
    parser = argparse.ArgumentParser(description="Plan or write Nayori accent colors into niri KDL")
    parser.add_argument("--config", required=True)
    parser.add_argument("--accent", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-validate", action="store_true")
    parser.add_argument("--integration", choices=("on", "off"), default="on")
    args = parser.parse_args()
    if args.integration == "off":
        # The settings toggle is off: do not read or write any niri file.
        json.dump({
            "ok": True,
            "changed": False,
            "accent": "",
            "error": "",
            "fields": [],
            "backups": [],
            "skipped": True,
        }, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 0
    rgb = accent_rgb(args.accent)
    if not rgb:
        json.dump(fail(BAD_ACCENT), sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return 1
    try:
        result = plan(args.config, rgb)
    except Exception:
        result = fail(READ_ERROR)
    if result.get("ok") and args.apply and not args.dry_run and result.get("changed"):
        try:
            result = commit(result, args.skip_validate)
        except Exception:
            result = fail(WRITE_ERROR)
    public = {key: result[key] for key in ("ok", "changed", "accent", "error", "fields", "backups") if key in result}
    if "backups" not in public:
        public["backups"] = []
    json.dump(public, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0 if public.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
