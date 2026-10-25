#!/usr/bin/env python3
"""Offline fixtures use invented text, never network access."""
import base64
import importlib.util
from pathlib import Path
import tempfile
import unittest
from urllib.parse import urlsplit

spec = importlib.util.spec_from_file_location('lyrics_fetch', Path(__file__).resolve().parents[1] / 'scripts/lyrics-fetch.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
TRACK = {'title': 'Fixture Song', 'artist': 'Test Artist', 'duration': 120}
LRC = '[00:01.00]Invented fixture one\n[00:02.00]Invented fixture two\n[00:03.00]Invented fixture three'

class LyricsTest(unittest.TestCase):
    def worker(self, fixtures):
        def fetch(url):
            path = urlsplit(url).path
            if path not in fixtures: raise OSError('offline fixture')
            return fixtures[path]
        return m.Worker(fetch=fetch)

    def test_lrc(self):
        rows = m.parse_lrc('[offset:-500]\n[00:01.25][01:02,50]<00:01.25>Made <00:01.50>up\n[ar:metadata]')
        self.assertEqual(rows, [{'t': .75, 'text': 'Made up'}, {'t': 62, 'text': 'Made up'}])

    def test_ttml(self):
        text = '<tt xmlns="http://www.w3.org/ns/ttml" xmlns:ttm="http://www.w3.org/ns/ttml#metadata"><body><div><p begin="00:01.2"><span>Made </span><span>up</span><span ttm:role="x-bg">background</span></p><p begin="2s" ttm:role="x-translation">translation</p></div></body></tt>'
        self.assertEqual(m.parse_ttml(text), [{'t': 1.2, 'text': 'Made up'}])

    def test_matching_rejects_version_artist_duration(self):
        self.assertTrue(m.matches(TRACK, 'Fixture Song (Official Video)', 'Test Artist', 121))
        self.assertFalse(m.matches(TRACK, 'Fixture Song (Live)', 'Test Artist', 120))
        self.assertFalse(m.matches(TRACK, 'Fixture Song', 'Other', 120))
        self.assertFalse(m.matches(TRACK, 'Fixture Song', 'Test Artist', 160))

    def test_lrclib_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            w = self.worker({'/api/get': {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'duration': 120, 'syncedLyrics': LRC}})
            w.cache = Path(directory)
            self.assertEqual(w.run(TRACK)['status'], 'synced')
            w.fetch_override = lambda url: self.fail('cache should avoid network')
            self.assertTrue(w.run(TRACK)['cached'])

    def test_cache_ignores_ephemeral_player_track_id(self):
        with tempfile.TemporaryDirectory() as directory:
            w = self.worker({'/api/get': {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'duration': 120, 'syncedLyrics': LRC}})
            w.cache = Path(directory)
            self.assertEqual(w.run({**TRACK, 'trackId':'/old/player/track', 'trackUrl':'https://example.test/song?session=old'})['status'], 'synced')
            w.fetch_override = lambda url: self.fail('changing player metadata must reuse cached lyrics')
            self.assertTrue(w.run({**TRACK, 'trackId':'/new/player/track', 'trackUrl':'https://example.test/song?session=new'})['cached'])

    def test_provider_order_and_plain_fallback(self):
        w = self.worker({'/api/get': {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'plainLyrics': 'Invented plain fixture'}, '/api/cloudsearch/pc': {'result': {'songs': [{'name': TRACK['title'], 'ar': [{'name': TRACK['artist']}], 'dt': 120000, 'id': 1}]}}, '/api/song/lyric': {'lrc': {'lyric': LRC}}})
        answer = w.run(TRACK)
        self.assertEqual(answer['source'], 'NetEase')
        self.assertEqual([x['source'] for x in answer['diagnostics']], list(m.SOURCES[:3]))

    def test_amll_names_and_id(self):
        row = {'metadata': [['musicName', ['Fixture Song']], ['artists', ['Test Artist']], ['spotifyId', ['0123456789abcdefghijkl']]], 'rawLyricFile': 'fixture.ttml'}
        import json
        w = self.worker({'/amll-dev/amll-ttml-db/main/metadata/raw-lyrics-index.jsonl': json.dumps(row), '/amll-dev/amll-ttml-db/main/raw-lyrics/fixture.ttml': '<tt><p begin="1s">Invented fixture one</p><p begin="2s">Invented fixture two</p><p begin="3s">Invented fixture three</p></tt>'})
        self.assertEqual(w.amll(TRACK)['status'], 'synced')
        self.assertEqual(w.amll({**TRACK, 'title': 'Different', 'trackUrl': 'https://open.spotify.com/track/0123456789abcdefghijkl'})['status'], 'synced')

    def test_kugou(self):
        w = self.worker({'/api/v3/search/song': {'data': {'info': [{'songname': TRACK['title'], 'singername': TRACK['artist'], 'duration': 120, 'hash': 'fake'}]}}, '/search': {'candidates': [{'id': 1, 'accesskey': 'fixture'}]}, '/download': {'content': base64.b64encode(LRC.encode()).decode()}})
        self.assertEqual(w.kugou(TRACK)['status'], 'synced')

    def test_qq_and_lrccx(self):
        w = self.worker({'/splcloud/fcgi-bin/smartbox_new.fcg': {'data': {'song': {'itemlist': [{'name': TRACK['title'], 'singer': TRACK['artist'], 'mid': 'fake'}]}}}, '/lyric/fcgi-bin/fcg_query_lyric_new.fcg': {'lyric': LRC}, '/jsonapi': [{'title': TRACK['title'], 'artist': TRACK['artist'], 'lrc': LRC}]})
        self.assertEqual(w.qq(TRACK)['status'], 'synced')
        self.assertEqual(w.lrccx(TRACK)['status'], 'synced')

    def test_ovh_last_and_errors_do_not_log_content(self):
        w = self.worker({'/v1/Test%20Artist/Fixture%20Song': {'lyrics': 'Invented fixture'}})
        answer = w.run(TRACK)
        self.assertEqual(answer['source'], 'lyrics.ovh')
        self.assertEqual(answer['status'], 'plain')
        self.assertEqual(len(answer['diagnostics']), 7)
        self.assertNotIn('Fixture Song', str(answer['diagnostics']))

    def test_silence_and_bracketed_lyrics(self):
        rows = m.parse_lrc('[00:01]Invented [chorus]\n[00:03]\n[00:04]Next')
        self.assertEqual(rows[0]['text'], 'Invented [chorus]')
        self.assertEqual(rows[1], {'t': 3, 'text': ''})
        self.assertIsNone(m.result('test', '[00:01]'))

    def test_cache_corrupt_stale_and_browser_metadata(self):
        import json
        import os
        import time
        fixtures = {'/api/get': {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'duration': 120, 'syncedLyrics': LRC}}
        with tempfile.TemporaryDirectory() as directory:
            w = self.worker(fixtures)
            w.cache = Path(directory)
            self.assertEqual(w.run({**TRACK, 'title': 'Test Artist - Fixture Song (Official Video)', 'artist': 'Test ArtistVEVO'})['status'], 'synced')
            cache = next(Path(directory).glob('*.json'))
            cache.write_text('broken json')
            self.assertFalse(w.run(TRACK)['cached'])
            os.utime(cache, (time.time() - 31 * 86400,) * 2)
            self.assertFalse(w.run(TRACK)['cached'])
        self.assertTrue(m.matches({**TRACK, 'artist': 'Test Artist feat. Another'}, TRACK['title'], 'Test Artist', 120))

    def test_amll_does_not_match_arbitrary_numeric_metadata(self):
        import json
        row = {'metadata': [['musicName', ['Different']], ['artists', ['Other']], ['ncmMusicId', ['1']]], 'rawLyricFile': 'forbidden.ttml'}
        w = self.worker({'/amll-dev/amll-ttml-db/main/metadata/raw-lyrics-index.jsonl': json.dumps(row)})
        self.assertIsNone(w.amll({**TRACK, 'trackUrl': 'https://other.example/1'}))

    def test_tiny_synced_rejected_and_lrclib_tries_later_candidate(self):
        self.assertIsNone(m.result('test', '[00:00]bogus'))
        self.assertIsNone(m.result('test', '[00:00]Lyrics by: Fixture\n[00:01]Composer: Fixture'))
        base = {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'duration': 120}
        w = self.worker({'/api/get': {**base, 'syncedLyrics': '[00:00]bogus'}, '/api/search': [{**base, 'syncedLyrics': '[00:00]bogus'}, {**base, 'syncedLyrics': LRC}]})
        answer = w.run(TRACK)
        self.assertEqual(answer['status'], 'synced')
        self.assertEqual(len(answer['lines']), 3)
        self.assertIsNone(m.result('test', '[00:01]one\n[00:01]two\n[00:01]three'))
        self.assertEqual(m.result('test', '[00:01]one\n[00:02]two', duration=20)['status'], 'synced')

    def test_lrclib_retries_only_http_server_errors(self):
        import urllib.error
        calls, waits = [], []
        def fetch(url):
            calls.append(url)
            if len(calls) < 10:
                raise urllib.error.HTTPError(url, 503, 'fixture', {}, None)
            return {'ok': True}
        worker = m.Worker(fetch=fetch, sleep=waits.append)
        self.assertEqual(worker.get('https://lrclib.net/api/get'), {'ok': True})
        self.assertEqual(len(calls), 10)
        self.assertEqual(waits, [.25, .5, 1.0] + [2.0] * 6)
        for url, code in [('https://lrclib.net/api/get', 429), ('https://lrclib.net/api/get', 404), ('https://api.lrc.cx/jsonapi', 503)]:
            calls.clear(); waits.clear()
            def failure(request):
                calls.append(request)
                raise urllib.error.HTTPError(request, code, 'fixture', {}, None)
            worker = m.Worker(fetch=failure, sleep=waits.append)
            with self.assertRaises(urllib.error.HTTPError): worker.get(url)
            self.assertEqual(len(calls), 1)
            self.assertEqual(waits, [])

    def test_retry_is_bounded_by_attempt_count_and_deadline(self):
        import urllib.error
        calls, waits = [], []
        now = [0.0]
        def sleep(delay):
            waits.append(delay)
            now[0] += delay
        def failure(url):
            calls.append(url)
            raise urllib.error.HTTPError(url, 502, 'fixture', {}, None)
        worker = m.Worker(fetch=failure, clock=lambda: now[0], sleep=sleep)
        with self.assertRaises(urllib.error.HTTPError): worker.get('https://lrclib.net/api/get')
        self.assertEqual(len(calls), 10)
        self.assertEqual(waits, [.25, .5, 1.0] + [2.0] * 6)
        calls.clear(); waits.clear()
        worker = m.Worker(fetch=failure, budget=.2, clock=lambda: now[0], sleep=sleep)
        with self.assertRaises(TimeoutError): worker.get('https://lrclib.net/api/get')
        self.assertEqual(len(calls), 1)
        self.assertEqual(waits, [])

    def test_exhausted_lrclib_retries_continue_provider_chain(self):
        import urllib.error
        calls, waits = [], []
        fixtures = {'/api/cloudsearch/pc': {'result': {'songs': [{'name': TRACK['title'], 'ar': [{'name': TRACK['artist']}], 'dt': 120000, 'id': 1}]}}, '/api/song/lyric': {'lrc': {'lyric': LRC}}}
        def fetch(url):
            calls.append(url)
            if urlsplit(url).hostname == 'lrclib.net':
                raise urllib.error.HTTPError(url, 503, 'fixture', {}, None)
            if urlsplit(url).path not in fixtures: raise OSError('fixture source unavailable')
            return fixtures[urlsplit(url).path]
        worker = m.Worker(fetch=fetch, sleep=waits.append)
        answer = worker.run(TRACK)
        self.assertEqual(answer['source'], 'NetEase')
        self.assertEqual(answer['status'], 'synced')
        self.assertEqual(sum(urlsplit(url).path == '/api/get' for url in calls), 10)
        self.assertEqual(sum(urlsplit(url).path == '/api/search' for url in calls), 10)
        self.assertEqual(waits, ([.25, .5, 1.0] + [2.0] * 6) * 2)
        self.assertEqual(answer['diagnostics'][0]['status'], 'error')

    def test_retired_source_cache_is_ignored_and_refresh_requeries(self):
        import json
        fixtures = {'/api/get': {'trackName': TRACK['title'], 'artistName': TRACK['artist'], 'duration': 120, 'syncedLyrics': LRC}}
        with tempfile.TemporaryDirectory() as directory:
            worker = self.worker(fixtures)
            worker.cache = Path(directory)
            worker.run(TRACK)
            cache = next(Path(directory).glob('*.json'))
            old = json.loads(cache.read_text())
            old['source'] = 'retired-provider'
            cache.write_text(json.dumps(old))
            answer = worker.run(TRACK)
            self.assertFalse(answer['cached'])
            self.assertEqual(answer['source'], 'LRCLIB')
            self.assertTrue(worker.run(TRACK)['cached'])
            self.assertFalse(worker.run({**TRACK, 'refresh': True})['cached'])
            self.assertEqual(len(list(Path(directory).glob('*.json'))), 1)

    def test_deadline_prevents_requests(self):
        w = m.Worker(fetch=lambda url: self.fail('deadline'), budget=-1)
        self.assertEqual(w.run(TRACK)['status'], 'error')

if __name__ == '__main__':
    unittest.main()
