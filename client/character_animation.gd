class_name CharacterAnimation
extends RefCounted

const CELL := Vector2(48, 80)
const COUNTS := {"idle": 1, "walk": 8, "talk": 6, "interact": 6, "sit": 1, "sleep": 1}
const RATES := {"idle": 1.0, "walk": 10.0, "talk": 6.0, "interact": 5.0, "sit": 1.0, "sleep": 1.0}
const BOB := [0, 1, 0, -1, 0, 1, 0, -1]
const OUTFITS := ["sage", "ochre", "landlord", "neighbour", "navy"]
const PEOPLE := {
	"person.newcomer_a": {"head": 1, "outfit": "sage"},
	"person.newcomer_b": {"head": 2, "outfit": "ochre"},
	"person.landlord": {"head": 3, "outfit": "landlord"},
	"person.neighbour": {"head": 4, "outfit": "neighbour"}
}
var cache: Dictionary = {}


static func direction(delta: Vector2, fallback: int = 2) -> int:
	if delta.length_squared() < 0.001:
		return fallback
	return posmod(roundi(delta.angle() / (PI / 4.0)), 8)


static func clip(activity: String) -> String:
	if activity == "walking":
		return "walk"
	if "sleep" in activity:
		return "sleep"
	if "sit" in activity or "seat" in activity:
		return "sit"
	if "talk" in activity or "speak" in activity:
		return "talk"
	return "idle" if activity == "idle" else "interact"


static func frame(clip_name: String, elapsed: float) -> int:
	return posmod(int(maxf(0.0, elapsed) * RATES[clip_name]), COUNTS[clip_name])


func texture(path: String) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path)
	return cache[path]


func layers(
	definition: String, outfit: String, facing: int, clip_name: String, elapsed: float
) -> Dictionary:
	var person: Dictionary = PEOPLE.get(definition, PEOPLE["person.newcomer_a"])
	var clothing: String = outfit if outfit in OUTFITS else person.outfit
	var index := frame(clip_name, elapsed)
	var bob: int = (
		BOB[index]
		if clip_name == "walk"
		else (1 if clip_name in ["talk", "interact"] and index in [2, 5] else 0)
	)
	if clip_name == "sit":
		bob = 3
	var expression: int = 0
	if clip_name == "talk":
		expression = 2 + index % 2
	elif clip_name == "sleep" or fmod(elapsed, 4.0) < 0.12:
		expression = 1
	return {
		"body":
		texture("res://assets/characters/body_%s_%d_%s.svg" % [clothing, person.head, clip_name]),
		"head": texture("res://assets/characters/head_%d.svg" % person.head),
		"body_rect": Rect2(Vector2(index * CELL.x, facing * CELL.y), CELL),
		"head_rect": Rect2(Vector2(expression * CELL.x, facing * CELL.y), CELL),
		"head_offset": Vector2(0, bob),
		"frame": index,
		"clip": clip_name,
		"outfit": clothing
	}


func portrait(definition: String) -> AtlasTexture:
	var person: Dictionary = PEOPLE.get(definition, PEOPLE["person.newcomer_a"])
	var result := AtlasTexture.new()
	result.atlas = texture("res://assets/characters/head_%d.svg" % person.head)
	result.region = Rect2(12, 2 * CELL.y + 3, 24, 24)
	return result
