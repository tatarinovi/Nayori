"""Поиск лаунчера: файлы, разбор команды и сборка строк.

Обход идёт в этом процессе, не в потоке интерфейса. fd, locate и Baloo
не вызываются. Команда превращается в список аргументов и отсюда не запускается.
"""

from __future__ import annotations

import os
import time
from pathlib import Path

MIN_QUERY_CHARS = 2
FILE_LIMIT = 6
CANDIDATE_CAP = 48
MAX_DEPTH = 7
MAX_VISITS = 8000
TIME_BUDGET_SEC = 0.35
MAX_ARGV = 32
MAX_ARG_CHARS = 4096
MAX_COMMAND_CHARS = 2000

USER_DIR_KEYS = (
    "XDG_DESKTOP_DIR",
    "XDG_DOCUMENTS_DIR",
    "XDG_DOWNLOAD_DIR",
    "XDG_MUSIC_DIR",
    "XDG_PICTURES_DIR",
    "XDG_VIDEOS_DIR",
    "XDG_TEMPLATES_DIR",
    "XDG_PUBLICSHARE_DIR",
)

SHELLS = {"sh", "bash", "zsh", "dash", "fish", "ksh", "csh", "tcsh"}
META = set("|&;<>`$()")
OPTIONAL_TOOLS = ("fd", "fdfind", "locate", "balooctl", "baloosearch")

TYPE_LABEL = {
    "application": "приложение",
    "file": "файл",
    "folder": "папка",
    "command": "команда",
    "web": "интернет",
}
SECTION = {
    "application": "Приложения",
    "files": "Файлы",
    "command": "Команда",
}
COMMAND_ERROR = {
    "shell": "Конвейер и перенаправление не выполняются",
    "quote": "В команде не закрыта кавычка",
    "long": "Команда слишком длинная",
}


def normalize(text) -> str:
    return " ".join(str("" if text is None else text).strip().split())


def trimmed(text) -> str:
    return str("" if text is None else text).strip()


def is_command_query(text) -> bool:
    return trimmed(text).startswith(">")


def command_body(text) -> str:
    raw = trimmed(text)
    if not raw.startswith(">"):
        return ""
    return raw[1:].strip()


def file_needle(text) -> str:
    if is_command_query(text):
        return ""
    return normalize(text)


def web_terms(text) -> str:
    raw = normalize(text)
    if not raw or is_command_query(raw):
        return ""
    folded = raw.casefold()
    if folded == "web":
        return ""
    if folded.startswith("web ") or folded.startswith("web\t"):
        return raw[4:].strip()
    return raw


def search_url(terms) -> str:
    text = str("" if terms is None else terms).strip()
    if not text:
        return ""
    from urllib.parse import quote

    return "https://www.google.com/search?q=" + quote(text, safe="")


def _program_name(program: str) -> str:
    return program.replace("\\", "/").rsplit("/", 1)[-1]


def _is_shell(program: str) -> bool:
    return _program_name(program) in SHELLS


def _fail(code: str) -> dict:
    return {"ok": False, "code": code, "argv": [], "error": COMMAND_ERROR.get(code, "")}


