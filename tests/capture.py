"""Image export, recorder commands and real worker IPC. No desktop/clipboard access."""
import importlib.util
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("capture_worker", ROOT / "services/capture/capture_worker.py")
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)


class CaptureTests(unittest.TestCase):
    def test_scaled_crop_and_blur_flattening(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "frame.png"
            image = Image.new("RGB", (400, 240))
            pixels = image.load()
            for y in range(image.height):
                for x in range(image.width):
                    pixels[x, y] = (255, 255, 255) if (x // 2 + y // 2) % 2 else (0, 0, 0)
            image.save(path)
            area = dict(x=25, y=20, w=100, h=70)
            base = worker.render(path, area, [], (200, 120))
            blurred = worker.render(path, area, [dict(tool="blur", x=25, y=20, ex=125, ey=90)], (200, 120))
            self.assertEqual(base.size, (200, 140))
            self.assertGreater(ImageStat.Stat(base).stddev[0], 100)
            self.assertLess(ImageStat.Stat(blurred).stddev[0], 10)
            self.assertEqual(blurred.mode, "RGB")
            annotated = worker.render(path, area, [dict(tool="text", x=30, y=30, text="Подпись"),
                dict(tool="arrow", x=30, y=30, ex=60, ey=65), dict(tool="rect", x=40, y=40, ex=70, ey=70)], (200, 120))
            self.assertNotEqual(annotated.tobytes(), base.tobytes())
            with self.assertRaises(ValueError):
                worker.render(path, dict(x=190, y=0, w=20, h=20), [], (200, 120))
            with self.assertRaises(ValueError):
                worker.render(path, dict(x=float("nan"), y=0, w=20, h=20), [], (200, 120))

    def test_region_audio_cursor_and_formats(self):
        output = dict(x=-1920, y=100, width=1920, height=1080)
        options = dict(captureFormat="webm", captureFps=60, captureQuality="very_high", captureMic=True, captureSystemAudio=True, captureCursor=False)
        command = worker.record_command(output, dict(x=100, y=40, w=640, h=480), options, Path("/tmp/a file.webm"))
        self.assertIn("640x480+-1820+140", command)
        self.assertEqual(command[command.index("-a") + 1], "default_output|default_input")
        self.assertEqual(command[command.index("-k") + 1], "vp9")
        self.assertEqual(command[command.index("-cursor") + 1], "no")
        with self.assertRaises(ValueError):
            worker.record_command(output, dict(x=10, y=10, w=9999, h=10), options, Path("/tmp/file"))

    def test_worker_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="nayori-capture-test-") as temp:
            folder = Path(temp)
            tools = folder / "bin"
            tools.mkdir()
            def executable(name, code):
                path = tools / name
                path.write_text("#!" + sys.executable + "\n" + code)
                path.chmod(0o755)
            frame = folder / "original.png"
            Image.new("RGB", (640, 480), "#223344").save(frame)
            video = folder / "fixture.mp4"
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=blue:s=64x64:d=0.2", "-c:v", "libx264", str(video)], check=True)
            executable("niri", 'import json;print(json.dumps({"TEST": {"current_mode": 0, "logical": {"x": -320, "y": 0, "width": 320, "height": 240}}}))\n')
            executable("grim", 'import shutil,sys,os;shutil.copyfile(os.environ["FRAME"],sys.argv[-1])\n')
            executable("wl-copy", 'import sys,os,pathlib;pathlib.Path(os.environ["COPY"]).write_bytes(sys.stdin.buffer.read())\n')
            executable("gpu-screen-recorder", '''import sys,os,signal,time,shutil,pathlib,json
pathlib.Path(os.environ["ARGS"]).write_text(json.dumps(sys.argv[1:]))
shutil.copyfile(os.environ["VIDEO"],sys.argv[sys.argv.index("-o")+1])
signal.signal(signal.SIGINT,lambda *_:sys.exit(0))
signal.signal(signal.SIGUSR2,lambda *_:None)
while True:time.sleep(.05)
''')
            env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"], XDG_RUNTIME_DIR=temp,
                       FRAME=str(frame), VIDEO=str(video), COPY=str(folder / "copy"), ARGS=str(folder / "args"))
            proc = subprocess.Popen([sys.executable, "-u", str(ROOT / "services/capture/capture_worker.py")],
                                    env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
            def response():
                self.assertTrue(select.select([proc.stdout], [], [], 8)[0], "worker did not respond")
                line = proc.stdout.readline()
                self.assertTrue(line, proc.stderr.read() if proc.poll() is not None else "worker EOF")
                return json.loads(line)
            def send(action, **data):
                proc.stdin.write(json.dumps(dict(action=action, **data)) + "\n")
                proc.stdin.flush()
                return response()
            options = dict(captureShotDir=str(folder / "shots ; $(false)"), captureVideoDir=str(folder / "video # files"), captureSystemAudio=False)
            try:
                self.assertEqual(response()["event"], "ready")
                ready = send("prepare", output="TEST")
                self.assertEqual(ready["event"], "prepared")
                result = send("export", rect=dict(x=10, y=10, w=100, h=50), marks=[], options=options, copy=True)
                self.assertEqual(result["event"], "saved")
                self.assertTrue(result["copied"])
                self.assertTrue((folder / "copy").read_bytes().startswith(b"\x89PNG"))
                with Image.open(result["path"]) as result_image:
                    self.assertEqual(result_image.size, (200, 100))
                self.assertEqual(Path(result["path"]).stat().st_mode & 0o777, 0o600)
                self.assertEqual(send("prepare", output="TEST")["event"], "prepared")
                self.assertEqual(send("start", rect=dict(x=0, y=0, w=100, h=100), options=options)["event"], "recording")
                self.assertTrue(send("pause")["paused"])
                self.assertFalse(send("pause")["paused"])
                saved = send("stop")
                self.assertEqual(saved["event"], "saved")
                self.assertEqual(saved["kind"], "video")
                self.assertEqual((folder / "copy").read_text(), Path(saved["path"]).as_uri() + "\n")
                self.assertEqual(send("prepare", output="TEST")["event"], "prepared")
                self.assertEqual(send("cancel")["event"], "cancelled")
                self.assertEqual(send("export", rect=dict(x=0, y=0, w=10, h=10), options=options)["event"], "error")
                proc.stdin.close()
                self.assertEqual(proc.wait(timeout=8), 0, proc.stderr.read())
                self.assertFalse(list(folder.glob("nayori-capture-*")), "private frames not cleaned")
            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        proc.kill(); proc.wait()
                proc.stdout.close(); proc.stderr.close()


if __name__ == "__main__":
    unittest.main()
