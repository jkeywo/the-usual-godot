class_name DifferentialTests
extends RefCounted


static func run(t: SimulationTests) -> void:
	var names: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/reference/matrix_manifest.json")
	)
	for filename: String in names:
		var fixture: Dictionary = t.integer_values(
			JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference/" + filename))
		)
		var sim := t.fresh()
		sim.state.seed = fixture.seed
		var command_index: int = 0
		var checkpoint: int = 0
		for tick: int in 601:
			if (
				checkpoint < fixture.checkpoints.size()
				and tick == fixture.checkpoints[checkpoint][0]
			):
				var actual: Dictionary = canonical(sim, t)
				var expected: Dictionary = fixture.checkpoints[checkpoint][1]
				if actual != expected:
					for key: String in expected:
						if actual.get(key) != expected[key]:
							print(
								filename,
								" tick ",
								tick,
								" state mismatch: ",
								key,
								" actual=",
								actual.get(key),
								" expected=",
								expected[key]
							)
							break
				t.check(filename + "_state_" + str(tick), actual == expected)
				checkpoint += 1
			while (
				command_index < fixture.commands.size()
				and fixture.commands[command_index][0] == tick
			):
				var command: Dictionary = fixture.commands[command_index][1]
				var data: Dictionary = command.value
				match command.kind:
					"QueueGoTo":
						sim.submit_player_command(
							VillageCommand.go_to(
								data.task, data.resident, data.destination, data.priority
							)
						)
					"QueueUseObject":
						sim.submit_player_command(
							VillageCommand.use_object(
								data.task,
								data.resident,
								data.object,
								data.affordance,
								data.priority
							)
						)
					"CancelPlayerTask":
						sim.submit_player_command(VillageCommand.cancel(data.task))
				command_index += 1
			if tick < 600:
				sim.advance_tick()
		t.check(filename + "_events", t.same_events(sim.state.ledger, fixture.events))


static func canonical(sim: VillageSimulation, t: SimulationTests) -> Dictionary:
	var data: Dictionary = sim.state.duplicate(true)
	data.erase("ledger")
	data.erase("inbox")
	for who: int in data.residents:
		var r: Dictionary = data.residents[who]
		for need: Dictionary in r.needs.values():
			need.erase("initial")
			need.erase("kind")
		data.residents[who] = {
			"definition_id": r.definition_id, "position": r.position, "needs": r.needs
		}
	for active: Dictionary in data.uses.values():
		for key: String in ["age", "band", "priority", "resident"]:
			active.erase(key)
	for who: int in data.queues:
		var queue: Array = []
		for c: Dictionary in data.queues[who]:
			var entry: Dictionary = {"task": c.task, "priority": c.priority}
			if c.kind == VillageCommand.Kind.GO_TO:
				entry.kind = "GoTo"
				entry.destination = c.destination
			else:
				entry.kind = "UseObject"
				entry.object = c.object
				entry.affordance = c.affordance
			queue.append(entry)
		data.queues[who] = queue
	return t.integer_values(JSON.parse_string(JSON.stringify(data)))
