class_name ClientTests
extends RefCounted


static func run(game: Control) -> Dictionary:
	var checks: Dictionary = {}
	game.speed = 0
	var before: Dictionary = game.simulation.state.duplicate(true)
	game.select_resident(2)
	game.view.switch_place(2)
	game.view.zoom_level = 4
	game.view.pan = Vector2(100000, -100000)
	game.view.constrain_pan()
	checks.camera_and_selection_do_not_change_simulation = before == game.simulation.state
	checks.camera_cannot_lose_place = (
		absf(game.view.pan.x) < 100000 and absf(game.view.pan.y) < 100000
	)
	checks.selected_resident_changes_card = game.name_label.text == "Mara Bell"
	var targets: Array = game.snapshot.objects.filter(
		func(o: Dictionary) -> bool: return o.id == "object.cottage_toilet"
	)
	var target: Dictionary = targets[0]
	game.open_menu(target, Vector2(100, 100))
	checks.context_menu_uses_authored_actions = (
		game.menu.get_item_text(1) == target.affordances[0].display_name
	)
	game.menu.hide()
	game.menu_action(0)
	checks.orders_are_deferred = (
		game.simulation.state.tasks.is_empty() and game.simulation.state.inbox.size() == 1
	)
	game.simulation.advance_tick()
	game.snapshot = game.simulation.cottage_snapshot()
	game.refresh_ui()
	game.consume_feedback()
	checks.receipt_is_consumed = game.receipt.text == game.strings.accepted
	var count: int = game.feed_lines.size()
	game.consume_feedback()
	checks.feed_does_not_repeat = count == game.feed_lines.size()
	game.simulation.submit_player_command(VillageCommand.cancel(1))
	game.simulation.advance_tick()
	checks.cancellation_uses_command = game.simulation.state.tasks[1] == "Cancelled"
	var safe: Dictionary = game.simulation.cottage_snapshot()
	checks.outsider_private_fields_absent = not safe.residents[2].has("private")
	var state_before: Dictionary = game.simulation.state.duplicate(true)
	game.view.alpha = 0.6
	game.view.set_snapshot(game.snapshot, game.previous)
	checks.interpolation_is_presentation_only = state_before == game.simulation.state
	var file := "user://__usual_acceptance.save"
	checks.platform_save_write = VillageSave.write_slot(game.simulation, file) == OK
	var restored := VillageSave.read_slot(game.content, file)
	checks.platform_save_read = restored != null and restored.state == game.simulation.state
	checks.task_ids_survive_restore = restored != null and restored.next_player_task_id() > 1
	checks.audio_asset_loaded = game.sound.stream != null
	var original_size: Vector2 = game.size
	game.size = Vector2(430, 900)
	game.responsive_layout()
	game.details.visible = false
	game.toggle_details()
	checks.narrow_details_overlay_viewport = game.details.visible and game.viewport_panel.visible
	checks.simulation_anchors_fill_window = (
		game.view.anchor_right == 1.0 and game.view.anchor_bottom == 1.0
	)
	checks.hud_blocks_pointer = game.details.mouse_filter == Control.MOUSE_FILTER_STOP
	checks.hud_does_not_change_simulation = state_before == game.simulation.state
	game.toggle_details()
	checks.narrow_drawer_closes = not game.details.visible and game.viewport_panel.visible
	game.size = original_size
	game.responsive_layout()
	var failed: Array[String] = []
	for name: String in checks:
		if not checks[name]:
			failed.append(name)
	return {"checks": checks, "failures": failed}