def command_argv(body: str, home: str) -> dict:
    """Список аргументов без оболочки. Набранный текст в оболочку не заворачивается."""
    text = str("" if body is None else body)
    if len(text) > MAX_COMMAND_CHARS:
        return _fail("long")
    if "\x00" in text:
        return _fail("shell")
    tokens: list[tuple[str, bool]] = []
    buf: list[str] = []
    quote = ""
    quoted = False
    index = 0
    length = len(text)
    while index < length:
        char = text[index]
        if quote:
            if char == quote:
                quote = ""
                quoted = True
            elif char == "\\" and quote == '"' and index + 1 < length and text[index + 1] in "\"\\":
                buf.append(text[index + 1])
                index += 1
            elif char in "\n\r\x00" or ord(char) < 32:
                return _fail("shell")
            else:
                buf.append(char)
        elif char in " \t":
            if buf or quoted:
                tokens.append(("".join(buf), quoted))
                buf = []
                quoted = False
        elif char in "'\"":
            quote = char
        elif char == "\\":
            if index + 1 >= length:
                return _fail("shell")
            buf.append(text[index + 1])
            index += 1
        elif char in META or ord(char) < 32:
            return _fail("shell")
        else:
            buf.append(char)
        index += 1
    if quote:
        return _fail("quote")
    if buf or quoted:
        tokens.append(("".join(buf), quoted))
    if not tokens:
        return _fail("empty")
    if len(tokens) > MAX_ARGV:
        return _fail("long")
    argv: list[str] = []
    home_text = str(home or "")
    for token, was_quoted in tokens:
        if len(token) > MAX_ARG_CHARS or "\x00" in token:
            return _fail("long" if len(token) > MAX_ARG_CHARS else "shell")
        if not was_quoted and home_text and (token == "~" or token.startswith("~/")):
            token = home_text + token[1:]
        argv.append(token)
    if not argv[0]:
        return _fail("empty")
    if _is_shell(argv[0]) and any(part in {"-c", "-lc"} for part in argv[1:]):
        return _fail("shell")
    return {"ok": True, "code": "", "argv": argv, "error": ""}


def safe_path(path: str) -> bool:
    text = str(path or "")
    if not text.startswith("/") or text == "/" or text.startswith("//"):
        return False
    if any(char in text for char in ("\x00", "\n", "\r")):
        return False
    return True


def open_argv(path: str) -> list[str] | None:
    text = str(path or "")
    if not safe_path(text):
        return None
    return ["xdg-open", text]


def _rank(text: str, needle: str) -> int | None:
    folded = text.casefold()
    query = needle.casefold()
    if not query or not folded:
        return None
    if folded == query:
        return 0
    if folded.startswith(query):
        return 1
    if query in folded:
        return 2
    return None


def match_rank(name: str, relative: str, needle: str) -> int | None:
    direct = _rank(name, needle)
    if direct is not None:
        return direct
    if "/" not in needle and "\\" not in needle:
        return None
    relative_rank = _rank(relative.replace("\\", "/"), needle.replace("\\", "/"))
    if relative_rank is None:
        return None
    return 3 + relative_rank


def skip_dir(name: str) -> bool:
    if not name or name in {".", ".."} or name.startswith("."):
        return True
    folded = name.casefold()
    return folded in {"node_modules", "cache", "caches", "__pycache__"}


def display_directory(parent: Path, home: Path) -> str:
    try:
        relative = parent.resolve().relative_to(home.resolve())
    except (OSError, ValueError):
        return str(parent)
    text = relative.as_posix()
    if text == ".":
        return "~"
    return "~/" + text


def _filter_roots(paths: list[Path]) -> list[Path]:
    result: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        try:
            if not path.is_absolute():
                continue
            resolved = path.resolve()
        except OSError:
            continue
        if resolved.as_posix() == "/" or not resolved.is_dir():
            continue
        key = resolved.as_posix()
        if key in seen:
            continue
        seen.add(key)
        result.append(path)
    return result


def expand_user_dir(value: str, home: Path) -> Path | None:
    text = str(value or "").strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        text = text[1:-1]
    text = text.replace("${HOME}", str(home)).replace("$HOME", str(home))
    if not text or "$" in text:
        return None
    path = Path(text)
    if not path.is_absolute():
        path = home / path
    return path


def parse_user_dirs(text: str, home: Path) -> list[tuple[str, Path]]:
    found: list[tuple[str, Path]] = []
    for line in str(text or "").splitlines():
        raw = line.strip()
        if not raw or raw.startswith("#") or "=" not in raw:
            continue
        key, value = raw.split("=", 1)
        key = key.strip()
        if key not in USER_DIR_KEYS:
            continue
        path = expand_user_dir(value.strip(), home)
        if path is not None:
            found.append((key, path))
    return found


