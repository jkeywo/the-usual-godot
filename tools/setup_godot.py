"""Install the exact official editor and platform templates into ignored .tools/."""
from pathlib import Path
import hashlib
import os
import platform
import urllib.request
import zipfile

VERSION = "4.7.2"
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / ".tools"
BASE = f"https://github.com/godotengine/godot/releases/download/{VERSION}-stable/"


def download(name):
    path = DEST / name
    if not path.exists():
        print(f"Downloading {name}", flush=True)
        urllib.request.urlretrieve(BASE + name, path)
    return path


def main():
    DEST.mkdir(exist_ok=True)
    checksum_file = download("SHA512-SUMS.txt")
    sums = {parts[1]: parts[0] for line in checksum_file.read_text().splitlines()
            if len(parts := line.split()) == 2}
    target = "win64.exe" if platform.system() == "Windows" else "linux.x86_64"
    archive = f"Godot_v{VERSION}-stable_{target}.zip"
    template = f"Godot_v{VERSION}-stable_export_templates.tpz"
    for name in (archive, template):
        path = download(name)
        with path.open("rb") as stream:
            assert hashlib.file_digest(stream, "sha512").hexdigest() == sums[name], name
        with zipfile.ZipFile(path) as bundle:
            if name == archive:
                bundle.extractall(DEST)
            else:
                for item in ("windows_debug_x86_64.exe", "windows_release_x86_64.exe",
                             "web_nothreads_debug.zip", "web_nothreads_release.zip"):
                    bundle.extract("templates/" + item, DEST)
    executable = DEST / (f"Godot_v{VERSION}-stable_win64_console.exe"
                         if platform.system() == "Windows" else f"Godot_v{VERSION}-stable_linux.x86_64")
    if platform.system() != "Windows":
        executable.chmod(0o755)
    print(executable)
    if output := os.environ.get("GITHUB_OUTPUT"):
        with open(output, "a") as stream:
            stream.write(f"godot={executable}\n")


if __name__ == "__main__":
    main()
