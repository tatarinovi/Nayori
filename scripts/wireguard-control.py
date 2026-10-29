"""WireGuard profiles owned by NetworkManager; JSON IPC, never read secrets."""
import json
import os
import subprocess
import sys
import uuid
from pathlib import Path
from urllib.parse import unquote, urlparse


class ControlError(Exception):
    pass


def nmcli(*args):
    try:
        result = subprocess.run(
            ['nmcli', '--colors', 'no', '--wait', '30', *args],
            capture_output=True, text=True, timeout=35,
            env={**os.environ, 'LC_ALL': 'C'},
        )
    except FileNotFoundError:
        raise ControlError('Команда nmcli не найдена. Установите NetworkManager') from None
    except subprocess.TimeoutExpired:
        raise ControlError('NetworkManager не ответил. Проверьте состояние подключения') from None
    if result.returncode:
        if 'import' in args:
            message = 'Не удалось импортировать WireGuard. Проверьте конфигурацию и права доступа'
        elif result.returncode == 3:
            message = 'Время ожидания истекло. Проверьте состояние подключения'
        elif result.returncode == 4:
            message = 'Не удалось подключить WireGuard. Проверьте профиль и доступ к серверу'
        elif result.returncode == 5:
            message = 'Не удалось отключить WireGuard. Обновите список и повторите попытку'
        elif result.returncode == 8:
            message = 'NetworkManager не запущен'
        elif 'not authorized' in result.stderr.lower() or 'permission denied' in result.stderr.lower():
            message = 'Нет прав на изменение подключения. Проверьте разрешения NetworkManager'
        elif 'secrets' in result.stderr.lower():
            message = 'В профиле не хватает ключа. Проверьте его в редакторе подключений'
        else:
            message = 'NetworkManager недоступен. Проверьте службу и права доступа'
        raise ControlError(message)
    return result.stdout


def fields(line):
    """Decode nmcli terse escaping, including colons and backslashes in names."""
    result, current, escaped = [], [], False
    for char in line:
        if escaped:
            current.append(char)
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            result.append(''.join(current))
            current = []
        else:
            current.append(char)
    if escaped:
        current.append('\\')
    result.append(''.join(current))
    return result


def profiles():
    output = nmcli('-t', '--escape', 'yes', '-f', 'NAME,UUID,TYPE,ACTIVE,STATE,DEVICE', 'connection', 'show')
    rows = []
    for line in output.splitlines():
        values = fields(line)
        if len(values) != 6 or values[2] != 'wireguard':
            continue
        name, ident, _kind, active, state, device = values
        rows.append(dict(name=name, uuid=ident, active=active == 'yes',
                         state=state, device=device))
    return sorted(rows, key=lambda row: (not row['active'], row['name'].casefold(), row['uuid']))


def run(args):
    operation = args[0] if args else 'list'
    if operation not in ('list', 'up', 'down', 'import'):
        raise ControlError('Неизвестная операция WireGuard')
    if operation == 'import':
        if len(args) != 2:
            raise ControlError('Выберите конфигурацию WireGuard')
        location = urlparse(args[1])
        if location.scheme != 'file' or location.netloc not in ('', 'localhost'):
            raise ControlError('Выберите локальный файл конфигурации WireGuard')
        path = Path(unquote(location.path))
        if not path.is_file() or path.suffix.lower() != '.conf':
            raise ControlError('Выберите файл WireGuard с расширением .conf')
        nmcli('connection', 'import', 'type', 'wireguard', 'file', str(path))
    elif operation != 'list':
        if len(args) != 2:
            raise ControlError('Не выбран профиль WireGuard')
        try:
            ident = str(uuid.UUID(args[1]))
        except ValueError:
            raise ControlError('Некорректный идентификатор профиля WireGuard') from None
        # Recheck on every action: stale UI must never operate on a different type.
        if not any(row['uuid'] == ident for row in profiles()):
            raise ControlError('Профиль WireGuard удалён. Обновите список')
        nmcli('connection', operation, 'uuid', ident)
    return {'profiles': profiles(), 'error': ''}


if __name__ == '__main__':
    try:
        payload = run(sys.argv[1:])
    except ControlError as error:
        payload = {'error': str(error)}
    print(json.dumps(payload, ensure_ascii=False))
