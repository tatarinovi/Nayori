# Panel and dynamic island

The side islands use 48 px height and 32 px controls; the central application
island uses 56 px height and 40 px controls. All use 8 px outer padding, and Nayori's graphite/lavender/rose tokens. There are no new theme,
font, icon-pack, or shell dependencies.

- Workspaces use markers without visible numbers or hover tooltips: an elongated
  lavender bar for the current workspace, filled dots for occupied workspaces,
  hollow dots for empty ones, and rose for urgent workspaces. Accessible names
  retain workspace details. Pointer, keyboard, and bounded wheel navigation are
  supported.
- The central dock hides when the current workspace has no windows and returns
  automatically when a window appears. Its layer window is hidden as well.
- Applications support pointer and keyboard activation, focus outlines, and
  hover feedback. Application icons are 26 px inside 40 px controls.
- Application and status hints share `islands/shared/PanelTooltip.qml`: a
  separate non-interactive surface above the control, delayed by 450 ms,
  limited to 300 px and three lines, using Nayori tokens throughout.
- The status island contains a tray disclosure, network, and sound. The clock
  lives in the upper dynamic island.
- The tray grid preserves left/middle/right activation and scrolling. Its menus
  use the same Nayori controls. Each submenu retains its own `QsMenuOpener`;
  navigating back releases only that level. Escape goes back one level, then
  closes the popup. Closing releases all menu handles.
- Network connections use Quickshell.Networking directly. Wi-Fi scans run only
  while the network popup is open. Existing profiles and supported personal
  Wi-Fi networks can connect; new enterprise connections require a separately
  provisioned NetworkManager profile. Password input is cleared after use and
  on closing the popup.
- Sound provides output selection, a 0–100% slider, and mute. Scrolling the
  sound button adjusts the level in 5% steps; middle click toggles mute.
  PipeWire's default sink is tracked so external changes update both surfaces.

## Dynamic island

The layer surface stays 712 × 522. The visible capsule is 352 × 48 at rest
and morphs into a 680 × 490 body on hover, keeping the clock, fox, and date
visible in its top row. The clock and date follow the expanding edges while
the fox stays centered. Width, height, radius, and colour share one 280 ms
progress animation; the dashboard appears inside the same clipped body.
At rest it shows `HH:mm:ss` on the left, an animated fox in the
center, and the date on the right. While an MPRIS player is playing, its track
title replaces the date in a clipped right-hand slot. Overflowing titles scroll
at 28 px/s with a one-second reading pause; short titles stay still. Track changes
and resizing restart the scroll, and inactive/volume states stop it. Track text is always rendered in full and clipped by the slot, including during
the reading pause; disabling animations leaves it stationary without ellipsis.
In the expanded island, fitting titles and the date are centered in the right section. Pausing restores the date. The dashboard's music card
keeps title and artist on single elided lines and reserves room for playback controls.
There is no hover tooltip or manual pause control.

The fox is a pixel-art kitsune drawn in code (`surfaces/island/FoxSprite.js`
rasterises a 52 × 30 frame by pixel centres; `Fox.qml` paints the cells as whole
squares without smoothing). It has pointed ears with dark tips, a long muzzle with a
dark nose, a slanted eye, one big S-curved bucket tail with a light tip, a cream
bib and cheeks, a darker belly, and darker socks. Colours come only from tokens, and
the fur is the muted accent rather than pink: `accentSoft` lightened by 1.45 (body,
ears, tail, near legs), lightened by 1.12 (belly and far legs), `accentSoft` itself
(socks, ear tips, nose), `text` (chest, cheeks, tail tip) and `background` (eye). The
unread marker is the `accent` dot with a 1px `text` ring so it never merges with the
fur. One-pixel gaps between
overlapping parts replace outlines. The whole sprite, including the tail at both extremes of its sway, stays inside the 52 × 30
grid with the leftmost column free (`FoxSprite.measure()` reports the unclipped bounds and
`tests/island-controller.cjs` checks every pose); the rump sits a few pixels in from the
left edge to leave room for the tail.
While the island is expanded the head and eye follow the cursor anywhere inside the island
(also when lying), clamped and smoothed; collapsed, only hovering the fox turns the head.
It lies down only
when there is no activity: no music with available audio and smoothed CPU load at
or below 5%. As soon as activity appears it stands up (about 0.45 s) and walks in
place; the stride rate and tail sweep follow the same CPU or music-energy
frequency as before, and the two diagonal pairs of legs step in antiphase. With
the pointer over an active fox it stops, stands, and its head and eye follow the
pointer while the tail sways calmly. Lying down is delayed until activity has been
absent for 5 continuous seconds (`REST_DELAY` in `services/island/Behavior.js`), so
a load hovering around the threshold does not make it flicker. It always breathes;
the tail follows the CPU or music frequency. Hidden island
and reduced motion show the static lying pose (the unread marker remains). CPU is sampled once per second from
`/proc/stat`, excluding the guest counters already counted in user/nice.
Running cadence follows the measured load. `tokens.motion.off` replaces the
fox's movement with a static lying pose and disables content fades.

