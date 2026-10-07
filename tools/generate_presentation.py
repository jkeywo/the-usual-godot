"""Reproducible project-owned sprite poses and synthesized audio; no external media."""
from pathlib import Path
import math
import struct
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
for person in range(1, 5):
    source = ROOT / f"assets/original/resident_{person}.svg"
    for pose in ["walk0", "walk1", "work0", "work1", "sit", "sleep", "blink"]:
        tree = ET.fromstring(source.read_text())
        parts = list(tree)
        if pose.startswith("walk"):
            stride = 2 if pose == "walk0" else -2
            for index in [1, 3]:
                parts[index].set("y", str(int(parts[index].get("y")) + stride))
            for index in [2, 4]:
                parts[index].set("y", str(int(parts[index].get("y")) - stride))
            for index in [6, 8]:
                parts[index].set("y", str(int(parts[index].get("y")) - stride))
            for index in [7, 9]:
                parts[index].set("y", str(int(parts[index].get("y")) + stride))
        if pose.startswith("work"):
            lift = 5 if pose == "work0" else 8
            for index in [6, 7, 8, 9]:
                parts[index].set("y", str(int(parts[index].get("y")) - lift))
        if pose == "sit":
            for index in [1, 2]:
                parts[index].set("height", "6")
            for index in [3, 4]:
                parts[index].set("y", "36")
        if pose in ["sleep", "blink"]:
            for part in parts:
                if part.get("y") == "10" and part.get("width") == "2":
                    part.set("height", "1")
        ET.register_namespace("", "http://www.w3.org/2000/svg")
        (source.parent / f"resident_{person}_{pose}.svg").write_text(ET.tostring(tree, encoding="unicode"))

output = ROOT / "assets/original/audio"
output.mkdir(exist_ok=True)
RATE = 22050
cues = {"click": (0.05, [740]), "accept": (0.16, [440, 660]),
        "reject": (0.22, [250, 180]), "cancel": (0.13, [550, 330]),
        "complete": (0.26, [440, 550, 660]), "notice": (0.32, [660, 440, 660]),
        "step": (0.075, [110, 75]), "room": (4.0, [55]), "outside": (4.0, [165])}
for name, (duration, notes) in cues.items():
    data = bytearray()
    ambient = name in ["room", "outside"]
    for i in range(int(RATE * duration)):
        t = i / RATE
        freq = notes[min(int(t / duration * len(notes)), len(notes) - 1)]
        envelope = 1.0 if ambient else min(1.0, t / .008) * (1 - t / duration) ** 2
        amplitude = .025 if ambient else (.16 if name == "step" else .22)
        tone = math.sin(math.tau * freq * t)
        if ambient:
            tone *= .6 + .4 * math.sin(math.tau * t / duration)
        data.extend(struct.pack("<h", int(32767 * amplitude * envelope * tone)))
    with wave.open(str(output / f"{name}.wav"), "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(RATE)
        audio.writeframes(data)
