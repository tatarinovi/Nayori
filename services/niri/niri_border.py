#!/usr/bin/env python3
"""Manage an opt-in Niri focus-ring fragment with rollback on invalid config."""
import argparse
import importlib.util
import json
import re
import shutil
import sys
from pathlib import Path

spec = importlib.util.spec_from_file_location('accent', Path(__file__).with_name('niri_accent.py'))
accent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(accent)
NAME = 'nayori-window-border.kdl'
MARKER = '// Managed by Nayori window borders'
INCLUDE = 'include "' + NAME + '" // Nayori window borders\n'


def apply(config, enabled, first, second, width):
    config = Path(config).resolve()
    fragment = config.parent / NAME
    if not config.is_file() or config.name == accent.NOCTALIA_NAME or not accent.inside(config.parent, fragment):
        raise ValueError('Недоступна конфигурация Niri')
    text = accent.read_text(config)
    original_fragment = accent.read_text(fragment) if fragment.exists() else None
    if original_fragment is not None and not original_fragment.startswith(MARKER + '\n'):
        raise ValueError('Фрагмент рамки уже существует и не принадлежит Nayori')
    if enabled:
        if not all(re.fullmatch(r'#[0-9A-Fa-f]{6}', c) for c in (first, second)) or not 1 <= width <= 12:
            raise ValueError('Некорректные параметры рамки')
        # Restrict ourselves to a unique, owned include. An unrelated include must not be removed.
        parser = accent.Parser(text)
        parser.apply('000000')
        if any(accent.include_name(s['spec']) == NAME for s in parser.include_spans) and INCLUDE not in text:
            raise ValueError('Фрагмент рамки уже подключён вручную')
        new_text = text if INCLUDE in text else text + ('' if not text or text.endswith('\n') else '\n') + INCLUDE
        new_fragment = (MARKER + '\nlayout {\n    focus-ring {\n        width ' + str(width) +
                        '\n        active-gradient from="' + first + '" to="' + second + '" angle=45\n    }\n}\n')
    else:
        if INCLUDE not in text and original_fragment is None:
            return False
        new_text = text.replace(INCLUDE, '')
        new_fragment = None
    if text == new_text and original_fragment == new_fragment:
        return False
    # Back up existing content before replacing it. Files are written atomically.
    shutil.copy2(config, str(config) + '.nayori-border.bak')
    if original_fragment is not None:
        shutil.copy2(fragment, str(fragment) + '.bak')
    try:
        if new_fragment is not None:
            accent.atomic_write(fragment, new_fragment)
        if new_text != text:
            accent.atomic_write(config, new_text)
        if not accent.validate(config):
            raise ValueError('Niri отклонил конфигурацию рамки')
        if new_fragment is None and fragment.exists():
            fragment.unlink()
    except (OSError, ValueError):
        if new_text != text:
            accent.atomic_write(config, text)
        if original_fragment is None:
            if fragment.exists():
                fragment.unlink()
        else:
            accent.atomic_write(fragment, original_fragment)
        raise
    return True


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--config', required=True)
    p.add_argument('--enabled', choices=('on', 'off'), required=True)
    p.add_argument('--first', default='#C0AFD1')
    p.add_argument('--second', default='#CAA7AA')
    p.add_argument('--width', type=int, default=3)
    args = p.parse_args()
    try:
        changed = apply(args.config, args.enabled == 'on', args.first, args.second, args.width)
        print(json.dumps({'ok': True, 'changed': changed}))
    except (OSError, ValueError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False))
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(main())
