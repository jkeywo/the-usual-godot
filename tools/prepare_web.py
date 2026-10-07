"""Prepare browser acceptance entry points and immutable game-pack URLs."""
import hashlib
import json
import re
from pathlib import Path

root = Path("build/web")
p = root / "index.html"
s = p.read_text()
pack = (root / "index.pck").read_bytes()
pack_name = "index-" + hashlib.sha256(pack).hexdigest()[:16] + ".pck"
(root / pack_name).write_bytes(pack)
match = re.search(r"const GODOT_CONFIG = (.*?);", s)
if match is None:
    raise RuntimeError("Exported Godot configuration not found")
config = json.loads(match.group(1))
config["mainPack"] = pack_name
config["fileSizes"] = {name: size for name, size in config["fileSizes"].items() if not name.endswith(".pck")}
config["fileSizes"][pack_name] = len(pack)
s = s[:match.start(1)] + json.dumps(config, separators=(",", ":")) + s[match.end(1):]
s = s.replace("engine.startGame({", "engine.startGame({args: new URLSearchParams(location.search).has('test') ? ['--', '--test-suite'] : [],")
p.write_text(s)
