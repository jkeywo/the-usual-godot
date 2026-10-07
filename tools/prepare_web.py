from pathlib import Path
p = Path("build/web/index.html")
s = p.read_text()
s = s.replace("engine.startGame({", "engine.startGame({args: new URLSearchParams(location.search).has('test') ? ['--', '--test-suite'] : [],")
p.write_text(s)
