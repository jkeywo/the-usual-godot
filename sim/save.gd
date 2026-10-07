class_name VillageSave
extends RefCounted

const FORMAT: int = 1
const MAX_BYTES: int = 32 * 1024 * 1024


static func encode(sim: VillageSimulation) -> String:
	var payload := Marshalls.raw_to_base64(var_to_bytes(sim.state))
	var envelope := {"format": FORMAT, "content": sim.content.fingerprint, "payload": payload}
	envelope.integrity = (str(FORMAT) + ":" + sim.content.fingerprint + ":" + payload).sha256_text()
	return JSON.stringify(envelope)


static func decode(text: String, content: VillageContent) -> VillageSimulation:
	if text.length() > MAX_BYTES:
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	var envelope: Dictionary = parsed
	if envelope.get("format") != FORMAT or envelope.get("content") != content.fingerprint:
		return null
	if not envelope.get("payload") is String or not envelope.get("integrity") is String:
		return null
	if (
		envelope.integrity
		!= (str(FORMAT) + ":" + content.fingerprint + ":" + envelope.payload).sha256_text()
	):
		return null
	var data: Variant = bytes_to_var(Marshalls.base64_to_raw(envelope.payload))
	if not data is Dictionary:
		return null
	var sim := VillageSimulation.create(content)
	if sim == null:
		return null
	for key: String in sim.state:
		if not data.has(key) or typeof(data[key]) != typeof(sim.state[key]):
			return null
	if data.tick < 0 or data.next_id < 1:
		return null
	if data.residents.keys() != sim.state.residents.keys():
		return null
	var positions: Array = []
	for who: int in data.residents:
		var resident: Variant = data.residents[who]
		if not resident is Dictionary or not resident.get("position") is Dictionary:
			return null
		if resident.get("definition_id") != sim.state.residents[who].definition_id:
			return null
		if resident.get("household") != sim.state.residents[who].household:
			return null
		if not sim.walkable(resident.position) or resident.position in positions:
			return null
		positions.append(resident.position)
		if not resident.get("needs") is Dictionary:
			return null
		for need: String in resident.needs:
			if (
				not resident.needs[need] is Dictionary
				or not resident.needs[need].get("value") is int
			):
				return null
			if resident.needs[need].value < 0 or resident.needs[need].value > 255:
				return null
	for who: int in data.plans:
		if not data.residents.has(who) or not data.plans[who] is Dictionary:
			return null
		for frame: Dictionary in data.plans[who].get("frames", []):
			if not sim.plans.has(frame.get("plan", "")):
				return null
	for who: int in data.uses:
		var active: Dictionary = data.uses[who]
		if (
			not data.residents.has(who)
			or sim.affordance(active.get("object", ""), active.get("affordance", "")).is_empty()
		):
			return null
	sim.state = data.duplicate(true)
	for who: int in sim.state.residents:
		var resident: Dictionary = sim.state.residents[who]
		if sim.objects.has(resident.definition_id):
			sim.objects[resident.definition_id].position = resident.position.duplicate()
	return sim


static func write_slot(sim: VillageSimulation, path: String = "user://cottage.save") -> Error:
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		return ERR_UNAVAILABLE
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encode(sim))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)


static func read_slot(
	content: VillageContent, path: String = "user://cottage.save"
) -> VillageSimulation:
	if not FileAccess.file_exists(path):
		return null
	return decode(FileAccess.get_file_as_string(path), content)
