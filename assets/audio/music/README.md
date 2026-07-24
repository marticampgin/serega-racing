# Local music

The personal music files are kept out of Git, but Godot imports and packs the
local copies into personal builds:

- `menu_slow.mp3` — looping main-menu track.
- `race_01.mp3` through `race_20.mp3` — shuffled for every non-Cadillac race.
- `cadillac.mp3` — the Cadillac-exclusive looping track.

During a race, `P` advances to the next song and `O` returns to the previous
song. The Cadillac always keeps its exclusive track.
