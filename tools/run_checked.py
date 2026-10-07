"""Fail on Godot script errors as well as nonzero process exit status."""
import subprocess
import sys

result = subprocess.run(sys.argv[1:], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        timeout=240)
print(result.stdout)
if result.returncode or "SCRIPT ERROR:" in result.stdout or "ERROR:" in result.stdout:
    raise SystemExit(result.returncode or 1)
