class_name CameraPortalTests
extends RefCounted


static func run(game: Control, checks: Dictionary) -> void:
	var saved_sim: VillageSimulation = game.simulation
	var saved_snapshot: Dictionary = game.snapshot
	var saved_previous: Dictionary = game.previous
	var saved_task: int = game.next_task
	var saved_pending: Dictionary = game.pending_crossings.duplicate(true)
	var saved_operations: Dictionary = game.pending_operations.duplicate(true)
	var before: Dictionary = saved_sim.state.duplicate(true)
	var old: Dictionary = saved_snapshot.duplicate(true)
	var current: Dictionary = old.duplicate(true)
	old.residents[0].position = {"place": 0, "x": 1, "y": 1}
	current.residents[0].position = {"place": 0, "x": 2, "y": 1}
	game.view.selected = 1
	game.view.zoom_level = 1
	game.view.follow = true
	game.view.set_snapshot(current, old)
	var pans: Array[Vector2] = []
	for fraction: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		game.view.alpha = fraction
		game.view.update_follow()
		pans.append(game.view.pan)
	checks.follow_interpolates_every_render_frame = (
		pans[1].x == pans[0].x - 8
		and pans[2].x == pans[0].x - 16
		and pans[3].x == pans[0].x - 24
		and pans[4].x == pans[0].x - 32
	)
	checks.follow_interpolation_leaves_world_untouched = before == saved_sim.state
	game.simulation = VillageSimulation.create(game.content)
	game.snapshot = game.simulation.cottage_snapshot()
	game.previous = game.snapshot.duplicate(true)
	game.next_task = 9001
	game.pending_crossings.clear()
	game.select_resident(1)
	game.view.switch_place(0)
	game.view.set_snapshot(game.snapshot, game.previous)
	var portal: Dictionary = game.snapshot.portals[0]
	var overlay: Dictionary = game.snapshot.duplicate(true)
	overlay.objects.append(
		{
			"id": "test.person",
			"position": portal.from.duplicate(),
			"display_name": "test",
			"affordances": [{"id": "talk", "display_name": "talk"}]
		}
	)
	game.view.set_snapshot(overlay, overlay)
	checks.stairs_win_over_overlapping_person_menu = game.view.context_target(portal.from).has(
		"destination"
	)
	game.view.set_snapshot(game.snapshot, game.previous)
	game.open_menu(game.view.context_target(portal.from), Vector2(100, 100))
	game.menu.hide()
	game.menu_action(0)
	var arrived_up := advance_crossing(game, portal.to)
	checks.manual_stairs_arrive_upstairs = (
		arrived_up and game.simulation.state.tasks[9001] == "Completed"
	)
	checks.manual_stairs_focus_upstairs_without_follow = (
		game.view.place == 1 and not game.view.follow
	)
	# The resident now occupies the stair tile. Right-click must still offer downstairs.
	game.view.interact(game.view.screen_position(portal.to), false)
	checks.occupied_stairs_remain_clickable = game.menu_target.get("destination", {}) == portal.from
	game.menu.hide()
	game.menu_action(0)
	var arrived_down := advance_crossing(game, portal.from)
	checks.manual_stairs_arrive_downstairs = (
		arrived_down and game.simulation.state.tasks[9002] == "Completed"
	)
	checks.manual_stairs_focus_downstairs_without_follow = (
		game.view.place == 0 and game.pending_crossings.is_empty()
	)
	game.simulation = saved_sim
	game.snapshot = saved_snapshot
	game.previous = saved_previous
	game.next_task = saved_task
	game.pending_crossings = saved_pending
	game.pending_operations = saved_operations
	game.view.set_snapshot(saved_snapshot, saved_previous)
	game.refresh_ui()


static func advance_crossing(game: Control, destination: Dictionary) -> bool:
	for tick: int in 40:
		game.previous = game.snapshot
		game.simulation.advance_tick()
		game.snapshot = game.simulation.cottage_snapshot()
		game.view.set_snapshot(game.snapshot, game.previous)
		game.update_crossing_focus()
		if game.simulation.state.residents[1].position == destination:
			return true
	return false
