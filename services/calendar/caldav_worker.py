"""Read-only CalDAV bridge. Credentials travel over stdin and Secret Service only."""
import base64
import datetime as dt
import hashlib
import html
import re
import json
import subprocess
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

D = '{DAV:}'
C = '{urn:ietf:params:xml:ns:caldav}'
LIMIT = 8 * 1024 * 1024


def identity(url, user):
    return hashlib.sha256((url + '\n' + user).encode()).hexdigest()


def secret(key, password=None):
    args = ['secret-tool', 'lookup' if password is None else 'store', 'application', 'nayori-calendar', 'account', key]
    if password is not None:
        args[2:2] = ['--label=Nayori CalDAV']
    result = subprocess.run(args, input=password, text=True, capture_output=True, timeout=30, check=False)
    if result.returncode:
        raise ValueError('Не удалось открыть хранилище паролей. Проверьте Secret Service и secret-tool')
    return result.stdout.rstrip('\n') if password is None else password


def request(url, user, password, method, body):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.fragment:
        raise ValueError('Нужен HTTPS-адрес CalDAV без пароля в URL')
    # Never send credentials across redirects (including to another origin).
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    req = urllib.request.Request(url, body.encode(), method=method, headers={
        'Authorization': 'Basic ' + base64.b64encode((user + ':' + password).encode()).decode(),
        'Content-Type': 'application/xml; charset=utf-8', 'Depth': '1'})
    with urllib.request.build_opener(NoRedirect).open(req, timeout=15) as response:
        data = response.read(LIMIT + 1)
    if len(data) > LIMIT or b'<!DOCTYPE' in data.upper() or b'<!ENTITY' in data.upper():
        raise ValueError('Ответ календаря слишком большой или имеет неподдерживаемый формат')
    return ET.fromstring(data)


def same_origin(base, href):
    target = urllib.parse.urljoin(base, href)
    if urllib.parse.urlsplit(target)[:2] != urllib.parse.urlsplit(base)[:2]:
        raise ValueError('Сервер вернул календарь на другом адресе')
    return target


def calendars(url, user, password):
    body = '<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><d:resourcetype/><d:current-user-principal/><c:calendar-home-set/></d:prop></d:propfind>'
    visited = set()
    queue = [url]
    found = []
    while queue and len(visited) < 4:
        current = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)
        tree = request(current, user, password, 'PROPFIND', body)
        for response in tree.findall(D + 'response'):
            href = response.findtext(D + 'href')
            if href and response.find('.//' + C + 'calendar') is not None:
                found.append(same_origin(url, href))
            for tag in [D + 'current-user-principal', C + 'calendar-home-set']:
                for node in response.findall('.//' + tag + '/' + D + 'href'):
                    queue.append(same_origin(url, node.text or ''))
        if found:
            return sorted(set(found))[:20]
    raise ValueError('Календари не найдены. Укажите адрес коллекции CalDAV или calendar home')


def event_link(description):
    """Prefer meeting links; otherwise use the first HTTP(S) URL in the description."""
    links = []
    for match in re.finditer(r"https?://[^\s<>\"']+", html.unescape(description), re.IGNORECASE):
        candidate = match.group().rstrip('.,;:!?)]}')
        try:
            parsed = urllib.parse.urlsplit(candidate)
            if parsed.hostname and not parsed.username:
                links.append(candidate)
        except ValueError:
            continue
    for link in links:
        if urllib.parse.urlsplit(link).hostname.lower() in ('telemost.360.yandex.ru', 'peregovorka.mos.ru'):
            return link
    return links[0] if links else ''


def events(url, user, password):
    try:
        import icalendar
        import recurring_ical_events
    except ImportError as exc:
        raise ValueError('Нужны python-icalendar и python-recurring-ical-events') from exc
    now = dt.datetime.now(dt.timezone.utc)
    start, end = now - dt.timedelta(days=31), now + dt.timedelta(days=366)
    body = '<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"><d:prop><c:calendar-data/></d:prop><c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT"><c:time-range start="%s" end="%s"/></c:comp-filter></c:comp-filter></c:filter></c:calendar-query>' % (start.strftime('%Y%m%dT%H%M%SZ'), end.strftime('%Y%m%dT%H%M%SZ'))
    result = []
    for collection in calendars(url, user, password):
        tree = request(collection, user, password, 'REPORT', body)
        for node in tree.iter(C + 'calendar-data'):
            calendar = icalendar.Calendar.from_ical(node.text or '')
            for event in recurring_ical_events.of(calendar).between(start, end):
                if str(event.get('STATUS', '')) == 'CANCELLED':
                    continue
                begin = event.decoded('DTSTART')
                finish = event.decoded('DTEND', begin)
                all_day = not isinstance(begin, dt.datetime)
                def stamp(value):
                    if isinstance(value, dt.datetime):
                        return value.astimezone().isoformat()
                    return value.isoformat()
                result.append({'title': str(event.get('SUMMARY', 'Без названия'))[:500], 'start': stamp(begin), 'end': stamp(finish), 'allDay': all_day, 'link': event_link(str(event.get('DESCRIPTION', '')))})
                if len(result) > 5000:
                    raise ValueError('Слишком много событий в календаре')
    return sorted(result, key=lambda event: event['start'])


def handle(message):
    url, user = message.get('url', '').strip(), message.get('user', '').strip()
    if not url or not user:
        return {'events': [], 'error': ''}
    key = identity(url, user)
    password = message.get('password') or secret(key)
    result = events(url, user, password)
    if message.get('password'):
        secret(key, password)
    return {'events': result, 'error': '', 'connected': True}


def main():
    for line in sys.stdin:
        try:
            result = handle(json.loads(line))
        except ValueError as exc:
            result = {'error': str(exc)}
        except Exception:
            result = {'error': 'CalDAV недоступен. Проверьте адрес, пароль приложения и соединение'}
        print(json.dumps(result, ensure_ascii=False), flush=True)


if __name__ == '__main__':
    main()
