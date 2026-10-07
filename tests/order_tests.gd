class_name OrderTests
extends RefCounted


static func run(t: SimulationTests) -> void:
	var sim := t.fresh(true)
	for id: int in [101, 102, 103]:
		sim.submit_player_command(VillageCommand.go_to(id, 1, t.tile(0, 12, 9)))
	sim.advance_tick()
	var before: Dictionary = sim.state.duplicate(true)
	sim.submit_player_command(VillageCommand.manage(103, VillageCommand.Kind.PROMOTE))
	t.check("promote_is_deferred", sim.state.queues == before.queues)
	sim.advance_tick()
	t.check(
		"promote_preserves_active_head",
		sim.state.queues[1][0].task == 101 and sim.state.queues[1][1].task == 103
	)
	sim.submit_player_command(VillageCommand.manage(103, VillageCommand.Kind.REORDER, 2))
	sim.advance_tick()
	t.check(
		"reorder_waiting_queue",
		sim.state.queues[1][1].task == 102 and sim.state.queues[1][2].task == 103
	)
	sim.submit_player_command(VillageCommand.manage(102, VillageCommand.Kind.REORDER, -1))
	sim.advance_tick()
	var invalid_position: bool = false
	for event: Dictionary in sim.state.ledger:
		if event.kind == "PlayerCommandRejected" and event.data.reason == "InvalidQueuePosition":
			invalid_position = true
	t.check("invalid_reorder_rejected", invalid_position)
	sim.submit_player_command(VillageCommand.manage(103, VillageCommand.Kind.FORCE))
	sim.advance_tick()
	t.check(
		"force_preserves_displaced_task",
		sim.state.queues[1][0].task == 103 and sim.state.tasks[101] == "Paused"
	)
	t.check("force_stays_in_player_band", sim.state.queues[1][0].priority == 500)
	var restored := VillageSave.decode(VillageSave.encode(sim), t.content)
	t.advance(sim, 25)
	t.advance(restored, 25)
	t.check("managed_queue_save_resume", sim.state == restored.state)
	sim = t.fresh(true)
	sim.submit_player_command(VillageCommand.manage(999, VillageCommand.Kind.FORCE))
	sim.advance_tick()
	t.check(
		"unknown_managed_task_rejected_without_mutation",
		sim.state.queues.is_empty() and t.has_event(sim, "PlayerCommandRejected")
	)
	t.check(
		"invalid_command_receipt_visible",
		sim.events_since(0).events.any(
			func(e: Dictionary) -> bool: return e.kind == "PlayerCommandRejected"
		)
	)
	sim = t.fresh(true)
	sim.begin_use(1, t.TOILET, t.USE, 0, 1000, 101)
	sim.state.tasks[101] = "Active"
	sim.state.queues[1] = [
		VillageCommand.use_object(101, 1, t.TOILET, t.USE).to_data(),
		VillageCommand.go_to(102, 1, t.tile(0, 12, 9)).to_data()
	]
	sim.state.tasks[102] = "Queued"
	sim.tick_uses()
	t.check("force_fixture_test_holds_claim", sim.state.slots.get(t.SLOT) == 1)
	sim.submit_player_command(VillageCommand.manage(102, VillageCommand.Kind.FORCE))
	sim.advance_tick()
	t.check(
		"force_releases_interrupted_claims",
		not sim.state.slots.has(t.SLOT) and not sim.state.capabilities.has("1/Hands")
	)
	t.check(
		"force_does_not_complete_interrupted_work",
		sim.state.tasks[101] == "Paused" and not t.has_event(sim, "ObjectUseCompleted")
	)
	sim = t.fresh(true)
	sim.submit_player_command(VillageCommand.go_to(101, 1, t.tile(0, 12, 9)))
	sim.submit_player_command(VillageCommand.go_to(102, 1, t.tile(0, 3, 9)))
	sim.advance_tick()
	sim.state.residents[1].needs.Toilet.value = 95
	sim.submit_player_command(VillageCommand.manage(102, VillageCommand.Kind.FORCE))
	sim.advance_tick()
	t.check(
		"forced_order_yields_to_urgent_need",
		sim.state.plans[1].band == 2000 and sim.state.walks.get(1, {}).get("task", 0) == 0
	)
	sim.submit_player_command(VillageCommand.cancel(102))
	sim.advance_tick()
	t.check("forced_order_remains_cancellable", sim.state.tasks[102] == "Cancelled")

	sim = t.fresh(true)
	sim.submit_player_command(VillageCommand.go_to(201, 1, t.tile(1, 4, 4)))
	for tick: int in 80:
		sim.advance_tick()
		if not sim.state.portals.is_empty():
			break
	t.check("portal_interrupt_fixture_enters_portal", not sim.state.portals.is_empty())
	sim.submit_player_command(VillageCommand.cancel(201))
	sim.advance_tick()
	t.check("cancel_releases_portal_occupancy", not sim.state.portals.values().has(1))
	sim = t.fresh(true)
	sim.submit_player_command(VillageCommand.go_to(201, 1, t.tile(1, 4, 4)))
	sim.submit_player_command(VillageCommand.go_to(202, 1, t.tile(0, 12, 9)))
	for tick: int in 80:
		sim.advance_tick()
		if not sim.state.portals.is_empty():
			break
	sim.submit_player_command(VillageCommand.manage(202, VillageCommand.Kind.FORCE))
	sim.advance_tick()
	t.check("force_releases_portal_occupancy", not sim.state.portals.values().has(1))
	t.check("force_in_portal_preserves_interrupted_order", sim.state.tasks[201] == "Paused")

	sim = t.fresh(true)
	sim.submit_player_command(VillageCommand.go_to(301, 1, t.tile(0, 12, 9)))
	sim.advance_tick()
	sim.submit_player_command(VillageCommand.manage(301, VillageCommand.Kind.FORCE))
	restored = VillageSave.decode(VillageSave.encode(sim), t.content)
	t.check(
		"pending_management_commands_survive_restore",
		restored != null and restored.state.inbox == sim.state.inbox
	)
	var legacy: Dictionary = JSON.parse_string(VillageSave.encode(sim))
	legacy.format = 1
	legacy.integrity = ("1:" + legacy.content + ":" + legacy.payload).sha256_text()
	t.check(
		"previous_godot_save_format_loads",
		VillageSave.decode(JSON.stringify(legacy), t.content) != null
	)
	legacy.format = 999
	t.check(
		"future_save_version_is_rejected",
		VillageSave.decode(JSON.stringify(legacy), t.content) == null
	)
	sim.state.queues[1][0].kind = 999
	t.check(
		"invalid_saved_queue_is_rejected",
		VillageSave.decode(VillageSave.encode(sim), t.content) == null
	)
	sim = t.fresh(true)
	sim.state.residents[1].needs.erase("Hunger")
	t.check(
		"missing_saved_need_is_rejected",
		VillageSave.decode(VillageSave.encode(sim), t.content) == null
	)
