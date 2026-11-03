"""Quick Capture storage regression tests; all paths are disposable."""
from concurrent.futures import ThreadPoolExecutor
import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
import uuid
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("quick_capture", ROOT / "services/quickcapture/quick_capture.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def record(vault, **extra):
    return dict(id=uuid.uuid4().hex, text="Привет 狐 🦊\nвторая строка\n\nещё", context="Work",
                vault=str(vault), directory="Inbox/Work", **extra)


def fails(action):
    try:
        action()
    except (OSError, ValueError):
        return
    raise AssertionError("expected failure")


def parallel(args):
    state, vault = args
    module.Capture(state).save(record(vault), dt.datetime(2026, 11, 3, 13, 42))


with tempfile.TemporaryDirectory(prefix="nayori-quick-capture-") as tmp:
    base = Path(tmp)
    vault = base / "Vault #? с пробелами"
    vault.mkdir()
    untouched = vault / "Templates/Контекст.md"
    untouched.parent.mkdir()
    untouched.write_text("Не применять", encoding="utf-8")
    state = base / "state"
    capture = module.Capture(state)
    first = record(vault)
    capture.draft(first)
    assert module.Capture(state).load()["text"] == first["text"]
    now = dt.datetime(2026, 11, 3, 13, 42)
    result = capture.save(first, now)
    assert result["uri"].startswith("obsidian://open?path=")
    log = vault / "Inbox/Work/2026-11.md"
    original = log.read_text()
    assert original.startswith("## 2026-11-03\n\n- **13:42** Привет 狐 🦊\n  вторая строка\n  \n  ещё")
    assert capture.load()["text"] == ""
    capture.save(first, dt.datetime(2026, 12, 1))  # lost acknowledgement, across month boundary
    assert log.read_text() == original
    assert not (vault / "Inbox/Work/2026-12.md").exists()
    capture.save(record(vault), now)
    assert log.read_text().count("## 2026-11-03") == 1
    assert log.read_text().startswith(original)
    capture.save(record(vault), dt.datetime(2026, 11, 4))
    capture.save(record(vault), now)  # local clock correction: reuse the date group
    assert log.read_text().count("## 2026-11-03") == 1
    capture.save(record(vault), dt.datetime(2026, 12, 1))
    assert (vault / "Inbox/Work/2026-12.md").exists()
    personal = record(vault)
    personal.update(context="Personal", directory="Inbox/Personal")
    capture.save(personal, now)
    assert (vault / "Inbox/Personal/2026-11.md").exists()
    for path in ("../outside", "/tmp/outside", "Inbox/../../outside", "Inbox//Work", "Inbox/./Work", "Inbox\\Work"):
        data = record(vault)
        data["directory"] = path
        fails(lambda: capture.save(data, now))
        assert capture.load()["text"] == data["text"]
    outside = base / "outside"
    outside.mkdir()
    (vault / "escape").symlink_to(outside, target_is_directory=True)
    data = record(vault)
    data["directory"] = "escape"
    fails(lambda: capture.save(data, now))
    assert not list(outside.iterdir())
    (vault / "Inbox/Work/2027-01.md").symlink_to(untouched)
    fails(lambda: capture.save(record(vault), dt.datetime(2027, 1, 1)))
    fails(lambda: capture.save(record(base / "missing"), now))
    data = record(vault)
    data["vault"] = ""
    fails(lambda: capture.save(data, now))
    data = record(vault)
    with patch.object(module, "atomic_at", side_effect=PermissionError("read only")):
        fails(lambda: capture.save(data, now))
    # Real journal write failure after durable draft; never clear or duplicate.
    real_atomic = module.atomic_at

    def fail_journal(directory, name, content):
        if name.endswith(".md"):
            raise PermissionError("read only")
        return real_atomic(directory, name, content)

    with patch.object(module, "atomic_at", side_effect=fail_journal):
        fails(lambda: capture.save(data, now))
    assert module.Capture(state).load()["id"] == data["id"]
    capture.save(data, now)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(parallel, [(state, vault)] * 16))
    capture.save(first, dt.datetime(2028, 1, 1))  # later operations do not erase retry metadata
    contents = log.read_text()
    assert contents.count("<!-- nayori:") == 21
    assert contents.count("## 2026-11-03") == 1
    assert untouched.read_text() == "Не применять"
    assert (state / "draft.json").stat().st_mode & 0o777 == 0o600
    assert not list(vault.rglob(".nayori-*"))
    assert json.loads((state / "draft.json").read_text())["text"] == ""
    uncertain = record(vault)
    committed = [False]

    def fail_ack(directory, name, content):
        if name == "draft.json" and committed[0]:
            raise OSError("lost acknowledgement")
        result = real_atomic(directory, name, content)
        if name.endswith(".md"):
            committed[0] = True
        return result

    with patch.object(module, "atomic_at", side_effect=fail_ack):
        fails(lambda: capture.save(uncertain, dt.datetime(2028, 5, 31, 23, 59)))
    assert capture.load()["id"] == uncertain["id"]
    capture.save(uncertain, dt.datetime(2028, 6, 1))
    assert (vault / "Inbox/Work/2028-05.md").read_text().count("<!-- nayori:") == 1
    assert not (vault / "Inbox/Work/2028-06.md").exists()
    for bad in ("{broken", "[]", '{"id":"bad"}'):
        (state / "draft.json").write_text(bad)
        fails(capture.load)
        assert (state / "draft.json").read_text() == bad

print("QUICK_CAPTURE_STORE_PASS")