def collect_roots(home: Path, environ: dict | None = None) -> list[Path]:
    env = os.environ if environ is None else environ
    config = str(env.get("XDG_CONFIG_HOME") or (home / ".config"))
    try:
        listing = (Path(config) / "user-dirs.dirs").read_text(encoding="utf-8")
    except OSError:
        listing = ""
    by_key = {key: path for key, path in parse_user_dirs(listing, home)}
    for key in USER_DIR_KEYS:
        if env.get(key):
            path = expand_user_dir(str(env.get(key)), home)
            if path is not None:
                by_key[key] = path
    ordered = [by_key[key] for key in USER_DIR_KEYS if key in by_key]
    ordered.append(home)
    return _filter_roots(ordered)


def search_files(query, roots, home: Path, clock=None, limit: int = FILE_LIMIT,
                 max_depth: int = MAX_DEPTH, max_visits: int = MAX_VISITS,
                 budget: float = TIME_BUDGET_SEC) -> dict:
    needle = file_needle(query)
    if len(needle) < MIN_QUERY_CHARS:
        return {"files": [], "truncated": False, "reason": "short"}
    now = clock or time.monotonic
    started = now()
    visits = 0
    truncated = False
    candidates: list[dict] = []
    seen_dirs: set[str] = set()

    def expired() -> bool:
        return now() - started >= budget

    def consider(entry_name: str, path: Path, kind: str, depth: int) -> None:
        nonlocal truncated
        try:
            relative = path.resolve().relative_to(home.resolve()).as_posix()
        except (OSError, ValueError):
            relative = path.as_posix().lstrip("/")
        rank = match_rank(entry_name, relative, needle)
        if rank is None:
            return
        absolute = path.as_posix()
        if not safe_path(absolute):
            return
        if len(candidates) >= CANDIDATE_CAP:
            truncated = True
            return
        candidates.append({
            "kind": kind,
            "name": entry_name,
            "path": absolute,
            "directory": display_directory(path.parent, home),
            "rank": rank,
            "depth": depth,
        })

    def walk(directory: Path, depth: int) -> None:
        nonlocal visits, truncated
        if expired() or visits >= max_visits or len(candidates) >= CANDIDATE_CAP:
            truncated = True
            return
        try:
            resolved = directory.resolve()
        except OSError:
            return
        if resolved.as_posix() == "/":
            return
        marker = resolved.as_posix()
        if marker in seen_dirs:
            return
        seen_dirs.add(marker)
        try:
            iterator = os.scandir(directory)
        except OSError:
            return
        entries = []
        with iterator:
            try:
                for entry in iterator:
                    entries.append(entry)
                    visits += 1
                    if visits >= max_visits or expired():
                        truncated = True
                        break
            except OSError:
                return
        entries.sort(key=lambda item: item.name.casefold())
        children: list[str] = []
        for entry in entries:
            if expired() or visits >= max_visits or len(candidates) >= CANDIDATE_CAP:
                truncated = True
                break
            name = entry.name
            if name in {".", ".."}:
                continue
            try:
                symlink = entry.is_symlink()
                directory_entry = entry.is_dir(follow_symlinks=False)
                linked_directory = symlink and entry.is_dir(follow_symlinks=True)
            except OSError:
                continue
            if directory_entry and skip_dir(name):
                continue
            kind = "folder" if directory_entry or linked_directory else "file"
            consider(name, Path(entry.path), kind, depth + 1)
            if directory_entry and not symlink and depth + 1 < max_depth:
                children.append(entry.path)
        for child in children:
            if expired() or visits >= max_visits or len(candidates) >= CANDIDATE_CAP:
                truncated = True
                break
            walk(Path(child), depth + 1)

    for root in roots:
        if expired() or visits >= max_visits or len(candidates) >= CANDIDATE_CAP:
            truncated = True
            break
        try:
            if not root.is_dir():
                continue
        except OSError:
            continue
        walk(root, 0)

    candidates.sort(key=lambda item: (
        item["rank"], 0 if item["kind"] == "folder" else 1, item["depth"], item["name"].casefold(), item["path"]
    ))
    files = [{
        "kind": item["kind"],
        "name": item["name"],
        "path": item["path"],
        "directory": item["directory"],
    } for item in candidates[:limit]]
    if len(candidates) > limit:
        truncated = True
    return {"files": files, "truncated": truncated, "reason": "ok"}


