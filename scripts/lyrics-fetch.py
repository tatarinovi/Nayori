#!/usr/bin/env python3
"""Network-only lyric lookup. One JSON track on stdin, one JSON result on stdout."""
import argparse
import base64
import hashlib
import html
import json
import os
from pathlib import Path
import re
import signal
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

SOURCES = ('LRCLIB', 'AMLL TTML DB', 'NetEase', 'Kugou', 'QQ Music', 'lrc.cx', 'lyrics.ovh')

def clean(value):
    value = re.sub(r'\s*[\[(](?:official (?:music )?(?:video|audio)|lyrics?|visualizer)[\])]','', str(value or ''), flags=re.I)
    return re.sub(r'\s+', ' ', value).strip()

def normalized(value):
    return ''.join(c for c in unicodedata.normalize('NFKC', clean(value)).casefold() if c.isalnum())

def matches(track, title, artist, duration=0):
    if normalized(title) != normalized(track['title']):
        return False
    a, b = normalized(artist), normalized(track.get('artist', ''))
    split = r'\s*(?:,|;| & | feat\.? | ft\.? )\s*'
    wanted_artists = {normalized(x) for x in re.split(split, track.get('artist', ''), flags=re.I) if normalized(x)}
    found_artists = {normalized(x) for x in re.split(split, str(artist or ''), flags=re.I) if normalized(x)}
    if b and not (a == b or wanted_artists & found_artists):
        return False
    wanted = float(track.get('duration') or 0)
    return not (wanted and duration) or abs(wanted - float(duration)) <= max(3, wanted * .02)

def parse_lrc(text):
    offset = re.search(r'\[offset:\s*([+-]?\d+)\]', text, re.I)
    offset = int(offset.group(1)) / 1000 if offset else 0
    rows = []
    for raw in text.splitlines():
        stamps = re.findall(r'\[(\d+):(\d{1,2}(?:[.,]\d+)?)\]', raw)
        content = re.sub(r'\[\d+:\d{1,2}(?:[.,]\d+)?\]|\[(?:ar|al|ti|by|offset|length):[^\]]*\]|<\d+:\d+(?:[.,]\d+)?>', '', raw, flags=re.I).strip()
        for minute, second in stamps:
            rows.append({'t': max(0, int(minute) * 60 + float(second.replace(',', '.')) + offset), 'text': html.unescape(content)})
    return sorted(rows, key=lambda row: row['t'])

def stamp(value):
    if value.endswith('ms'):
        return float(value[:-2]) / 1000
    if value.endswith('s'):
        return float(value[:-1])
    parts = value.split(':')
    return sum(float(part) * 60 ** i for i, part in enumerate(reversed(parts)))

def parse_ttml(text):
    root = ET.fromstring(text)
    def excluded(node):
        return any(value in ('x-bg', 'x-translation', 'x-roman') for key, value in node.attrib.items() if key.rsplit('}', 1)[-1] == 'role')
    def content(node):
        if excluded(node):
            return ''
        return (node.text or '') + ''.join(content(child) + (child.tail or '') for child in node)
    rows = []
    def visit(node, blocked=False):
        blocked = blocked or excluded(node)
        if not blocked and node.tag.rsplit('}', 1)[-1] == 'p' and node.get('begin'):
            line = content(node).strip()
            if line:
                rows.append({'t': stamp(node.get('begin')), 'text': line})
        for child in node:
            visit(child, blocked)
    visit(root)
    return sorted(rows, key=lambda row: row['t'])

def good_synced(lines, duration=0):
    meaningful = [row for row in lines if row['text'].strip()]
    required = 2 if 0 < duration < 30 else 3
    return len(meaningful) >= required and len({row['t'] for row in meaningful}) >= required


