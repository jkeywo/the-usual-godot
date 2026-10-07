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
There are 205 simulation checks and 19 client checks, including 75 save/resume
checkpoints for movement, contention, cooking, urgent preemption and initiatives.

The same suite runs headlessly and in the browser export. CI verifies browser
persistence after reload, captures wide and narrow screenshots, and runs the
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