def optional_tools(which=None) -> dict:
    import shutil

    finder = which or shutil.which
    report = {}
    for name in OPTIONAL_TOOLS:
        try:
            found = finder(name)
        except OSError:
            found = None
        report[name] = "installed" if found else "missing"
    return {"tools": report, "used": False}


def handle_request(payload, environ=None, clock=None) -> dict:
    env = os.environ if environ is None else environ
    generation = 0
    if isinstance(payload, dict):
        try:
            generation = int(payload.get("generation") or 0)
        except (TypeError, ValueError):
            generation = 0
        if isinstance(generation, bool):
            generation = 0
    else:
        payload = {}
    query = payload.get("query") if isinstance(payload, dict) else ""
    if not isinstance(query, str):
        query = "" if query is None else str(query)
    home_text = str(env.get("HOME") or "")
    home = Path(home_text) if home_text else Path.home()
    base = {
        "generation": generation,
        "files": [],
        "truncated": False,
        "error": "",
        "reason": "ok",
        "command": None,
        "optionalToolsUsed": False,
    }
    try:
        if is_command_query(query):
            base["reason"] = "command"
            base["command"] = command_argv(command_body(query), str(home))
            return base
        if isinstance(payload, dict) and payload.get("allowRoots") is True and isinstance(payload.get("roots"), list):
            roots = _filter_roots([Path(item) for item in payload["roots"] if isinstance(item, str)])
        else:
            roots = collect_roots(home, env)
        found = search_files(query, roots, home, clock=clock)
        base["files"] = found["files"]
        base["truncated"] = found["truncated"]
        base["reason"] = found["reason"]
        return base
    except Exception:
        base["error"] = "failed"
        base["reason"] = "error"
        base["files"] = []
        base["command"] = None
        return base


def result_is_current(current, payload) -> bool:
    if isinstance(current, bool) or not isinstance(current, int) or current <= 0:
        return False
    if not isinstance(payload, dict):
        return False
    generation = payload.get("generation")
    if isinstance(generation, bool) or not isinstance(generation, int):
        return False
    return generation == current


def _copy(row: dict) -> dict:
    return dict(row)


def build_rows(spec: dict) -> list[dict]:
    command = command_body(spec.get("query") or "")
    rows: list[dict] = []
    if not command:
        for app in spec.get("apps") or []:
            if not isinstance(app, dict):
                continue
            name = str(app.get("name") or "").strip()
            ident = str(app.get("id") or "").strip()
            if not name or not ident:
                continue
            generic = str(app.get("genericName") or "").strip()
            if generic.casefold() == name.casefold():
                generic = ""
            rows.append({
                "kind": "application",
                "key": "application:" + ident,
                "id": ident,
                "title": name,
                "subtitle": generic,
                "typeLabel": TYPE_LABEL["application"],
                "glyph": "",
                "iconSource": str(app.get("iconSource") or ""),
                "path": "",
                "argv": [],
                "ok": False,
                "pending": False,
                "url": "",
                "distinct": False,
            })
        for item in spec.get("files") or []:
            if not isinstance(item, dict):
                continue
            kind = item.get("kind")
            if kind not in ("file", "folder"):
                continue
            path = str(item.get("path") or "")
            name = str(item.get("name") or "").strip()
            if not name or not safe_path(path):
                continue
            rows.append({
                "kind": kind,
                "key": kind + ":" + path,
                "id": path,
                "title": name,
                "subtitle": str(item.get("directory") or ""),
                "typeLabel": TYPE_LABEL[kind],
                "glyph": "folder" if kind == "folder" else "file",
                "iconSource": "",
                "path": path,
                "argv": [],
                "ok": False,
                "pending": False,
                "url": "",
                "distinct": False,
            })
    if command:
        argv = [str(part) for part in (spec.get("commandArgv") or []) if isinstance(part, str)]
        code = str(spec.get("commandCode") or "")
        failed = spec.get("commandStatus") == "error"
        ok = bool(spec.get("commandOk")) and len(argv) > 0 and not code and not failed
        pending = bool(spec.get("commandPending")) and not code and not failed
        if code in COMMAND_ERROR:
            subtitle = COMMAND_ERROR[code]
        elif failed:
            subtitle = "Не удалось разобрать команду. Измените запрос"
        elif pending or not ok:
            subtitle = "Проверяем аргументы"
        else:
            subtitle = "Без оболочки"
        rows.append({
            "kind": "command",
            "key": "command:" + command,
            "id": "",
            "title": command,
            "subtitle": subtitle,
            "typeLabel": TYPE_LABEL["command"],
            "glyph": "command",
            "iconSource": "",
            "path": "",
            "argv": argv if ok else [],
            "ok": ok,
            "pending": pending,
            "url": "",
            "distinct": True,
        })
    terms = "" if command else str(spec.get("webTerms") or "")
    url = "" if command else str(spec.get("webUrl") or "")
    if terms and url:
        rows.append({
            "kind": "web",
            "key": "web:" + terms,
            "id": "",
            "title": "Поиск в\u00a0интернете",
            "subtitle": "Искать в\u00a0Google",
            "typeLabel": TYPE_LABEL["web"],
            "glyph": "search",
            "iconSource": "",
            "path": "",
            "argv": [],
            "ok": False,
            "pending": False,
            "url": url,
            "distinct": False,
        })
    seen: set[str] = set()
    for row in rows:
        group = "files" if row["kind"] in ("file", "folder") else row["kind"]
        if group in SECTION and group not in seen:
            seen.add(group)
            row["section"] = SECTION[group]
        else:
            row["section"] = ""
    return [_copy(row) for row in rows]


