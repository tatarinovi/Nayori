#!/usr/bin/env bash
# Bootstrap only. Package transactions are never run without an explicit answer.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly_mode=0
for arg in "$@"; do
    case "$arg" in
        --dry-run|--diagnose|--help|-h) readonly_mode=1 ;;
        *) printf 'Неизвестный аргумент: %s\n' "$arg" >&2; exit 2 ;;
    esac
done
case "${1:-}" in
    --help|-h)
        printf '%s\n' 'Nayori — установщик Arch/CachyOS' \
            './install.sh [--dry-run | --diagnose]' \
            'Установка начинается только после проверки плана в TUI.'
        exit 0 ;;
esac
[[ $(uname -s) == Linux ]] || { echo 'Поддерживается только Linux.' >&2; exit 1; }
(( EUID != 0 )) || { echo 'Запустите без sudo: права запрашиваются для отдельных операций.' >&2; exit 1; }
if ! command -v pacman >/dev/null; then
    echo 'Требуется Arch/CachyOS с pacman.' >&2; exit 1
fi
[[ -t 0 && -t 1 && ${TERM:-dumb} != dumb ]] || {
    echo 'Нужен интерактивный терминал.' >&2; exit 1;
}
if ! command -v python3 >/dev/null || ! python3 -c 'import textual' 2>/dev/null; then
    if (( readonly_mode )); then
        echo 'Нужны python и python-textual. В режиме просмотра bootstrap отключён.' >&2
        exit 1
    fi
    printf '%s\n' 'Для интерфейса нужны python и python-textual из репозитория pacman.' \
        'Системный pip не используется. Обновление баз отдельно не выполняется.'
    read -r -p 'Установить через sudo pacman -S --needed python python-textual? [y/N] ' answer
    case "$answer" in y|Y|yes|да) sudo pacman -S --needed python python-textual ;; *) exit 0 ;; esac
fi
exec python3 "$root/scripts/installer/ui.py" "$@"