def result(source, text='', instrumental=False, lines=None, duration=0):
    parsed = parse_lrc(text) if lines is None else lines
    # Catalogue placeholders and credit-only rows are not usable synced lyrics.
    credit = re.compile(r'^(?:作词|作曲|编曲|词|曲|制作人|lyrics by|written by|composed by|arranged by|composer|producer)\s*[:：]', re.I)
    parsed = [row for row in parsed if not credit.match(row['text'].strip())]
    if instrumental:
        return {'status': 'instrumental', 'source': source, 'lines': [], 'plainText': ''}
    if parsed:
        if not good_synced(parsed, duration):
            return None
        return {'status': 'synced', 'source': source, 'lines': parsed, 'plainText': '\n'.join(row['text'] for row in parsed)}
    # An invalid timed payload must not become a positive plain-text cache entry.
    if lines is not None or re.search(r'\[\d+:\d', text):
        return None
    plain_lines = [line for line in text.splitlines() if not re.match(r'^\s*\[(?:ar|al|ti|by|offset|length):[^\]]*\]\s*$', line, re.I) and not credit.match(line.strip())]
    plain = '\n'.join(plain_lines).strip()
    if not plain:
        return None
    return {'status': 'plain', 'source': source, 'lines': [], 'plainText': plain}

class Worker:
    def __init__(self, cache_dir=None, fetch=None, budget=65, clock=time.monotonic, sleep=time.sleep):
        self.cache = Path(cache_dir) if cache_dir else None
        self.clock = clock
        self.sleep = sleep
        self.deadline = self.clock() + budget
        self.fetch_override = fetch
        self.diagnostics = []

    def make_result(self, source, text='', instrumental=False, lines=None):
        return result(source, text, instrumental, lines, getattr(self, 'track_duration', 0))

    def get(self, url, params=None, raw=False, headers=None, timeout=4):
        retryable = urllib.parse.urlsplit(url).hostname == 'lrclib.net'
        for attempt in range(10):
            try:
                return self._get_once(url, params, raw, headers, timeout)
            except urllib.error.HTTPError as error:
                error.close()
                if not retryable or not 500 <= error.code <= 599 or attempt == 9:
                    raise
                delay = min(2.0, 0.25 * 2 ** attempt)
                if self.deadline - self.clock() <= delay:
                    raise TimeoutError('lookup deadline') from None
                self.sleep(delay)

    def _get_once(self, url, params=None, raw=False, headers=None, timeout=4):
        if params:
            url += '?' + urllib.parse.urlencode({k: v for k, v in params.items() if v is not None})
        remaining = self.deadline - self.clock()
        if remaining <= 0:
            raise TimeoutError('lookup deadline')
        if self.fetch_override:
            value = self.fetch_override(url)
            return value if raw or not isinstance(value, str) else json.loads(value)
        request = urllib.request.Request(url, headers={'User-Agent': 'Nayori/1.0 (desktop lyrics)', **(headers or {})})
        with urllib.request.urlopen(request, timeout=min(timeout, remaining)) as response:
            data = response.read(12 * 1024 * 1024 + 1)
        if len(data) > 12 * 1024 * 1024:
            raise ValueError('response too large')
        text = data.decode('utf-8-sig')
        return text if raw else json.loads(text)

    def write_cache(self, name, value):
        if not self.cache:
            return
        try:
            self.cache.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(mode='w', dir=self.cache, delete=False, encoding='utf-8') as handle:
                temp = handle.name
                json.dump(value, handle, ensure_ascii=False)
            os.replace(temp, self.cache / name)
        except OSError:
            if 'temp' in locals():
                try: os.unlink(temp)
                except OSError: pass

    def lrclib(self, t):
        params = {'track_name': t['title'], 'artist_name': t.get('artist', ''), 'album_name': t.get('album', ''), 'duration': round(t.get('duration') or 0)}
        plain = None
        def candidate(item):
            if not matches(t, item.get('trackName'), item.get('artistName'), item.get('duration', 0)):
                return None
            synced = self.make_result('LRCLIB', item.get('syncedLyrics') or '', item.get('instrumental', False))
            return synced or self.make_result('LRCLIB', item.get('plainLyrics') or '')
        try:
            found = candidate(self.get('https://lrclib.net/api/get', params))
            if found and found['status'] != 'plain': return found
            plain = found
        except Exception:
            pass
        try:
            items = self.get('https://lrclib.net/api/search', {'track_name': t['title'], 'artist_name': t.get('artist', '')})
        except Exception:
            if plain: return plain
            raise
        for item in items:
            found = candidate(item)
            if found and found['status'] != 'plain': return found
            plain = plain or found
        return plain

    def amll(self, t):
        index = None
        path = self.cache / 'amll-index.json' if self.cache else None
        try:
            if path and time.time() - path.stat().st_mtime < 604800:
                index = json.loads(path.read_text())
        except (OSError, ValueError): pass
        if index is None:
            raw = self.get('https://raw.githubusercontent.com/amll-dev/amll-ttml-db/main/metadata/raw-lyrics-index.jsonl', raw=True, timeout=10)
            index = [json.loads(line) for line in raw.splitlines() if line.strip()]
            self.write_cache('amll-index.json', index)
        identity = str(t.get('trackUrl') or '') + ' ' + str(t.get('trackId') or '')
        spotify_ids = re.findall(r'(?:spotify:track:|open\.spotify\.com/track/)([A-Za-z0-9]{22})(?![A-Za-z0-9])', identity)
        netease_ids = re.findall(r'(?:music\.163\.com/(?:#/)?song\?id=|/netease/)(\d+)(?!\d)', identity)
        for row in index:
            meta = dict(row.get('metadata', []))
            id_match = bool(set(spotify_ids) & set(map(str, meta.get('spotifyId', []))) or set(netease_ids) & set(map(str, meta.get('ncmMusicId', []))))
            name_match = any(matches(t, title, artist) for title in meta.get('musicName', []) for artist in meta.get('artists', ['']))
            if id_match or name_match:
                filename = row.get('rawLyricFile', '')
                if not filename or '..' in filename: continue
                text = self.get('https://raw.githubusercontent.com/amll-dev/amll-ttml-db/main/raw-lyrics/' + urllib.parse.quote(filename, safe='/'), raw=True)
                return self.make_result('AMLL TTML DB', lines=parse_ttml(text))

    def netease(self, t):
        data = self.get('https://music.163.com/api/cloudsearch/pc', {'s': t['title'] + ' ' + t.get('artist', ''), 'type': 1, 'limit': 10})
        for x in data.get('result', {}).get('songs', []):
            if matches(t, x.get('name'), ', '.join(a['name'] for a in x.get('ar', [])), x.get('dt', 0) / 1000):
                data = self.get('https://music.163.com/api/song/lyric', {'id': x['id'], 'lv': 1})
                return self.make_result('NetEase', data.get('lrc', {}).get('lyric', ''))

    def kugou(self, t):
        data = self.get('https://mobilecdn.kugou.com/api/v3/search/song', {'format': 'json', 'keyword': t.get('artist', '') + ' ' + t['title'], 'page': 1, 'pagesize': 10})
        for x in data.get('data', {}).get('info', []):
            if matches(t, x.get('songname'), x.get('singername'), x.get('duration', 0)):
                candidates = self.get('https://krcs.kugou.com/search', {'ver': 1, 'man': 'yes', 'client': 'mobi', 'hash': x['hash'], 'duration': round((t.get('duration') or x.get('duration', 0)) * 1000)}).get('candidates', [])
                if not candidates: return None
                c = candidates[0]
                data = self.get('https://lyrics.kugou.com/download', {'ver': 1, 'client': 'pc', 'id': c['id'], 'accesskey': c['accesskey'], 'fmt': 'lrc', 'charset': 'utf8'})
                return self.make_result('Kugou', base64.b64decode(data.get('content', '')).decode('utf-8'))

    def qq(self, t):
        data = self.get('https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg', {'key': t.get('artist', '') + ' ' + t['title'], 'format': 'json'})
        for x in data.get('data', {}).get('song', {}).get('itemlist', []):
            if matches(t, x.get('name'), x.get('singer')):
                data = self.get('https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg', {'songmid': x['mid'], 'format': 'json', 'nobase64': 1, 'g_tk': 5381}, headers={'Referer': 'https://y.qq.com/'})
                return self.make_result('QQ Music', html.unescape(data.get('lyric', '')))

    def lrccx(self, t):
        data = self.get('https://api.lrc.cx/jsonapi', {'title': t['title'], 'artist': t.get('artist', ''), 'album': t.get('album', '')})
        for x in data if isinstance(data, list) else []:
            if matches(t, x.get('title'), x.get('artist'), x.get('duration', 0)):
                found = self.make_result('lrc.cx', x.get('lrc', ''))
                if found: return found

    def ovh(self, t):
        url = 'https://api.lyrics.ovh/v1/' + urllib.parse.quote(t.get('artist', ''), safe='') + '/' + urllib.parse.quote(t['title'], safe='')
        return self.make_result('lyrics.ovh', self.get(url).get('lyrics', ''))

    def run(self, track):
        t = {**track, 'title': clean(track.get('title')), 'artist': clean(track.get('artist')), 'duration': max(0, float(track.get('duration') or 0))}
        t['artist'] = re.sub(r'(?:VEVO| - Topic)$', '', t['artist'], flags=re.I).strip()
        prefix = t['artist'] + ' - '
        if t['artist'] and t['title'].casefold().startswith(prefix.casefold()):
            t['title'] = t['title'][len(prefix):].strip()
        if not t['title']: return {'status': 'notfound', 'source': '', 'lines': [], 'plainText': '', 'diagnostics': []}
        self.track_duration = t['duration']
        identity = {field: t.get(field, '') for field in ('title', 'artist', 'album')}
        identity['duration'] = round(t['duration'])
        key = hashlib.sha256(json.dumps(identity, sort_keys=True, ensure_ascii=False).encode()).hexdigest() + '.json'
        try:
            cache_path = self.cache / key if self.cache else None
            cached = json.loads(cache_path.read_text()) if not t.get('refresh', False) and cache_path and time.time() - cache_path.stat().st_mtime < 2592000 else None
            if isinstance(cached, dict) and cached.get('source') in SOURCES and cached.get('status') in ('synced', 'plain', 'instrumental') and isinstance(cached.get('lines'), list) and isinstance(cached.get('plainText'), str) and (cached['status'] != 'synced' or good_synced(cached['lines'], t['duration'])):
                cached['diagnostics'] = [item for item in cached.get('diagnostics', []) if isinstance(item, dict) and item.get('source') in SOURCES]
                return {**cached, 'cached': True}
        except (OSError, ValueError, TypeError, KeyError): pass
        plain = None
        for source, adapter in zip(SOURCES, (self.lrclib, self.amll, self.netease, self.kugou, self.qq, self.lrccx, self.ovh)):
            if source == 'lyrics.ovh' and plain: break
            try:
                found = adapter(t)
                self.diagnostics.append({'source': source, 'status': found['status'] if found else 'notfound'})
                if found and found['status'] != 'plain':
                    found.update(diagnostics=self.diagnostics, cached=False)
                    self.write_cache(key, found)
                    return found
                plain = plain or found
            except Exception as exc:
                # Exception class only: URLs can contain private track metadata.
                self.diagnostics.append({'source': source, 'status': 'error', 'reason': type(exc).__name__})
        failed = bool(self.diagnostics) and all(item['status'] == 'error' for item in self.diagnostics)
        found = plain or {'status': 'error' if failed else 'notfound', 'source': '', 'lines': [], 'plainText': ''}
        found.update(diagnostics=self.diagnostics, cached=False)
        if plain: self.write_cache(key, found)
        return found

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache-dir', default=os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache')), 'nayori', 'lyrics'))
    parser.add_argument('--no-cache', action='store_true')
    args = parser.parse_args()
    try:
        import sys
        track = json.load(sys.stdin)
        def deadline_reached(signum, frame):
            raise TimeoutError('lookup deadline')
        signal.signal(signal.SIGALRM, deadline_reached)
        signal.alarm(65)
        try:
            output = Worker(None if args.no_cache else args.cache_dir).run(track)
        finally:
            signal.alarm(0)
    except Exception as exc:
        output = {'status': 'error', 'source': '', 'lines': [], 'plainText': '', 'reason': type(exc).__name__}
    print(json.dumps(output, ensure_ascii=False))

if __name__ == '__main__':
    main()
