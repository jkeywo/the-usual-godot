class_name HudTests
extends RefCounted


static func run(game: Control, checks: Dictionary) -> void:
	var saved_sim: VillageSimulation = game.simulation
	var saved_snapshot: Dictionary = game.snapshot
	var saved_previous: Dictionary = game.previous
	var saved_task: int = game.next_task
	var saved_ops: Dictionary = game.pending_operations.duplicate(true)
	var before := saved_sim.state.duplicate(true)
	var old_size: Vector2 = game.size
	var old_place: int = game.view.place
	var old_follow: bool = game.view.follow
	game.size = Vector2(1280, 800)
	game.responsive_layout()
	checks.bottom_docks_do_not_overlap = (
		game.bottom_hud.position.x + game.bottom_hud.size.x < game.details.position.x
	)
	checks.portraits_stack_beside_bottom_dock = (
		game.household.vertical and game.household_panel.position.y < game.bottom_hud.position.y
	)
	for index: int in 3:
		game.detail_tabs.current_tab = index
		var box: Container = [game.needs_box, game.orders_box, game.memories_box][index]
		checks["resident_tab_" + str(index) + "_shows_its_content"] = (
			box.get_parent().get_parent() == game.detail_tabs.get_current_tab_control()
		)
	var option_texts: Array[String] = []
	for child: Node in game.settings_panel.get_child(0).get_children():
		if child is Button:
			option_texts.append(child.text)
	checks.options_retain_save_load_clothes_audio = (
		game.strings.save in option_texts
		and game.strings.load in option_texts
		and game.strings.outfit_toggle in option_texts
		and game.strings.audio_on in option_texts
	)
	game.village_map.view_location("place.cottage_ground")
	checks.ground_floor_has_only_up_arrow = game.floor_up.visible and not game.floor_down.visible
	game.floor_up.emit_signal("pressed")
	checks.floor_up_views_upstairs = (
		game.view.current_place().id == "place.cottage_upstairs"
		and game.location_label.text == game.view.current_place().display_name
		and game.floor_down.visible
		and not game.floor_up.visible
	)
	game.floor_down.emit_signal("pressed")
	checks.floor_down_views_ground = game.view.current_place().id == "place.cottage_ground"
	game.village_map.open()
	checks.map_has_every_location_once = game.village_map.markers.size() == 4
	game.village_map.markers[1].emit_signal("pressed")
	checks.map_selects_pub_and_closes = (
		game.view.current_place().id == "place.kings_head"
		and not game.village_map.visible
		and not game.view.follow
		and not game.floor_up.visible
		and not game.floor_down.visible
	)
	var map_valid := true
	for site: Dictionary in game.village_map.sites:
		for id: String in site.floors:
			map_valid = map_valid and not game.village_map.definition(id).is_empty()
	checks.map_references_valid_public_places = map_valid
	game.village_map.open()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	var shop: Dictionary = game.village_map.sites[2]
	touch.position = (
		Vector2(shop.position[0], shop.position[1]) * game.village_map.canvas.size - Vector2(0, 45)
	)
	game.village_map.click_house(touch)
	checks.map_buildings_accept_touch = (
		game.view.current_place().id == "place.village_shop" and not game.village_map.visible
	)

	game.size = Vector2(430, 900)
	game.responsive_layout()
	game.village_map.open()
	var map_bounded := true
	for marker: Button in game.village_map.markers:
		map_bounded = (
			map_bounded
			and Rect2(Vector2.ZERO, game.village_map.canvas.size).encloses(
				Rect2(marker.position, marker.size)
			)
		)
	checks.map_markers_fit_narrow_screen = map_bounded
	game.village_map.hide()
	checks.hud_navigation_is_presentation_only = saved_sim.state == before
	game.size = Vector2(1280, 800)
	game.view.switch_place(old_place)
	game.view.follow = old_follow
	game.village_map.refresh_location()
	game.responsive_layout()
	game.simulation = VillageSimulation.create(game.content)
	game.snapshot = game.simulation.cottage_snapshot()
	game.previous = game.snapshot.duplicate(true)
	game.next_task = 9901
	var target: Dictionary = game.snapshot.objects[0]
	for object: Dictionary in game.snapshot.objects:
		if object.affordances.size() > target.affordances.size():
			target = object
	game.open_menu(target, Vector2(1200, 100))
	var authored: bool = game.interaction_menu.choices.size() == target.affordances.size()
	var bounded := true
	for index: int in game.interaction_menu.choices.size():
		var choice: Button = game.interaction_menu.choices[index]
		authored = authored and choice.text == target.affordances[index].display_name
		bounded = (
			bounded and Rect2(Vector2.ZERO, game.size).encloses(Rect2(choice.position, choice.size))
		)
	checks.interaction_bubbles_use_authored_actions = authored
	checks.interaction_bubbles_stay_on_screen = bounded
	game.interaction_menu.choices[0].emit_signal("pressed")
	checks.bubble_selection_submits_typed_command = (
		not game.interaction_menu.visible
		and game.simulation.state.inbox.back().kind == VillageCommand.Kind.USE_OBJECT
		and game.simulation.state.inbox.back().object == target.id
	)
	game.simulation.advance_tick()
	game.snapshot = game.simulation.cottage_snapshot()
	game.select_resident(1)
	checks.top_queue_shows_selected_resident_tasks = (
		game.queue_panel.visible and not game.queue_box.get_children().is_empty()
	)
	var cancel: Button = game.queue_box.get_child(0).get_child(0).get_child(1)
	cancel.emit_signal("pressed")
	checks.top_queue_cancel_submits_typed_command = (
		game.simulation.state.inbox.back().kind == VillageCommand.Kind.CANCEL
	)
	game.size = Vector2(430, 900)
	game.responsive_layout()
	game.open_menu(target, Vector2(420, 880))
	bounded = true
	for choice: Button in game.interaction_menu.choices:
		bounded = (
			bounded and Rect2(Vector2.ZERO, game.size).encloses(Rect2(choice.position, choice.size))
		)
	checks.narrow_interaction_list_stays_on_screen = bounded
	game.close_menu()
	game.simulation = saved_sim
	game.snapshot = saved_snapshot
	game.previous = saved_previous
	game.next_task = saved_task
	game.pending_operations = saved_ops
	game.size = old_size
	game.detail_tabs.current_tab = 0
	game.status_signature = "!"
	game.view.set_snapshot(saved_snapshot, saved_previous)
	game.refresh_ui()
	game.responsive_layout()
