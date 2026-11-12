"""Shared, on-demand I/O for imported widgets. JSON lines; never a shell."""
import concurrent.futures
import datetime as dt
import html
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo

_lock = threading.Lock()
_cache = {}


def remote(url):
    if urllib.parse.urlsplit(url).scheme != 'https':
        raise ValueError('Only HTTPS sources are supported')
    request = urllib.request.Request(url, headers={'User-Agent': 'Nayori widgets/1.0'})
    with urllib.request.urlopen(request, timeout=15) as response:
        content = response.read(4 * 1024 * 1024 + 1)
        if len(content) > 4 * 1024 * 1024:
            raise ValueError('Response is too large')
        return content


def handle(op, data):
    if op == 'capabilities':
        return {'nightlight': bool(shutil.which('gammastep')), 'brightness': bool(shutil.which('brightnessctl')),
                'ffmpeg': bool(shutil.which('ffmpeg')), 'magick': bool(shutil.which('magick')), 'easyeffects':bool(shutil.which('easyeffects'))}
    if op == 'nightlight':
        command = ['gammastep', '-P', '-O', '4000'] if data.get('enabled') else ['gammastep', '-x']
        subprocess.run(command, timeout=10, check=True, capture_output=True)
        return {'enabled': bool(data.get('enabled'))}
    if op == 'zones':
        now = dt.datetime.now(dt.timezone.utc)
        rows = []
        for name in data.get('zones', [])[:4]:
            current = now.astimezone(ZoneInfo(str(name)))
            rows.append({'zone': name, 'name': str(name).split('/')[-1].replace('_', ' '),
                         'offset': current.utcoffset().total_seconds() / 60,
                         'year': current.year, 'month': current.month, 'day': current.day,
                         'hour': current.hour, 'minute': current.minute, 'second': current.second,
                         'time': current.strftime('%H:%M'), 'isDay': 6 <= current.hour < 18})
        return {'entries': rows}
    if op == 'github':
        user = str(data.get('user', ''))
        if not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})', user):
            raise ValueError('Invalid GitHub username')
        year = max(2008, min(dt.date.today().year, int(data.get('year', dt.date.today().year))))
        body = json.loads(remote('https://github-contributions-api.jogruber.de/v4/' + user + '?y=' + str(year)))
        rows = [{'date': r['date'], 'count': int(r['count']), 'level': int(r['level'])}
                for r in body.get('contributions', []) if isinstance(r, dict) and 'count' in r][:400]
        return {'contributions': rows, 'total': sum(r['count'] for r in rows), 'user': user, 'year': year}
    if op == 'news':
        tree = ET.fromstring(remote(str(data.get('url', ''))))
        articles = []
        for node in list(tree.findall('.//item')) + list(tree.findall('.//{http://www.w3.org/2005/Atom}entry')):
            def get(tag):
                return node.findtext(tag, '') or node.findtext('{http://www.w3.org/2005/Atom}' + tag, '')
            link = get('link')
            if not link:
                item = node.find('{http://www.w3.org/2005/Atom}link')
                link = item.get('href', '') if item is not None else ''
            if urllib.parse.urlsplit(link).scheme not in ('https', 'http'):
                continue
            articles.append({'title': html.unescape(get('title')), 'link': link, 'url': link,
                             'source': urllib.parse.urlsplit(link).hostname or '',
                             'timestamp': get('pubDate') or get('published') or get('updated'),
                             'description': html.unescape(get('description') or get('summary'))})
        return {'articles': articles[:60]}
    if op == 'lyrics':
        path = Path(str(data.get('path', ''))).expanduser()
        if not path.is_file() or path.stat().st_size > 1024 * 1024 or path.suffix.lower() not in ('.lrc', '.txt'):
            raise ValueError('Select an LRC or TXT file smaller than 1 MB')
        content = path.read_text(encoding='utf-8-sig')
        rows = []
        for line in content.splitlines():
            text = re.sub(r'\[\d+:\d+(?:\.\d+)?\]', '', line)
            for minute, second in re.findall(r'\[(\d+):(\d+(?:\.\d+)?)\]', line):
                rows.append({'t': int(minute) * 60 + float(second), 'text': text})
        return {'status': 'synced' if rows else 'plain', 'lines': sorted(rows, key=lambda r: r['t']), 'plainText': content}
    if op == 'brightness':
        if 'value' in data:
            value = max(0, min(100, round(float(data['value']) * 100)))
            subprocess.run(['brightnessctl', 'set', str(value) + '%'], check=True, timeout=5, capture_output=True)
        value = subprocess.run(['brightnessctl', '-m'], check=True, timeout=5, capture_output=True, text=True).stdout
        match = re.search(r',(\d+)%,', value)
        return {'available': bool(match), 'value': int(match[1]) / 100 if match else 0}
    if op == 'command':
        argv = data.get('command', [])
        if not isinstance(argv, list) or not all(isinstance(s, str) and '\x00' not in s for s in argv):
            raise ValueError('Invalid conversion command')
        if not argv or argv[0] not in ('ffmpeg', 'magick'):
            raise ValueError('Unsupported conversion command')
        if argv[0] == 'ffmpeg' and (len(argv) != 5 or argv[1:3] not in (['-y', '-i'], ['-n', '-i'])):
            raise ValueError('Unsupported ffmpeg arguments')
        inputs = [argv[3]] if argv[0] == 'ffmpeg' else argv[1:-1]
        if not inputs or any(not Path(path).is_absolute() or not Path(path).is_file() for path in inputs):
            raise ValueError('Conversion inputs must be existing absolute file paths')
        output = Path(argv[-1])
        if not output.is_absolute() or output.exists():
            raise ValueError('Output already exists or is not an absolute path')
        # Render to an owned temporary file, then publish without overwriting.
        fd, temporary = tempfile.mkstemp(prefix='.nayori-convert-', suffix=output.suffix, dir=output.parent)
        os.close(fd)
        try:
            argv = argv[:-1] + [temporary]
            if argv[0] == 'ffmpeg':
                argv[1] = '-y'  # only our own temporary file
            result = subprocess.run(argv, timeout=120, capture_output=True, text=True)
            if result.returncode == 0:
                os.link(temporary, output)
            return {'exitCode': result.returncode, 'exitStatus': 0, 'error': result.stderr[-2000:] if result.returncode else ''}
        finally:
            Path(temporary).unlink(missing_ok=True)
    raise ValueError('Unknown operation')


def dispatch(request):
    key = str(request.get('key', ''))[:512]
    op = request.get('op')
    data = request.get('data', {})
    try:
        cache_key = json.dumps([op, {key: value for key, value in data.items() if key != 'force'}], sort_keys=True)
        now = dt.datetime.now().timestamp()
        ttl = {'github': 900, 'news': 900, 'zones': 30}.get(op, 0)
        cached = _cache.get(cache_key)
        result = cached[1] if cached and not data.get('force') and now - cached[0] < ttl else handle(op, data)
        if ttl:
            if len(_cache) > 200:
                _cache.clear()
            _cache[cache_key] = (now, result)
        response = {'key': key, 'token': request.get('token'), 'data': result}
    except Exception as error:
        response = {'key': key, 'token': request.get('token'), 'data': {'error': str(error), 'exitCode': 1, 'exitStatus': 0}}
    with _lock:
        print(json.dumps(response, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for line in sys.stdin:
            try:
                request = json.loads(line)
                if isinstance(request, dict):
                    pool.submit(dispatch, request)
            except (ValueError, TypeError):
                continue
