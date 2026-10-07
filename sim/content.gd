class_name VillageContent
extends RefCounted

var domains: Dictionary = {}
var errors: Array[String] = []
var fingerprint: String = ""


static func load_default() -> VillageContent:
	var result := VillageContent.new()
	var paths: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/manifest.json")
	)
	var digest := ""
	for path: String in paths:
		var asset: VillageAsset = load(path)
		if asset == null:
			result.errors.append("Missing asset: " + path)
			continue
		if not result.domains.has(asset.domain):
			result.domains[asset.domain] = []
		result.domains[asset.domain].append(asset.data.duplicate(true))
		digest += path + JSON.stringify(asset.data, "", true)
	result.fingerprint = digest.sha256_text()
	result.validate()
	return result


func table(domain: String) -> Array:
	var result: Array = []
	for asset: Dictionary in domains.get(domain, []):
		if asset.has(domain) and asset[domain] is Array:
			result.append_array(asset[domain])
		else:
			result.append(asset)
	return result


func index(domain: String) -> Dictionary:
	var result: Dictionary = {}
	for item: Dictionary in table(domain):
		result[item.id] = item
	return result


func validate() -> void:
	for domain: String in [
		"scenarios",
		"maps",
		"people",
		"objects",
		"plans",
		"conducts",
		"intentions",
		"recipes",
		"items",
		"initiatives",
		"coordinators",
		"social"
	]:
		if table(domain).is_empty():
			errors.append("Missing domain: " + domain)
	if not errors.is_empty():
		return
	for domain: String in [
		"people",
		"objects",
		"plans",
		"conducts",
		"intentions",
		"recipes",
		"items",
		"initiatives",
		"coordinators"
	]:
		var seen: Dictionary = {}
		for item: Dictionary in table(domain):
			if seen.has(item.id):
				errors.append("Duplicate definition: " + item.id)
			seen[item.id] = true
	var scenario: Dictionary = table("scenarios")[0]
	var map: Dictionary = table("maps")[0]
	if scenario.map != map.id:
		errors.append("Wrong scenario map")
	var people := index("people")
	var objects := index("objects")
	var plans := index("plans")
	var conducts := index("conducts")
	var positions: Array = []
	for placement: Dictionary in scenario.placements:
		if positions.has(placement.position):
			errors.append("Duplicate placement: " + placement.person)
		positions.append(placement.position)
		if not map_walkable(map, placement.position):
			errors.append("Invalid placement: " + placement.person)
	for id: String in scenario.people:
		if not people.has(id):
			errors.append("Missing person: " + id)
	for id: String in scenario.objects:
		if not objects.has(id):
			errors.append("Missing object: " + id)
	for obj: Dictionary in objects.values():
		if not map_walkable(map, obj.position):
			errors.append("Object inside wall: " + obj.id)
		if obj.get("solid", false):
			if positions.has(obj.position):
				errors.append("Solid fixture blocks placement: " + obj.id)
			for portal: Dictionary in map.portals:
				if obj.position == portal.from or obj.position == portal.to:
					errors.append("Solid fixture blocks threshold: " + obj.id)
		for affordance: Dictionary in obj.get("affordances", []):
			if not obj.slots.any(func(slot: Dictionary) -> bool: return slot.id == affordance.slot):
				errors.append("Missing object slot: " + obj.id)
	for person: Dictionary in people.values():
		for intention: Dictionary in table("intentions"):
			var source: Variant = intention.source
			if source is String and source == "HoldingARole":
				continue
			if (
				source is Dictionary
				and source.kind == "Need"
				and not person.get("needs", []).any(
					func(n: Dictionary) -> bool: return n.kind == source.value
				)
			):
				continue
			var answered := false
			for id: String in person.get("conducts", []):
				for method: Dictionary in conducts.get(id, {}).get("methods", []):
					if method.slot == intention.conduct:
						answered = true
			if not answered:
				errors.append("No conduct answers intention: " + person.id + "/" + intention.id)
	for conduct: Dictionary in conducts.values():
		for method: Dictionary in conduct.methods:
			if not plans.has(method.plan):
				errors.append("Missing conduct plan: " + method.plan)


static func map_walkable(map: Dictionary, pos: Dictionary) -> bool:
	for place: Dictionary in map.places:
		if place.place == pos.place:
			return (
				pos.y >= 0
				and pos.y < place.rows.size()
				and pos.x >= 0
				and pos.x < place.rows[place.rows.size() - 1 - pos.y].length()
				and place.rows[place.rows.size() - 1 - pos.y][pos.x] != "#"
			)
	return false