Volume or mute changes briefly replace the resting content for 1.8 seconds.
Initial audio synchronization does not create an event. Scrolling the capsule
adjusts volume; middle click toggles mute. Events keep the surface geometry
fixed and crossfade content using the existing fast motion token.

## Launcher

Alt+Space (`qs ipc call launcher toggle`), the island's right-click menu, or the IPC
`launcher` target open the launcher on the output that invoked it. The island capsule
morphs into the search row (640 px wide, 48 px tall); results live in a separate
card 8 px below it, 24 px narrower on each side. If the second-monitor island is
hidden in Settings the launcher opens on the first output, which is the only one
with an island.

- The row has a large magnifier, a blinking lavender caret, the placeholder
  “Найти приложения, файлы, команды…” and a `Alt` `Space` keycap hint showing how the launcher
  opens (`openShortcut` in `Launcher.qml`; the binding itself lives in the niri config).
  Ctrl+K is an unadvertised extra: it returns input to the field and selects the whole
  query so the next keystroke replaces it (any layout: the scan code is checked).
- Rows (`LauncherRow.qml`) show icon, name, a smaller muted description and an
  action mark: ↵ on the selected row, → on the others. The selected row gets a
  rounded `surfaceAlt` plate; thin dividers separate rows and disappear next to the
  selected one. “Поиск в интернете” is the last row and opens a Google query in the
  default browser. All colors, radii, fonts and motion come from tokens; the
  frosted material is translucent graphite, solid mode uses the dark background.
- Arrow keys select, Enter launches, Escape or a click outside closes. Hovering a row
  selects it only when the pointer actually moves.
- Only desktop applications and the web row are searched; there is no file or
  command index yet, although the placeholder text mentions them.

Keyboard focus: the island window requests `WlrKeyboardFocus.Exclusive` while the
launcher is open and keeps `focusable: true` constant. Toggling `focusable` together
with `keyboardFocus` made Quickshell send `OnDemand` instead, and niri then gave focus
only after the pointer hovered the window (`focus-follows-mouse`). `Launcher.focusInput()`
still waits for the layer surface to become active before `forceActiveFocus()`.
Closing drops the request, so the keyboard returns to the previous window.
`python3 tests/launcher-focus.py` guards this statically;
`NAYORI_NESTED_NIRI=1 python3 tests/launcher-focus.py` repeats open/close three times in
a nested niri (separate runtime dir and D-Bus) and checks `wl_keyboard.enter/leave`.

## Expanded island and settings

Hovering over the island for 400 ms expands its Home dashboard: a live MPRIS player,
a browsable month calendar, and weather for a city chosen in Settings → Weather.
The body stays expanded under the pointer and collapses 600 ms after leaving.
Right click retains its context menu. The expanded body uses on-demand
keyboard focus so hovering does not take input away from an app. There is no
separate expanded window or close icon.
No location is inferred. Weather uses `curl` and wttr.in only when a configured
city is present. A shell-owned WeatherService refreshes it in the background at the configured interval (15 minutes by default). All outputs share its cached result; opening or closing the dashboard does not start or stop weather requests.

Settings opens on Home with the login name and AccountsService avatar (or a
monogram fallback). The Panels page controls upper/lower reserved space and
four independent auto-hide switches: top island, app dock, workspaces, status.
Each connected output has its own dynamic island, bottom panels, edge triggers,
and reserved space. Workspace and application lists follow that output's active
workspace. Launcher opens on the output that invoked it. Settings is an independent compositor-managed window; Niri controls its output and placement. Hover,
expansion, and auto-hide state are independent per output; connecting or removing
an output adds or removes its surfaces automatically.
The Panels page also has “Скрыть Dynamic Island на втором мониторе”: it fully
hides the island and its top edge trigger on outputs other than the first screen,
including its upper reservation, while keeping their bottom panels available.
The switch is off by default and persists with the other panel preferences in settings.json.

Appearance controls animations; Weather controls the city. These preferences
currently live for the shell session.

