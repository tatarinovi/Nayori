"""Imported widget I/O contracts: fixtures only, no network or device commands."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / 'services/desktop/imported_widget_worker.py'
SPEC = importlib.util.spec_from_file_location('widget_worker', SOURCE)
worker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(worker)


class WorkerTests(unittest.TestCase):
    def test_zones_and_invalid_zone(self):
        rows = worker.handle('zones', {'zones': ['UTC', 'Asia/Tokyo']})['entries']
        self.assertEqual([r['offset'] for r in rows], [0, 540])
        self.assertTrue(all(0 <= r['hour'] < 24 for r in rows))
        with self.assertRaises(KeyError):
            worker.handle('zones', {'zones': ['No/Such_Zone']})

    def test_github_uses_actual_counts(self):
        payload = {'contributions': [{'date': '2026-01-01', 'count': 13, 'level': 3}]}
        with patch.object(worker, 'remote', return_value=json.dumps(payload)) as remote:
            result = worker.handle('github', {'user': 'fixture', 'year': 2026})
            self.assertEqual(result['total'], 13)
            self.assertEqual(result['contributions'][0]['count'], 13)
            self.assertIn('/fixture?y=', remote.call_args.args[0])
        with self.assertRaises(ValueError):
            worker.handle('github', {'user': 'a/b'})

    def test_rss_and_atom_reject_non_web_links(self):
        fixtures = [
            b'<rss><channel><item><title>A &amp; B</title><link>https://example.org/a</link></item><item><link>file:///secret</link></item></channel></rss>',
            b'<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>A &amp; B</title><link href="https://example.org/a"/></entry></feed>',
        ]
        for body in fixtures:
            with patch.object(worker, 'remote', return_value=body):
                result = worker.handle('news', {'url': 'https://example.org/rss'})
                self.assertEqual(len(result['articles']), 1)
                self.assertEqual(result['articles'][0]['title'], 'A & B')
                self.assertEqual(result['articles'][0]['url'], 'https://example.org/a')
        with self.assertRaises(ValueError):
            worker.remote('file:///etc/passwd')

    def test_local_lyrics_and_missing_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'fixture.lrc'
            path.write_text('[00:30.50]Later\n[00:01.00][00:02.00]First\n', encoding='utf-8')
            result = worker.handle('lyrics', {'path': str(path)})
            self.assertEqual(result['status'], 'synced')
            self.assertEqual([r['t'] for r in result['lines']], [1, 2, 30.5])
            self.assertEqual(result['lines'][0]['text'], 'First')
            path.write_text('Plain text')
            self.assertEqual(worker.handle('lyrics', {'path': str(path)})['status'], 'plain')
            path.unlink()
            with self.assertRaises(ValueError):
                worker.handle('lyrics', {'path': str(path)})

    def test_converter_never_overwrites_and_cleans_tempfiles(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / 'input.png', Path(tmp) / 'output.webp'
            source.write_bytes(b'input')
            command = ['ffmpeg', '-y', '-i', str(source), str(output)]
            def convert(argv, **kwargs):
                self.assertNotEqual(argv[-1], str(output))
                Path(argv[-1]).write_bytes(b'converted')
                return subprocess.CompletedProcess(argv, 0, '', '')
            with patch.object(worker.subprocess, 'run', side_effect=convert) as run:
                self.assertEqual(worker.handle('command', {'command': command})['exitCode'], 0)
                self.assertEqual(output.read_bytes(), b'converted')
                with self.assertRaises(ValueError):
                    worker.handle('command', {'command': command})
                self.assertEqual(run.call_count, 1)
            output.unlink()
            with patch.object(worker.subprocess, 'run', return_value=subprocess.CompletedProcess(command, 7, '', 'bad input')):
                self.assertEqual(worker.handle('command', {'command': command})['exitCode'], 7)
                self.assertFalse(output.exists())
            with patch.object(worker.subprocess, 'run', side_effect=subprocess.TimeoutExpired(command, 120)):
                with self.assertRaises(subprocess.TimeoutExpired):
                    worker.handle('command', {'command': command})
            self.assertEqual(list(Path(tmp).glob('.nayori-convert-*')), [])
            with self.assertRaises(ValueError):
                worker.handle('command', {'command': ['sh', '-c', 'anything']})

    def test_publish_race_preserves_new_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, output = Path(tmp) / 'input.png', Path(tmp) / 'out.png'
            source.write_bytes(b'input')
            def race(argv, **kwargs):
                output.write_bytes(b'another writer')
                return subprocess.CompletedProcess(argv, 0, '', '')
            with patch.object(worker.subprocess, 'run', side_effect=race):
                with self.assertRaises(FileExistsError):
                    worker.handle('command', {'command': ['magick', str(source), str(output)]})
            self.assertEqual(output.read_bytes(), b'another writer')
            self.assertEqual(list(Path(tmp).glob('.nayori-convert-*')), [])

    def test_shared_cache_and_explicit_refresh(self):
        worker._cache.clear()
        capture = io.StringIO()
        with patch.object(worker, "handle", side_effect=[{"total":1}, {"total":2}]) as handle, contextlib.redirect_stdout(capture):
            worker.dispatch({"key":"one", "op":"github", "data":{"user":"fixture"}})
            worker.dispatch({"key":"two", "op":"github", "data":{"user":"fixture"}})
            worker.dispatch({"key":"one", "op":"github", "data":{"user":"fixture", "force":True}})
            worker.dispatch({"key":"two", "op":"github", "data":{"user":"fixture"}})
        self.assertEqual(handle.call_count, 2)
        self.assertEqual([json.loads(line)["data"]["total"] for line in capture.getvalue().splitlines()], [1, 1, 2, 2])

    def test_dispatch_preserves_token_and_returns_errors(self):
        capture = io.StringIO()
        with contextlib.redirect_stdout(capture):
            worker.dispatch({'key': 'one', 'token': 17, 'op': 'missing', 'data': {}})
        reply = json.loads(capture.getvalue())
        self.assertEqual((reply['key'], reply['token']), ('one', 17))
        self.assertEqual(reply['data']['exitCode'], 1)
        self.assertTrue(reply['data']['error'])


if __name__ == '__main__':
    unittest.main()
