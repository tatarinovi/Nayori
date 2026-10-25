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

The fox lies down below 5% aggregate CPU load, with breathing, blinking, occasional ear flicks, muzzle lifts and
tail movements separated by resting pauses, and runs at 5% or above. CPU is sampled once per second from
`/proc/stat`, excluding the guest counters already counted in user/nice.
Running cadence follows the measured load. `tokens.motion.off` replaces the
fox's movement with a static lying pose and disables content fades.

Volume or mute changes briefly replace the resting content for 1.8 seconds.
Initial audio synchronization does not create an event. Scrolling the capsule
adjusts volume; middle click toggles mute. Events keep the surface geometry
fixed and crossfade content using the existing fast motion token.

## Launcher

Right click on the dynamic island opens a menu with Launcher and Settings.
Choosing Launcher opens the application launcher with keyboard focus in search. Arrow keys select a result; Enter launches
it. Escape, clicking outside, or successful launch closes the surface. The host
is created lazily and released on closing so it returns keyboard focus to the
desktop. Middle click and volume scrolling on the dynamic island are preserved.
Search hides the favorites row so five results and the keyboard footer fit.

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
`AutoHideSmoke.qml` tests independent state, the close delay, held-open state,
and empty app availability without moving the pointer or activating windows.

## Source boundary

Halo's resting left/center/right arrangement, fixed layer geometry, and
short-lived audio event are behavioral references. The implementation and lying idle artwork are original. The eight running
frames were supplied by the user and are stored unchanged in `assets/fox/`.
Their monochrome silhouettes are tinted with the text token during rendering.
No AngelOS or RunCat code, frames, or assets were copied.
See `ANGELOS_AUDIT.md` for the original reference audit and license decisions.

## Verification

Use the Qt 6 linter (`/usr/lib/qt6/bin/qmllint` on the target machine). The
unversioned `qmllint` can resolve to the older Qt 5 tool. Quickshell's dynamic
properties and generated layer-shell types still produce some tooling warnings.

An isolated smoke renderer is provided at `PanelSmoke.qml`:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=basic \
  timeout 7s qs -p ./PanelSmoke.qml --no-color
```

It checks CPU deltas, invalid-sample handling, seconds in the clock, panel and
event geometry, popup lifecycle, and available tray submenu lifetimes. It reads
live service models and never activates application actions, changes volume,
or connects/disconnects networks. It writes previews to `/tmp/nayori-*.png`.
Look for `PANEL_SMOKE_PASS`; the timeout's exit code 124 is expected. Native
layer-shell placement and pointer grabs still require a Wayland session; the
offscreen backend does not implement window masks.

`MorphSmoke.qml` checks intermediate dimensions, full expansion/collapse, and
immediate transitions when animations are disabled, and renders preview states.
