"""Local JSON-lines worker. No shell, network, Obsidian API or template access."""
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import stat
import uuid
from urllib.parse import quote


def atomic_at(directory, name, data):
    temporary = ".nayori-" + uuid.uuid4().hex
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600, dir_fd=directory)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, name, src_dir_fd=directory, dst_dir_fd=directory)
        os.fsync(directory)
    finally:
        try:
            os.unlink(temporary, dir_fd=directory)
        except FileNotFoundError:
            pass


def validate_draft(data):
    if not isinstance(data, dict):
        raise ValueError("Некорректный файл черновика")
    if not isinstance(data.get("text"), str) or len(data["text"]) > 64000 or "\0" in data["text"]:
        raise ValueError("Текст должен содержать не больше 64 000 символов")
    if data.get("context") not in ("Work", "Personal"):
        raise ValueError("Выберите Work или Personal")
    if not isinstance(data.get("id"), str) or not re.fullmatch(r"[a-f0-9]{32}", data["id"]):
        raise ValueError("Некорректный идентификатор записи")
    return {key: data[key] for key in ("id", "text", "context")}


class Capture:
    def __init__(self, state):
        self.state = Path(state)
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.draft_path = self.state / "draft.json"

    def load(self):
        if not self.draft_path.exists():
            return dict(id=uuid.uuid4().hex, text="", context="")
        return validate_draft(json.loads(self.draft_path.read_text(encoding="utf-8")))

    def draft(self, data):
        data = validate_draft(data)
        fd = os.open(self.state, os.O_RDONLY | os.O_DIRECTORY)
        try:
            atomic_at(fd, "draft.json", (json.dumps(data, ensure_ascii=False) + "\n").encode())
        finally:
            os.close(fd)
        return data

    def save(self, data, now=None):
        draft = self.draft(data)  # durable retry identity before touching the vault
        if not draft["text"].strip():
            raise ValueError("Введите текст заметки")
        pending_path = self.state / ("pending-" + draft["id"] + ".json")
        pending = json.loads(pending_path.read_text()) if pending_path.exists() else {}
        if not isinstance(pending, dict):
            raise ValueError("Повреждены метаданные операции; черновик сохранён")
        if pending.get("id") == draft["id"]:
            if not all(isinstance(pending.get(key), str) for key in ("vault", "directory", "time")):
                raise ValueError("Повреждены метаданные операции; черновик сохранён")
            data = dict(data, vault=pending["vault"], directory=pending["directory"])
            now = datetime.datetime.fromisoformat(pending["time"])
        vault_text = data.get("vault", "")
        if not isinstance(vault_text, str) or not vault_text.strip():
            raise ValueError("Укажите Vault: Приложения → Obsidian Inbox")
        vault = Path(vault_text).expanduser()
        if not vault.is_absolute():
            raise ValueError("Укажите абсолютный путь к Vault")
        vault = vault.resolve(strict=True)
        relative = data.get("directory", "")
        if (not isinstance(relative, str) or not relative or relative.startswith("/")
                or any(p in ("", ".", "..") for p in relative.split("/"))
                or any(ord(c) < 32 for c in relative) or "\\" in relative):
            raise ValueError("Папка журнала должна находиться внутри Vault")
        # One lock per vault, also across workers and atomic replacements.
        digest = hashlib.sha256(str(vault).encode()).hexdigest()
        with (self.state / (digest + ".lock")).open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            directory = os.open(vault, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
            try:
                for part in relative.split("/"):
                    try:
                        os.mkdir(part, mode=0o700, dir_fd=directory)
                        os.fsync(directory)
                    except FileExistsError:
                        pass
                    child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
                    os.close(directory)
                    directory = child
                now = now or datetime.datetime.now().astimezone()
                name = now.strftime("%Y-%m.md")
                try:
                    fd = os.open(name, os.O_RDWR | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
                except FileNotFoundError:
                    original = ""
                else:
                    with os.fdopen(fd, "r", encoding="utf-8", newline="") as stream:
                        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
                            raise ValueError("Журнал должен быть обычным файлом")
                        original = stream.read()
                marker = "<!-- nayori:" + draft["id"] + " -->"
                if marker not in original:
                    heading = now.strftime("## %Y-%m-%d")
                    lines = draft["text"].strip().replace("\r\n", "\n").replace("\r", "\n").split("\n")
                    entry = "- **" + now.strftime("%H:%M") + "** " + lines[0]
                    entry += "".join("\n  " + line for line in lines[1:])
                    entry += "\n  " + marker + "\n"
                    # Preserve existing bytes; a clock correction can revisit an earlier day.
                    match = re.search(r"^" + re.escape(heading) + r"\r?$", original, re.M)
                    if match:
                        following = re.search(r"^## ", original[match.end():], re.M)
                        position = match.end() + following.start() if following else len(original)
                        prefix, suffix = original[:position], original[position:]
                        updated = prefix + ("\n" if not prefix.endswith("\n") else "") + entry + ("\n" if suffix else "") + suffix
                    else:
                        updated = original + ("\n\n" if original and not original.endswith("\n\n") else "") + heading + "\n\n" + entry
                    state_fd = os.open(self.state, os.O_RDONLY | os.O_DIRECTORY)
                    try:
                        atomic_at(state_fd, pending_path.name, json.dumps(dict(id=draft["id"], vault=str(vault),
                                  directory=relative, time=now.isoformat())).encode())
                    finally:
                        os.close(state_fd)
                    atomic_at(directory, name, updated.encode("utf-8"))
                os.fsync(directory)
                path = vault / relative / name
            finally:
                os.close(directory)
        # If this fails, the same persisted id can safely be retried.
        next_draft = self.draft(dict(id=uuid.uuid4().hex, text="", context=draft["context"]))
        return dict(event="saved", id=next_draft["id"], uri="obsidian://open?path=" + quote(str(path), safe=""))


def main():
    state = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state") / "nayori/quick-capture"
    try:
        store = Capture(state)
        print(json.dumps(dict(event="ready", draft=store.load())), flush=True)
    except (OSError, ValueError) as error:
        print(json.dumps(dict(event="error", error="Не удалось прочитать черновик: " + str(error))), flush=True)
        return
    for line in sys.stdin:
        data = {}
        try:
            data = json.loads(line)
            if not isinstance(data, dict):
                data = {}
                raise ValueError("Ожидался объект запроса")
            if data.get("action") == "draft":
                store.draft(data)
                result = dict(event="draft")
            elif data.get("action") == "save":
                result = store.save(data)
            else:
                raise ValueError("Неизвестное действие")
        except (OSError, ValueError) as error:
            result = dict(event="error", action=data.get("action", ""), error="Не удалось сохранить: " + str(error))
        print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    main()
