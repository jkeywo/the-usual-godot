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
	game.manage_order(9999, VillageCommand.Kind.PROMOTE, 0)
	game.simulation.advance_tick()
	game.consume_feedback()
	checks.rejection_explains_reason = game.receipt.text.contains(
		game.strings.rejection_reasons.UnknownTask
	)
	var state_before_animation: Dictionary = game.simulation.state.duplicate(true)
	game.view.animation_time += 4.5
	checks.walking_has_alternating_frames = (
		VillageView.animation_pose("walking", 0.0) != VillageView.animation_pose("walking", 0.2)
	)
	checks.using_has_activity_pose = (
		VillageView.animation_pose("affordance.sleep", 0.0) == "sleep"
		and VillageView.animation_pose("affordance.sit_down", 0.0) == "sit"
	)
	checks.animation_does_not_change_simulation = state_before_animation == game.simulation.state
	checks.feedback_audio_assets_loaded = game.audio.players.size() == 7
	for player: AudioStreamPlayer in game.audio.players.values():
		checks.feedback_audio_assets_loaded = (
			checks.feedback_audio_assets_loaded and player.stream != null
		)
	game.audio.set_muted(true)
	game.audio.play("reject")
	checks.mute_silences_feedback = not game.audio.players.reject.playing
	game.audio.set_muted(false)
	game.simulation.submit_player_command(
		VillageCommand.go_to(401, 1, {"place": 0, "x": 12, "y": 9})
	)
	game.simulation.submit_player_command(
		VillageCommand.go_to(402, 1, {"place": 0, "x": 1, "y": 1})
	)
	game.simulation.advance_tick()
	game.manage_order(402, VillageCommand.Kind.FORCE, 0)
	game.simulation.advance_tick()
	game.consume_feedback()
	checks.force_feedback_is_specific = game.receipt.text == game.strings.force_accepted
	game.snapshot = game.simulation.cottage_snapshot()
	game.select_resident(1)
	checks.order_controls_are_present = (
		not game.orders_box.get_children().is_empty()
		and game.orders_box.get_child(0).get_child_count() == 2
	)
	game.select_resident(3)
	checks.outsider_card_clears_household_details = (
		game.needs_box.get_child_count() == 0
		and game.orders_box.get_child_count() == 0
		and game.memories_box.get_child_count() == 0
	)
	game.select_resident(1)
	var portal: Dictionary = game.snapshot.portals[0]
	var crossing: Dictionary = game.view.context_target(portal.from)
	checks.stairs_use_authored_crossing = (
		crossing.destination == portal.to
		and crossing.affordances[0].display_name == portal.from_label
	)
	crossing = game.view.context_target(portal.to)
	checks.stairs_reverse_crossing = (
		crossing.destination == portal.from
		and crossing.affordances[0].display_name == portal.to_label
	)
	game.open_menu(crossing, Vector2(100, 100))
	game.menu.hide()
	game.menu_action(0)
	checks.crossing_submits_typed_move = (
		game.simulation.state.inbox.back().kind == VillageCommand.Kind.GO_TO
		and game.simulation.state.inbox.back().destination == portal.from
	)
	checks.furniture_art_is_distinct = (
		game.view.textures.bar != game.view.textures.toilet
		and game.view.textures.seat != game.view.textures.toilet
	)
	checks.original_animation_frames_loaded = (
		game.view.textures.has("resident_1_walk0") and game.view.textures.has("resident_4_sleep")
	)
	for target_object: Dictionary in game.snapshot.objects:
		if target_object.id == "object.kings_head_bar":
			var bar: Dictionary = game.view.context_target(target_object.position)
			checks.pub_fixture_uses_authored_action = (
				bar.id == target_object.id and bar.affordances[0].id == "affordance.order_drink"
			)
		if target_object.id == "object.cottage_table":
			checks.decoration_has_no_use_menu = (
				game.view.context_target(target_object.position).is_empty()
			)
		if target_object.id == "person.neighbour":
			var person: Dictionary = game.view.context_target(target_object.position)
			checks.neighbour_offers_conversation = (
				person.id == "person.neighbour" and person.affordances[0].id == "affordance.talk"
			)
	var door: Dictionary = game.snapshot.portals[1]
	checks.door_actions_name_both_directions = (
		game.view.context_target(door.from).affordances[0].display_name == door.from_label
		and game.view.context_target(door.to).affordances[0].display_name == door.to_label
	)
	checks.clock_is_zero_padded = game.strings.clock % [3, 7] == "03:07"
	var projection: Dictionary = game.snapshot.duplicate(true)
	projection.residents[0].position.place = 1
	game.view.selected = 1
	game.view.follow = true
	game.view.set_snapshot(projection, game.snapshot)
	checks.follow_changes_floor_from_snapshot = game.view.place == 1
	game.change_zoom(100)
	checks.zoom_has_upper_bound = game.view.zoom_level == 4
	game.change_zoom(-100)
	checks.zoom_has_lower_bound = game.view.zoom_level == 1
	game.select_resident(0)
	checks.no_selection_clears_card = (
		game.name_label.text == game.strings.no_selection and game.needs_box.get_child_count() == 0
	)
	game.select_resident(1)
	game.view.set_snapshot(game.snapshot, game.previous)
	var failed: Array[String] = []
	for name: String in checks:
		if not checks[name]:
			failed.append(name)
	return {"checks": checks, "failures": failed}
