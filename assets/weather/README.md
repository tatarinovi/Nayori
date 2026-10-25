# Weather artwork

Six local PNG backgrounds for the expanded dynamic island. `IslandDashboard.qml` selects them from the current wttr.in weather code; loading, error and unconfigured states have no illustration.

Generated with the built-in image generation tool. Original outputs remain in the Codex generated_images directory; these project copies require no remote image requests.

## Prompt set

Master (`clear.png`): restrained Japanese anime editorial landscape, graphite/lavender/dusty rose/cream palette, textured painted valley and mountains with a traditional rural house and path on the lower right, clear sky and cream sun, quiet space for foreground text, 3:2 landscape, no text or UI.

All variants use clear.png as the edit target, preserving camera, house, path, valley, mountains, painterly texture and palette. Change only weather and its natural lighting:

- `cloudy.png`: remove sun, thick soft graphite/lavender cloud cover, no precipitation.
- `rain.png`: fine slanted rain, wet path, no lightning.
- `snow.png`: cream snow on roof, path and landscape, gentle falling snow.
- `fog.png`: layered lavender mist veiling valley, mountains and house, no precipitation.
- `storm.png`: dark violet storm clouds, visible slanted rain, slender cream lightning fork in upper right replacing sun.

## Rendering

Art is cropped to the weather card, under a 72% graphite overlay. Small painted corner covers preserve rounded edges with both GPU and software rendering. City selection remains in Settings.

`WeatherSmoke.qml` loads all six conditions, checks image readiness and clears illustrations for missing/error data; it saves previews to `/tmp/nayori-weather-*.png`.
