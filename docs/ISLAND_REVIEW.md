# Dynamic island interface review

## Scope and coverage

The compact header, expanded Home page, context menu, and morphing wrapper were reviewed as one desktop surface. Implementation is Qt Quick/QML with Quickshell, native MPRIS, Inter/Literata, and the existing graphite/lavender/cream/rose tokens. Project references: `docs/PANEL.md`, `docs/ARCHITECTURE.md`, and `tokens/Tokens.qml`. This is a screen/style review and implementation, not a review of the repository's uncommitted diff.

Supported geometry inspected: 352 × 48 compact, 680 × 490 expanded wrapper, 680 × 450 dashboard. A 320 px mobile viewport and browser zoom are outside this desktop layer surface's current layout contract. No responsive/mobile coverage is claimed.

| Domain | Evidence inspected | Result |
| --- | --- | --- |
| Accessibility | Dashboard actions, accessible names, focus borders, calendar selected day, source of compact/context interactions | Fixed focus treatment and selected-day redundancy; native keyboard/screen-reader walk not verified |
| Layout | Expanded offscreen image and layout source; header dimensions/morph smoke | Fixed calendar footer overflow, section alignment and hierarchy |
| Writing | All dashboard empty, fetching, error, weather settings and navigation strings | Short neutral actions and recoverable weather errors retained; no invented data |
| Typography | Inter/Literata tokens, rendered Home/music/calendar headings, caption and numeric sizes | Fixed serif/sans hierarchy; 12–13 px captions except secondary provider attribution at 11 px |
| Colors | Existing tokens and calculated rendered pairs, image-overlay worst case | Required dashboard text pairs pass 4.5:1 |
| UI | Music/weather/calendar surfaces, outlined controls, hover/focus/disabled source, morph smoke | Consistent restrained editorial composition; existing header motion contract retained |

## Findings addressed

| Severity | Domain | Location | Before | After | Why |
| --- | --- | --- | --- | --- | --- |
| MEDIUM | Layout | `surfaces/island/IslandDashboard.qml:122` | Three similar rounded utility cards with competing labels | Music and illustrated weather form one column; calendar sits on an open editorial column | Clear grouping and deliberate hierarchy support quick scanning |
| MEDIUM | Typography | `surfaces/island/IslandDashboard.qml:87` | Serif used primarily on Home; calendar and track metadata had nearly equal weight | Literata identifies Home, track title and month; Inter carries controls and metadata | One consistent display/body relationship preserves Nayori's literary character |
| MEDIUM | Accessibility | `surfaces/island/IslandDashboard.qml:93` | A 1 px keyboard focus border | A 2 px accent perimeter on native abstract buttons | Visible keyboard focus is distinct from ordinary outlined controls |
| MEDIUM | Accessibility | `surfaces/island/IslandDashboard.qml:266` | Today indicated by lavender fill alone | Today also has bold underlined date text | Current-day status survives color differences |
| MEDIUM | Layout | `surfaces/island/IslandDashboard.qml:248` | Calendar footer overflowed at the fixed dashboard height during the first revised render | 26 px day rows with 3 px gaps; complete footer is visible | Today action remains reachable at the supported expanded geometry |
| LOW | Writing | `surfaces/island/IslandDashboard.qml:218` | Empty weather button named its settings area | “Выбрать город” names the next user action | Empty state gives a clear path forward |

## Verification

Passed:

- Six local weather illustrations integrated and visually inspected in the card: clear, cloudy, rain, snow, storm and fog. `tests/smoke/WeatherSmoke.qml` reports `WEATHER_ARTWORK_PASS`, verifies all six images load, and verifies empty/error conditions clear the source. Rounded corners also render in the software backend.
- Running Nayori reloaded the updated configuration successfully.

- `/usr/lib/qt6/bin/qmllint surfaces/island/IslandDashboard.qml` exits 0, without diagnostics.
- `QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QPA_PLATFORMTHEME=basic XDG_RUNTIME_DIR=/tmp/nayori-dashboard-runtime timeout 2s quickshell -p ./tests/smoke/MorphSmoke.qml --no-color` reports `MORPH_ISLAND_PASS`. Timeout 124 is expected.
- Expanded screenshot `/tmp/nayori-morph-expanded.png` visually inspected: complete calendar footer, no overlap between music/weather/calendar, consistent insets and heading hierarchy. Intermediate morph and reduced-motion geometry assertions pass.
- Color calculation from sRGB tokens: cream text on music card 13.12:1; muted text 10.15:1. With a completely white weather-image pixel under the 72% graphite overlay, cream is at least 6.21:1 and muted text at least 4.80:1. Current-day dark text on lavender is 9.15:1.

Not verified:

- Native Wayland hover/grab/keyboard focus and screen-reader announcement. Offscreen backend cannot represent the session's pointer behavior.
- Live MPRIS action dispatch and network weather fetching. The isolated runtime cannot connect to the session’s D-Bus/PipeWire; weather tests inject conditions without making network requests.
- Long real-world media titles and arbitrary-width desktop layouts beyond the fixed surface contract.

## Remaining observations

The context and wrapper preserve the existing equal header gaps, central fox, edge-following clock/date, right-click menu, hover expansion, and no close button. Changes to that interaction contract were excluded from this dashboard polish. Full native interaction acceptance should be completed in the running shell. No unverified behavior is marked as passing.

## Verdict

Approve the dashboard's inspected desktop style/layout scope. Native input and assistive-technology coverage remain explicitly unverified.
