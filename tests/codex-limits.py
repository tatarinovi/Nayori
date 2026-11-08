import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("codex_limits", Path(__file__).resolve().parents[1] / "services/status/codex_limits.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class LimitsTest(unittest.TestCase):
    def test_used_to_remaining(self):
        data = module.parse(json.dumps({"text": "<span>NAYORI|6|43|4h 29m|7h 49m</span>"}))
        self.assertEqual([item["left"] for item in data["windows"]], [94, 57])

    def test_invalid_output(self):
        for text in ("broken", json.dumps({"text": "NAYORI|—|43|?|?"}), json.dumps({"text": "NAYORI|101|0|?|?"})):
            self.assertEqual(module.parse(text)["status"], "error")

    @patch.object(module.subprocess, "run", side_effect=FileNotFoundError)
    def test_missing(self, _run):
        self.assertEqual(module.scan()["status"], "missing")

    @patch.object(module.subprocess, "run", side_effect=subprocess.TimeoutExpired("ai-usagebar", 20))
    def test_timeout(self, _run):
        self.assertEqual(module.scan()["status"], "error")


if __name__ == "__main__":
    unittest.main()
