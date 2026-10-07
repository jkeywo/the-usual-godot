extends SceneTree


func _initialize() -> void:
	var content := VillageContent.load_default()
	var sim := VillageSimulation.create(content)
	if sim == null:
		push_error(str(content.errors))
		quit(1)
		return
	for tick: int in 241:
		if tick in [0, 1, 2, 10, 30, 60, 120, 240]:
			FileAccess.open("res://.reference/godot_%d.json" % tick, FileAccess.WRITE).store_string(
				JSON.stringify(sim.state)
			)
		sim.advance_tick()
	var vectors: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/reference/draw.json")
	)
	for v: Array in vectors:
		if KeyedDraw.draw(v[0], v[1], v[1]) != v[2]:
			push_error("Mixer mismatch: " + str(v))
			quit(1)
			return
	print("240 ticks and all unsigned mixer vectors passed")
	quit()