Reservations are separate transparent layer-shell surfaces. Visible panels use
`ExclusionMode.Ignore` without assigning `exclusiveZone`, whose setter would
otherwise change their mode. Reservations therefore constrain Niri windows
while the visible bars stay at the physical screen edges.

Auto-hide is evaluated against each island separately using window rectangles
on the active workspace. Clear areas and empty workspaces keep their islands
visible. Niri26.04 currently omits viewport coordinates for tiled windows; the
user-selected fallback for unknown geometry is ordinary auto-hide. No window
positions are guessed. Empty application docks remain hidden. Layout events
update the known rectangles without polling.

Each hidden island has its own two-pixel input strip at the corresponding
physical edge. Entering a strip reveals only that island. A 650 ms close delay
bridges the gap between the edge and panel; open menus and the expanded island
hold their owner visible. Reveal and hide use a 140 ms opacity transition with
a strong ease-out, interrupted from the current value. No reveal animation runs
on initial loading; disabling animations makes the transition immediate. An
empty app dock stays hidden even on edge hover.
`tests/smoke/AutoHideSmoke.qml` tests independent state, the close delay, held-open state,
and empty app availability without moving the pointer or activating windows.

## Source boundary

Halo's resting left/center/right arrangement, fixed layer geometry, and
short-lived audio event are behavioral references. The implementation and the
kitsune fox artwork are original. The fox is drawn in code
(`surfaces/island/Fox.qml`, Bézier and polygon paths on a `Canvas`) in the
text, background, and accent tokens; it uses no image files. No AngelOS or
RunCat code, frames, or assets were copied.
See `ANGELOS_AUDIT.md` for the original reference audit and license decisions.

## Verification

Use the Qt 6 linter (`/usr/lib/qt6/bin/qmllint` on the target machine). The
unversioned `qmllint` can resolve to the older Qt 5 tool. Quickshell's dynamic
properties and generated layer-shell types still produce some tooling warnings.

An isolated smoke renderer is provided at `tests/smoke/PanelSmoke.qml`:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=basic \
  timeout 7s qs -p ./tests/smoke/PanelSmoke.qml --no-color
```

It checks CPU deltas, invalid-sample handling, seconds in the clock, panel and
event geometry, popup lifecycle, and available tray submenu lifetimes. It reads
live service models and never activates application actions, changes volume,
or connects/disconnects networks. It writes previews to `/tmp/nayori-*.png`.
Look for `PANEL_SMOKE_PASS`; the timeout's exit code 124 is expected. Native
layer-shell placement and pointer grabs still require a Wayland session; the
offscreen backend does not implement window masks.

`tests/smoke/MorphSmoke.qml` checks intermediate dimensions, full expansion/collapse, and
immediate transitions when animations are disabled, and renders preview states.

## Меню «Пуск»

Короткое одиночное нажатие левой или правой Super переключает меню. Меню одно на все
мониторы: если оно уже открыто, тап (и `start toggle`) закрывает именно его, где бы ни был
активный монитор niri; если закрыто — открывает на активном мониторе
(`services/ui/StartRouting.js`, проверяет `tests/start-routing.cjs`). Открытие кнопкой на
другом мониторе закрывает меню на первом. Удержание дольше 400 мс, другие клавиши, клики и
прокрутка колесом отменяют срабатывание; одно лишь движение мыши — нет. `SuperTap` читает
evdev без захвата устройств и не записывает ввод; нужны `python-evdev` и доступ к
`/dev/input/event*`. В неактивной или заблокированной сессии меню по Super не открывается.
Одна клавиша, пришедшая через несколько интерфейсов (провод и донгл, boot и NKRO),
считается одним нажатием; потерянное отпускание сбрасывается по состоянию ядра не позже
чем через секунду простоя.

Для внешних команд доступно переключение через IPC:

```sh
qs ipc -p /home/katamy/Projects/nayori call start toggle
```

Появление и скрытие используют прозрачность и раскрытие области снизу вверх.
Область системного блюра меняет высоту синхронно с видимой частью меню,
до нулевой высоты при закрытии. Длительность берётся из `tokens.motion.base`; отключение анимаций в
настройках действует и здесь. Меню рисуется в одном окне слоя Overlay до конца
затухания. Клик снаружи запускает закрытие; фокус клавиатуры и область ввода
освобождаются сразу, без подмены окна снимком.

`tests/smoke/StartMenuSmoke.qml` проверяет отрисовку, навигацию, прерывание закрытия,
мгновенный режим и завершение затухания после внешнего закрытия.
`python3 tests/super-tap.py` проверяет распознавание нажатий без доступа к устройствам.