def reconcile(rows, index, key, pinned) -> dict:
    if not rows:
        return {"index": 0, "key": "", "pinned": False}
    if pinned and key:
        for position, row in enumerate(rows):
            if row.get("key") == key:
                return {"index": position, "key": key, "pinned": True}
        clamped = max(0, min(int(index or 0), len(rows) - 1))
        return {"index": clamped, "key": rows[clamped].get("key") or "", "pinned": True}
    return {"index": 0, "key": rows[0].get("key") or "", "pinned": False}


def move(rows, index, delta) -> dict:
    if not rows:
        return {"index": 0, "key": "", "pinned": False}
    nxt = int(index or 0) + int(delta or 0)
    nxt = max(0, min(nxt, len(rows) - 1))
    return {"index": nxt, "key": rows[nxt].get("key") or "", "pinned": True}


def pin(rows, index) -> dict:
    if not rows or index is None or int(index) < 0 or int(index) >= len(rows):
        return {"index": 0, "key": "", "pinned": False}
    position = int(index)
    return {"index": position, "key": rows[position].get("key") or "", "pinned": True}


def activation_plan(row) -> dict:
    if not isinstance(row, dict):
        return {"action": "none"}
    kind = row.get("kind")
    if kind == "application":
        ident = str(row.get("id") or "").strip()
        if not ident:
            return {"action": "none"}
        return {"action": "desktop", "id": ident}
    if kind in ("file", "folder"):
        argv = open_argv(str(row.get("path") or ""))
        if not argv:
            return {"action": "none"}
        return {"action": "argv", "argv": argv}
    if kind == "command":
        if row.get("pending"):
            return {"action": "wait"}
        if not row.get("ok"):
            return {"action": "none"}
        argv = row.get("argv")
        if not isinstance(argv, list) or not argv:
            return {"action": "none"}
        cleaned: list[str] = []
        for part in argv:
            if not isinstance(part, str) or "\x00" in part:
                return {"action": "none"}
            cleaned.append(part)
        if not cleaned or cleaned[0] == "":
            return {"action": "none"}
        if len(cleaned) >= 2 and _is_shell(cleaned[0]) and cleaned[1] in {"-c", "-lc"}:
            return {"action": "none"}
        return {"action": "argv", "argv": cleaned}
    if kind == "web":
        url = str(row.get("url") or "")
        if not url.startswith("https://www.google.com/search?q="):
            return {"action": "none"}
        return {"action": "url", "url": url, "fallback": ["xdg-open", url]}
    return {"action": "none"}
