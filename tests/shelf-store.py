"""Shelf persistence and file operations, entirely inside a disposable directory."""
import base64
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "services/shelf/shelf_store.py"
spec = importlib.util.spec_from_file_location("shelf_store", WORKER)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def fails(operation):
    try:
        operation()
    except (ValueError, OSError):
        return
    raise AssertionError("Expected an error")


with tempfile.TemporaryDirectory(prefix="nayori-shelf-test-") as temporary:
    directory = Path(temporary)
    shelf = module.Shelf(directory / "store")
    source = directory / "С пробелами #1?.txt"
    source.write_text("payload")
    folder = directory / "folder"
    folder.mkdir()
    shelf.add(dict(urls=[source.as_uri(), folder.as_uri(), "https://example.org/page"], text=""))
    shelf.add(dict(text="  test\ntext  "))
    assert sorted(i["kind"] for i in shelf.items()) == ["file", "folder", "link", "text"]
    file = next(i for i in shelf.items() if i["path"] == str(source))
    assert file["uri"] == source.as_uri()
    shelf.action(dict(action="fav", id=file["id"]))
    shelf.add(dict(urls=[source.as_uri()]))
    assert len(shelf.items()) == 4
    assert shelf.items()[0]["fav"]
    shelf.action(dict(action="taken", id=file["id"]))
    assert len(shelf.items()) == 4
    shelf.action(dict(action="fav", id=file["id"]))
    shelf.action(dict(action="taken", id=file["id"]))
    assert len(shelf.items()) == 3
    shelf.add(dict(text="note", note=True))
    note = shelf.items()[0]
    shelf.action(dict(action="taken", id=note["id"]))
    assert shelf.find(note["id"])
    shelf.action(dict(action="edit", id=note["id"], text="changed\nwords"))
    shelf = module.Shelf(directory / "store")
    assert shelf.find(note["id"])["text"] == "changed\nwords"
    shelf.action(dict(action="edit", id=note["id"], text="  "))
    assert not shelf.find(note["id"])
    first = shelf.put("text", text="original")
    shelf.action(dict(action="edit", id=first["id"], text="edited"))
    second = shelf.put("text", text="original")
    assert first["id"] != second["id"]
    assert shelf.find(first["id"])["text"] == "edited"
    favorite = next(i for i in shelf.items() if i["kind"] == "folder")
    fails(lambda: shelf.action(dict(action="into", id=favorite["id"], urls=[source.as_uri()])))
    shelf.action(dict(action="fav", id=favorite["id"]))
    for _ in range(2):
        shelf.action(dict(action="into", id=favorite["id"], urls=[source.as_uri()]))
    assert (folder / source.name).read_text() == "payload"
    assert (folder / (source.stem + " (2)" + source.suffix)).read_text() == "payload"
    fails(lambda: shelf.action(dict(action="into", id=favorite["id"], urls=[directory.as_uri()])))
    fails(lambda: shelf.add(dict(urls=["file://remote-host/tmp/file"])))
    fails(lambda: shelf.add(dict(urls=["javascript:alert(1)"])))
    fails(lambda: shelf.add(dict(text="x" * (module.MAX_TEXT + 1))))
    fails(lambda: shelf.add(dict()))
    shelf.add(dict(urls=[source.as_uri()]))
    source.unlink()
    assert shelf.items()[0]["missing"]
    fails(lambda: shelf.action(dict(action="open", id=shelf.items()[0]["id"])))
    image = (ROOT / "assets/branding/nayori-fox-logo.png").read_bytes()
    shelf.add(dict(image="data:image/png;base64," + base64.b64encode(image).decode()))
    picture = shelf.items()[0]
    assert picture["kind"] == "image"
    assert Path(picture["path"]).read_bytes() == image
    assert Path(picture["path"]).stat().st_mode & 0o777 == 0o600
    shelf.action(dict(action="taken", id=picture["id"]))
    assert Path(picture["path"]).exists(), "receiver may still be reading the accepted drag"
    video = b"\x00\x00\x00\x18ftypmp42" + b"V" * 100000
    shelf.add(dict(media=base64.b64encode(video).decode(), mime="video/mp4"))
    assert shelf.items()[0]["kind"] == "video"
    assert Path(shelf.items()[0]["path"]).read_bytes() == video
    fails(lambda: shelf.add(dict(media=base64.b64encode(b"invalid video").decode(), mime="video/mp4")))
    fails(lambda: shelf.add(dict(image="blob:https://example.org/private")))
    # Failed browser image fetch preserves an actionable source link.
    shelf.image = lambda src: (_ for _ in ()).throw(ValueError("offline"))
    fails(lambda: shelf.add(dict(image="https://example.org/fail.png")))
    assert shelf.items()[0]["kind"] == "link" and shelf.items()[0]["failed"]
    module.MAX_ITEMS = len(shelf.items())
    fails(lambda: shelf.add(dict(text="overflow")))
    assert (directory / "store/shelf.sqlite3").stat().st_mode & 0o777 == 0o600
    # Exercise JSON-line protocol and restart persistence without a live clipboard/session.
    environment = dict(os.environ, XDG_STATE_HOME=str(directory / "state"))
    def worker(commands):
        result = subprocess.run(["python3", "-u", str(WORKER)], env=environment,
                                input="".join(json.dumps(c) + "\n" for c in commands),
                                capture_output=True, text=True, timeout=10, check=True)
        return [json.loads(line) for line in result.stdout.splitlines()]
    states = worker([dict(action="add", text="persistent", note=True), dict(action="add", urls=["ssh://bad"]), dict(action="list")])
    assert states[1]["items"][0]["text"] == "persistent"
    assert states[2]["error"]
    assert not states[3]["error"]
    assert worker([])[0]["items"][0]["note"]
print("SHELF_STORE_PASS")
