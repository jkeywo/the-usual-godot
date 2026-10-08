# Migration record

Source: https://github.com/jkeywo/the-usual
Baseline: 56950edb09ea0eeb63d9495556600ae91f410473
Engine: Godot 4.7.2 (standard build), Windows and single-threaded Web.

The user authorized a complete GDScript rewrite, fresh repository history,
a household dashboard, fresh saves, and replacement of restricted artwork.
Historical PASM decisions remain preserved; migration decisions supersede
technology-specific choices for this repository only.

The acceptance suite maps all 84 baseline simulation behavior tests, compares
three independent Rust event traces and eight authoritative state checkpoints,
and checks unsigned mixer vectors. The state comparisons include positions,
needs, navigation paths, plans, active uses, stocks, claims and pending events.
There are 540 simulation checks and 60 client checks, including 75 save/resume
checkpoints for movement, contention, cooking, urgent preemption and initiatives.
An additional independent matrix runs autonomous and scripted scenarios for 600
ticks at each of six seeds (0, 1, 42, 4243, i64::MAX and u64::MAX). All twelve
full event traces and 300 normalized authoritative checkpoints match the Rust
baseline. Normalization covers plans, queues, movement, uses, claims, needs,
stocks, social state and pending events. These are finite regression scenarios,
not a proof of equivalence for every possible playthrough.

The reproducible Rust exporter is `tools/reference_matrix.rs`; append it to the
baseline's simulation tests in an isolated checkout, run `cargo test -p village_sim export_godot_matrix`
with `GODOT_FIXTURES` set to this port's `.reference/matrix` directory, then normalize with
`tools/normalize_matrix.py`. The committed fixtures require no Rust toolchain.
New queue-management behavior has dedicated GDScript semantic tests because the
baseline did not implement these commands.

The same suite runs headlessly and in the browser export. CI verifies browser
persistence after reload and audio after a real user gesture, captures wide and narrow screenshots, and runs the
exported executable on Windows before deploying GitHub Pages. Every release is
built with the pinned editor and matching SHA512-verified templates.

## Godot architecture checks

The pinned PASM scanner supports Rust and JavaScript symbols, but does not yet
index GDScript. PASM validation and scan remain required. The additional
`tools/check_architecture.py` gate resolves Godot implementation mappings and
rejects simulation-to-client dependencies, nondeterministic engine access, and
client access to mutable simulation state. This does not modify vellum.

The initial port keeps the simulation's phase methods together to permit direct
comparison with the Rust baseline. GDScript lint limits explicitly accommodate
that parity boundary; extraction can follow once behavior is established.

## Completed client gaps

The simulation fills the window behind a floating, responsive HUD. Orders expose
Next (promote behind current work), Do now (interrupt and preserve current work),
Up/Down (reorder waiting jobs) and Cancel. Urgent needs still outrank forced player
work. Receipts distinguish pending, accepted and rejected operations, with reasons;
waiting and cancellation messages describe what happened. Doors and stairs expose
their authored crossing actions. Selecting an outsider clears household details.

Client-only walk, work, rest and idle poses accompany original synthesized effect
cues and quiet ambience. Sound starts after a user gesture and can be muted.
`tools/generate_presentation.py` reproduces the original media; provenance is in
`assets/PROVENANCE.md`. New saves use version 2 and retain version 1 read support.
Malformed state, integrity failures and content mismatches leave the world intact.

The roadmap's deferred systems, including a household economy, remain outside
this migration. No new economic mechanics were added while closing client gaps.


## Modular runtime animation

All four authored residents now use separate head and clothing/body atlases.
Each outfit has eight-direction walks (eight frames), conversation gestures
(six frames), and generic interaction loops (six frames), alongside idle,
seated and sleeping poses. Cells are 48 by 80 logical pixels; head and body use
one shared collar attachment coordinate. Clothing variants reuse
frame order and retain the separate character identity. The client chooses
frames, facing and clothes; it never alters authoritative simulation state.

Snapshots expose only the position of an object currently being used as
`activity_target`, detached from the world. This permits visible face-to-face
conversation gestures without revealing an outsider's needs or future plans.
Outfit choices are cosmetic client state and are not stored in simulation saves.
The Menu switches a selected resident between the original and navy outfit.

The rejected procedural SVG character artwork is replaced with generated raster art
based directly on C — Observational Pixels. See `art/README.md` for prompts,
provenance and optional technical reimport. Shipped PNGs need no generator.
`tests/animation_gallery.gd` renders every current resident and direction;
`tests/animation_tests.gd` checks assets, distinct poses, head compatibility,
facing, conversation, detached targets and the simulation boundary.

Camera follow uses the rendered interpolated position each frame. Manual portal
orders switch the selected resident's view on arrival even when follow is off,
and an occupied stair tile retains its crossing menu. `tests/camera_portal_tests.gd`
checks both floor directions and fractional-tick follow without sim mutations.

## Pixel life HUD

The Sims 3 inspired arrangement uses original blue-grey pixel panels and green
highlights. Household portraits sit beside the lower-left time dock; a selected
portrait and tabbed Needs, Orders and On their mind panel span the lower edge.
Accepted orders remain visible in the upper-left queue with cancellation buttons.
Authored interactions appear in bubbles around a clicked target, or in a compact
list on narrow screens. Menu contains saving, loading, clothing and sound controls.
The village continues to fill the viewport under every panel.

`HouseholdHud` owns construction and responsive placement; `InteractionMenu` owns
context layout and delegates action submission to the existing typed command path.
Thirteen HUD checks cover tabs, screen bounds, queue cancellation, retained controls
and the simulation boundary, bringing client acceptance to 73 checks.
