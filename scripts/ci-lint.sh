#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ruff check scripts services tests
# Start with correctness diagnostics; legacy style is not reformatted by CI.
shellcheck --severity=error scripts/*.sh scripts/nayori-settings
while IFS= read -r -d '' script; do
    bash -n "$script"
done < <(git ls-files -z -- '*.sh' scripts/nayori-settings)

mapfile -d '' qml_files < <(git ls-files -z -- '*.qml')
# Quickshell qmltypes omit dynamic properties and mark some factories uncreatable.
/usr/lib/qt6/bin/qmllint --missing-property disable --uncreatable-type disable \
    -I /usr/lib/qt6/qml "${qml_files[@]}"

# Ignore QML's .pragma/.import directives when checking embedded JS syntax.
python3 - <<'PY'
import pathlib
import re
import subprocess

paths = subprocess.check_output(['git', 'ls-files', '-z', '--', '*.js', '*.cjs']).decode().split('\0')
for name in filter(None, paths):
    source = pathlib.Path(name).read_text()
    source = re.sub(r'^\s*\.(?:pragma|import)\b[^\n]*', '', source, flags=re.MULTILINE)
    subprocess.run(['node', '--check'], input=source, text=True, check=True)
PY

git diff --check
