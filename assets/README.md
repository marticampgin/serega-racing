# Personalized assets

- Put private original photos in `assets/source/friends/`; this folder is ignored by Git.
- Approved game-ready derivatives live in `assets/generated/friends/` and are committed.
- Use descriptive filenames for future additions so placement rules stay readable.

The current portraits use a recognizable low-poly arcade-racing treatment and appear as trackside billboards. The third portrait is also prepared for the finish celebration UI.

## Course maps

- `generated/maps/synthwave-course-map-v1.png` is the approved-style world-map
  concept used to guide the map-driven track rebuild.
- The original route sketch is kept at `tools/map template.png` so geometry can
  always be checked against the user's source rather than inferred from artwork.
- Route order and implementation constraints are documented in
  `docs/course-map.md`.
