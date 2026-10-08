# Observational Pixels runtime artwork

Generated with the built-in imagegen tool, 8 October 2026. The visual reference
was this project's C — Observational Pixels board: Rowan's short brown hair and
sage cardigan, Mara's auburn bob and ochre cardigan, substantial adult silhouettes,
realistic clothing folds, earthy pixel clusters and brown shoes. No external art
packs or artist-name style prompts were used.

## Prompt set

- Headless garment study: eight columns × twelve rows, sage cardigan, cream shirt,
  charcoal trousers. E/SE/S/SW/W/NW/N/NE views, followed by six front and rear talking
  gestures and six front and rear generic interactions. Actual transparent background,
  generous cell spacing, no labels, no shadows, a constant collar socket.
- Targeted extraction: preserve all sprites and layout; remove the coloured backdrop
  to actual zero-alpha space, with opaque sprites.
- Improved walk atlas: eight columns × eight directions. Left contact, down,
  right passing, right raised knee, opposite contact/down/passing/raised knee.
  Clearly alternate spread-leg contact and legs-together passing silhouettes, with
  opposing arm swing. Match the C board's knit folds and grounded adult proportions.
- Exact garment edits on both atlases: warm ochre; muted plum for Gerald; brick rust
  for Sylvia; navy over burgundy with tan corduroy trousers. Preserve poses and sockets.
- Head atlas: four columns × eight direction rows. Rowan and Mara retain their C
  identities; Gerald has receding silver hair and a grey moustache; Sylvia has grey
  hair in a bun. Heads with necks only, realistic warm faces, no shoulders or backdrop.

- Seated atlas: five outfits × eight directions, upright torso, bent knees,
  hands on lap, no chairs or heads, keeping the same observational pixel style.

- Expression edits: preserve each neutral head and socket, changing only eyes
  to closed for blink/sleep, or mouths to slightly open for speaking.

## Files and import

The generated source boards are retained locally in `art/source/` (hashes in
`source-hashes.json`); they are excluded from Godot scanning and exports. The compact
runtime PNGs in `assets/characters/` are checked in and can be edited directly.

Optional reimport with the original boards present:

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tools/import_character_atlases.gd
```

The technical importer performs alpha cutoff, trimming, collar registration and
nearest sampling. It never paints features, substitutes procedural silhouettes or
changes palettes. Runtime cells remain 48×80, preserving tile footprints and
integer world scaling. Clothing does not select a head. Front/rear gesture views
are mirrored for opposite facings. Animation time and outfit choices are client-only.

The rejected SVG generator and character atlases have been retired. Their earlier
AI-origin PASM rationale is explicitly superseded by this raster workflow.
