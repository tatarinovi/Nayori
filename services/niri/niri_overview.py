#!/usr/bin/env python3
"""Point niri's overview backdrop at Nayori's blurred wallpaper layer.

niri 26.04 (8ed0da4) overview accepts backdrop-color, zoom, and workspace-shadow.
It has no image path. A background layer named nayori-overview is placed in the
backdrop with place-within-backdrop. The sharp desktop wallpaper stays on
nayori-canvas and is not this layer.

The fragment nayori-overview.kdl is included from config.kdl after
nayori-accent.kdl when that include exists. noctalia.kdl is never written.
--apply re-reads config.kdl immediately before inserting the include, writes
through a temporary file that is removed before return, then validates. A
failed validation restores the previous text from memory. No backup file is
kept. This does not reload the compositor.
"""

import argparse
import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

FRAGMENT_NAME = "nayori-overview.kdl"
ACCENT_NAME = "nayori-accent.kdl"
NOCTALIA_NAME = "noctalia.kdl"
NAMESPACE = "nayori-overview"

MISSING = "Файл конфигурации niri не найден"
READ_ERROR = "Не удалось прочитать конфигурацию niri"
WRITE_ERROR = "Не удалось записать фон обзора niri"
INVALID = "Конфигурация niri не приняла фон обзора. Прежний текст возвращён"
OUTSIDE = "Фон обзора niri лежит вне каталога конфигурации"

FRAGMENT_TEXT = (
    "// Blurred Nayori wallpaper for the overview backdrop.\n"
    "// niri 26.04 has no overview image path. This background layer is\n"
    "// placed in the backdrop; nayori-canvas stays sharp on the desktop.\n"
    "layer-rule {\n"
    "    match namespace=\"^nayori-overview$\"\n"
    "    place-within-backdrop true\n"
    "}\n"
)


def fail(message):
    return {
        "ok": False,
        "changed": False,
        "namespace": NAMESPACE,
        "included": False,
        "ruleLive": False,
        "error": message,
        "backups": [],
    }


