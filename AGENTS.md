# The Usual — Godot

Use Godot 4.7.2 and typed GDScript. The authoritative simulation in `sim/` is
RefCounted data and fixed-tick logic; it must not depend on scene nodes,
physics, rendering, wall-clock time, input, or global random state.
The client submits typed commands and consumes detached snapshots. Outsider
private information is structurally absent from the household projection.
Player-facing prose lives in authored content. Read `pasm/spec/setting/setting-guide.yaml`
before writing it. Update PASM before or alongside structural changes, preserve
historical decisions, and mark agent-origin decisions with `origin: ai` or `[ai]`.
Never modify an unmarked decision without user authorization.

Run headless tests, GDScript formatting/lint checks, PASM validate and scan,
and Windows and Web exports before declaring completion. Preserve the Rust
baseline behavior; deferred roadmap systems are not part of this migration.
Restricted source art must never enter Git. Record asset provenance.
