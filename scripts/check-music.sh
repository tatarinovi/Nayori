#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tests/lyrics-fetch.py
/usr/lib/qt6/bin/qmllint --missing-property disable -I /usr/lib/qt6/qml \
    services/island/MusicService.qml surfaces/island/{MusicCard,SyncedLyrics,AlbumBackdrop,IslandDashboard,MorphingIsland,DynamicIsland}.qml \
    CompactMusicSmoke.qml MusicServiceSmoke.qml MusicWidgetSmoke.qml PlayerStyleSmoke.qml
runtime=$(mktemp -d /tmp/nayori-music-check.XXXXXX)
trap 'rm -rf "$runtime"' EXIT
chmod 700 "$runtime"
export QS_DISABLE_FILE_WATCHER=1 XDG_RUNTIME_DIR="$runtime" QT_QPA_PLATFORM=offscreen QT_QPA_PLATFORMTHEME=basic QT_QUICK_BACKEND=software
for fixture in CompactMusicSmoke MusicServiceSmoke MusicWidgetSmoke PlayerStyleSmoke; do
    timeout 15s qs -p "$fixture.qml" --no-color > "$runtime/$fixture.log" 2>&1
    cat "$runtime/$fixture.log"
    ! rg -q 'Error:|Unable to assign|ReferenceError|TypeError|Failed to load configuration' "$runtime/$fixture.log"
done
rg -q COMPACT_MUSIC_PASS "$runtime/CompactMusicSmoke.log"
rg -q MUSIC_SERVICE_PASS "$runtime/MusicServiceSmoke.log"
rg -q MUSIC_WIDGET_PASS "$runtime/MusicWidgetSmoke.log"
rg -q PLAYER_SOURCE_AND_LYRICS_PASS "$runtime/PlayerStyleSmoke.log"
git diff --check