def load_accent():
    path = Path(__file__).with_name("niri_accent.py")
    spec = importlib.util.spec_from_file_location("nayori_niri_accent", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ACCENT = load_accent()


def refuse_noctalia(path):
    if Path(path).name == NOCTALIA_NAME or Path(path).resolve().name == NOCTALIA_NAME:
        raise OSError("noctalia")


def read_config(path):
    refuse_noctalia(path)
    return ACCENT.read_text(path)


def fragment_matches(text):
    return "namespace=\"^" + NAMESPACE + "$\"" in text and "place-within-backdrop true" in text


def parse_includes(text):
    parser = ACCENT.Parser(text)
    parser.rgb = "000000"
    parser.walk([], False)
    return parser.include_spans


def ensure_include(text):
    accent_at = None
    for span in parse_includes(text):
        name = ACCENT.include_name(span["spec"])
        if name == FRAGMENT_NAME:
            return text, False
        if name == ACCENT_NAME:
            accent_at = span["insert_at"]
    line = "include \"" + FRAGMENT_NAME + "\"\n"
    if accent_at is not None:
        piece = text[:accent_at]
        if piece and not piece.endswith("\n"):
            piece += "\n"
        return piece + line + text[accent_at:], True
    suffix = "" if text.endswith("\n") or text == "" else "\n"
    return text + suffix + line, True


def resolved_fragment(config, text):
    for span in parse_includes(text):
        if ACCENT.include_name(span["spec"]) == FRAGMENT_NAME:
            return ACCENT.resolve_include(config, span["spec"])
    return config.parent / FRAGMENT_NAME


def start_unix(stat_text, uptime, now, clk):
    end = stat_text.rfind(")")
    if end < 0:
        raise ValueError("stat")
    fields = stat_text[end + 2 :].split()
    ticks = int(fields[19])
    return now - uptime + (ticks / float(clk))


def process_start(pid):
    with open("/proc/uptime", "r", encoding="ascii") as handle:
        uptime = float(handle.read().split()[0])
    stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")
    return start_unix(stat_text, uptime, time.time(), os.sysconf(os.sysconf_names["SC_CLK_TCK"]))


def niri_pid(socket_path):
    if not socket_path:
        return None
    try:
        target = os.stat(socket_path).st_ino
    except OSError:
        return None
    try:
        entries = os.listdir("/proc")
    except OSError:
        return None
    for entry in entries:
        if not entry.isdigit():
            continue
        pid = int(entry)
        comm = Path(f"/proc/{pid}/comm")
        try:
            if comm.read_text(encoding="utf-8").strip() != "niri":
                continue
        except OSError:
            continue
        fd_dir = Path(f"/proc/{pid}/fd")
        try:
            fds = list(fd_dir.iterdir())
        except OSError:
            continue
        for fd in fds:
            try:
                if fd.stat().st_ino == target:
                    return pid
            except OSError:
                continue
    return None


def compositor_start(socket_path):
    pid = niri_pid(socket_path)
    if pid is None:
        return None
    try:
        return process_start(pid)
    except (OSError, ValueError, IndexError):
        return None


def files_ready(config, fragment):
    if not config.is_file() or not fragment.is_file():
        return False
    try:
        if not fragment_matches(read_config(fragment)):
            return False
        config_text = read_config(config)
    except (OSError, UnicodeError):
        return False
    for span in parse_includes(config_text):
        if ACCENT.include_name(span["spec"]) == FRAGMENT_NAME:
            return True
    return False


def stamp_path():
    base = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return Path(base) / "nayori" / "overview-rule.json"


def stamp_matches(config, fragment):
    path = stamp_path()
    if not path.is_file():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return False
    digest = hashlib.sha256(FRAGMENT_TEXT.encode("utf-8")).hexdigest()
    return (
        data.get("config") == str(config.resolve())
        and data.get("fragment") == str(fragment.resolve())
        and data.get("fragmentSha") == digest
    )


def remember(config, fragment):
    """Record that this include was loaded. A later Nayori start can map without another reload."""
    config = Path(config)
    fragment = Path(fragment)
    if not files_ready(config, fragment):
        return
    path = stamp_path()
    payload = json.dumps({
        "config": str(config.resolve()),
        "fragment": str(fragment.resolve()),
        "fragmentSha": hashlib.sha256(FRAGMENT_TEXT.encode("utf-8")).hexdigest(),
    }) + "\n"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(path, payload)
    except OSError:
        return


def rule_is_live(config, fragment, process_start_at, reload_at):
    config = Path(config)
    fragment = Path(fragment)
    if not files_ready(config, fragment):
        return False
    if stamp_matches(config, fragment):
        return True
    try:
        mtimes = (config.stat().st_mtime, fragment.stat().st_mtime)
    except OSError:
        return False
    # Two seconds of slack so a clock skew cannot treat a just-written file as
    # already loaded by a compositor that started first.
    if process_start_at is not None and all(item + 2 <= process_start_at for item in mtimes):
        return True
    if reload_at is not None and reload_at > 0 and all(item <= reload_at for item in mtimes):
        return True
    return False


def prepare(config):
    config = Path(config)
    if not config.is_file():
        return fail(MISSING)
    if config.name == NOCTALIA_NAME:
        return fail(WRITE_ERROR)
    try:
        text = read_config(config)
        edited, include_changed = ensure_include(text)
        fragment = resolved_fragment(config, edited)
        root = config.parent.resolve()
        if not ACCENT.inside(root, fragment):
            return fail(OUTSIDE)
        refuse_noctalia(fragment)
        current = read_config(fragment) if fragment.is_file() else None
    except (OSError, UnicodeError):
        return fail(READ_ERROR)
    fragment_changed = current != FRAGMENT_TEXT
    return {
        "ok": True,
        "changed": bool(include_changed or fragment_changed),
        "namespace": NAMESPACE,
        "included": True,
        "ruleLive": False,
        "error": "",
        "backups": [],
        "_config": config.resolve(),
        "_fragment": fragment,
        "_include_changed": include_changed,
        "_fragment_changed": fragment_changed,
        "_fragment_existed": current is not None,
    }


def atomic_write(path, text):
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


def public_result(config, fragment, changed, process_start_at, reload_at):
    live = rule_is_live(config, fragment, process_start_at, reload_at)
    return {
        "ok": True,
        "changed": bool(changed),
        "namespace": NAMESPACE,
        "included": True,
        "ruleLive": live,
        "error": "",
        "backups": [],
    }


def commit(config, process_start_at, reload_at, skip_validate):
    # Read again here so an include added by another writer is preserved.
    fresh = prepare(config)
    if not fresh.get("ok"):
        return fresh
    if not fresh.get("changed"):
        return public_result(fresh["_config"], fresh["_fragment"], False, process_start_at, reload_at)
    target = fresh["_config"]
    fragment = fresh["_fragment"]
    written = []
    created = []
    previous = {}
    try:
        refuse_noctalia(target)
        refuse_noctalia(fragment)
        if fresh["_fragment_changed"]:
            if fresh["_fragment_existed"]:
                previous[fragment] = read_config(fragment)
            else:
                created.append(fragment)
            atomic_write(fragment, FRAGMENT_TEXT)
            written.append(fragment)
        if fresh["_include_changed"]:
            latest = read_config(target)
            edited, include_changed = ensure_include(latest)
            if include_changed:
                previous[target] = latest
                atomic_write(target, edited)
                written.append(target)
        if not skip_validate and not validate(target):
            undo(written, created, previous)
            return fail(INVALID)
    except OSError:
        try:
            undo(written, created, previous)
        except OSError:
            pass
        return fail(WRITE_ERROR)
    return public_result(target, fragment, bool(written), process_start_at, reload_at)


def main():
    parser = argparse.ArgumentParser(description="Plan or write the Nayori overview backdrop rule")
    parser.add_argument("--config", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-validate", action="store_true")
    parser.add_argument("--socket", default="")
    parser.add_argument("--reload-at", type=float, default=0)
    args = parser.parse_args()
    try:
        result = prepare(args.config)
    except Exception:
        result = fail(READ_ERROR)
    started = compositor_start(args.socket) if result.get("ok") else None
    reload_at = args.reload_at if args.reload_at and args.reload_at > 0 else None
    if result.get("ok") and args.apply and not args.dry_run:
        try:
            result = commit(args.config, started, reload_at, args.skip_validate)
        except Exception:
            result = fail(WRITE_ERROR)
    elif result.get("ok"):
        result = public_result(Path(args.config), Path(args.config).parent / FRAGMENT_NAME, result["changed"], started, reload_at)
        result["changed"] = bool(prepare(args.config).get("changed"))
    if result.get("ok") and result.get("ruleLive") and args.apply and not args.dry_run:
        try:
            config = Path(args.config)
            remember(config, resolved_fragment(config, read_config(config)))
        except (OSError, UnicodeError):
            pass
    public = {
        key: result[key]
        for key in ("ok", "changed", "namespace", "included", "ruleLive", "error", "backups")
        if key in result
    }
    if "backups" not in public:
        public["backups"] = []
    json.dump(public, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0 if public.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
