class_name VillageSave
extends RefCounted

const FORMAT: int = 2
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
	if (
		(envelope.get("format") != 1 and envelope.get("format") != FORMAT)
		or envelope.get("content") != content.fingerprint
	):
		return null
	if not envelope.get("payload") is String or not envelope.get("integrity") is String:
		return null
	if (
		envelope.integrity
		!= (
			(str(int(envelope.format)) + ":" + content.fingerprint + ":" + envelope.payload)
			. sha256_text()
		)
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
	if not valid_orders(data, sim):
		return null
	if data.tick < 0 or data.next_id < 1:
		return null
	if data.residents.keys() != sim.state.residents.keys():
		return null
	var positions: Array = []
	for who: int in data.residents:
		var resident: Variant = data.residents[who]
		if not same_shape(sim.state.residents[who], resident) or not valid_tile(resident.position):
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


static func valid_tile(tile: Variant) -> bool:
	if not tile is Dictionary:
		return false
	for key: String in ["place", "x", "y"]:
		if not tile.get(key) is int:
			return false
	return true


static func same_shape(template: Variant, value: Variant) -> bool:
	if typeof(template) != typeof(value):
		return false
	if template is Dictionary:
		for key: Variant in template:
			if not value.has(key) or not same_shape(template[key], value[key]):
				return false
	elif template is Array and not template.is_empty():
		for item: Variant in value:
			if not same_shape(template[0], item):
				return false
	return true


static func valid_orders(data: Dictionary, sim: VillageSimulation) -> bool:
	var queued: Array = []
	for who: Variant in data.queues:
		if (
			not who is int
			or not sim.state.residents.has(who)
			or not sim.state.residents[who].household
			or not data.queues[who] is Array
		):
			return false
		for command: Variant in data.queues[who]:
			if (
				not valid_command(command, sim)
				or command.kind not in [VillageCommand.Kind.GO_TO, VillageCommand.Kind.USE_OBJECT]
			):
				return false
			if (
				command.resident != who
				or command.task in queued
				or data.tasks.get(command.task) not in ["Queued", "Active", "Paused"]
			):
				return false
			queued.append(command.task)
	for command: Variant in data.inbox:
		if not valid_command(command, sim):
			return false
	for task: Variant in data.tasks:
		if (
			not task is int
			or data.tasks[task] not in ["Queued", "Active", "Paused", "Completed", "Cancelled"]
		):
			return false
		if data.tasks[task] in ["Queued", "Active", "Paused"] and task not in queued:
			return false
	return true


static func valid_command(command: Variant, _sim: VillageSimulation) -> bool:
	if not command is Dictionary:
		return false
	for key: String in ["kind", "task", "resident", "priority"]:
		if not command.get(key) is int:
			return false
	if command.kind < 0 or command.kind > VillageCommand.Kind.REORDER:
		return false
	if (
		not command.get("object") is String
		or not command.get("affordance") is String
		or not command.get("destination") is Dictionary
	):
		return false
	if command.has("forced") and not command.forced is bool:
		return false
	if command.kind == VillageCommand.Kind.REORDER and not command.get("queue_index") is int:
		return false
	if command.kind == VillageCommand.Kind.GO_TO and not valid_tile(command.destination):
		return false
	return true
