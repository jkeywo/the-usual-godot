"""Supplement pinned PASM's Rust/JS scanner with Godot path/boundary checks."""
from pathlib import Path
import json
import re
import yaml

root = Path(__file__).resolve().parents[1]
errors = []
entities = []
for source in (root / "pasm/spec").rglob("*.yaml"):
    for entity in yaml.safe_load(source.read_text(encoding="utf-8"))["entities"]:
        implementation = entity.get("implementation", {})
        paths = implementation.get("paths", [])
        if not paths:
            continue
        files = []
        for name in paths:
            path = root / name
            if not path.exists():
                errors.append(f"Missing mapping: {name}")
            elif path.is_dir():
                files.extend(str(f.relative_to(root)) for f in path.rglob("*") if f.is_file())
            else:
                files.append(name)
        entities.append({"entity": next(v for k, v in entity.items() if k not in ("core", "implementation")),
                         "files": sorted(set(files))})
for path in (root / "sim").glob("*.gd"):
    source = path.read_text()
    if "res://client/" in source or re.search(r"extends\s+(Node\w*|Control|SceneTree)", source):
        errors.append(f"Presentation dependency in {path.name}")
    if path.name in ("simulation.gd", "keyed_draw.gd") and re.search(r"\b(Input|Time|Engine|randf|randi|randomize)\b", source):
        errors.append(f"Nondeterministic engine dependency in {path.name}")
for path in (root / "client").glob("*.gd"):
    if "simulation.state" in path.read_text():
        errors.append(f"Client bypasses snapshot boundary in {path.name}")
print(json.dumps({"entities": entities, "errors": errors, "ok": not errors}, indent=2))
raise SystemExit(bool(errors))
