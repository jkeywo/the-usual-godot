extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var width := OS.get_environment("THE_USUAL_CAPTURE_WIDTH")
	if not width.is_empty():
		root.size = Vector2i(int(width), int(OS.get_environment("THE_USUAL_CAPTURE_HEIGHT")))
	var game: Control = load("res://client/main.tscn").instantiate()
	root.add_child(game)
	game.speed = 0
	if OS.get_environment("THE_USUAL_CAPTURE_MODE") == "orders":
		game.simulation.submit_player_command(
			VillageCommand.go_to(501, 1, {"place": 0, "x": 12, "y": 9})
		)
		game.simulation.submit_player_command(
			VillageCommand.use_object(502, 1, "object.cottage_bed", "affordance.sleep")
		)
		game.simulation.submit_player_command(
			VillageCommand.use_object(503, 1, "object.cottage_stove", "affordance.make_a_meal")
		)
		game.simulation.advance_tick()
		game.snapshot = game.simulation.cottage_snapshot()
		game.view.set_snapshot(game.snapshot, game.previous)
		game.refresh_ui()
	game.responsive_layout()
	if OS.get_environment("THE_USUAL_CAPTURE_MODE") == "menu":
		game.open_menu(game.view.context_target(game.snapshot.portals[0].from), Vector2(480, 360))
	elif OS.get_environment("THE_USUAL_CAPTURE_MODE") == "map":
		game.village_map.open()
	elif OS.get_environment("THE_USUAL_CAPTURE_MODE") == "details":
		game.details.show()
	elif OS.get_environment("THE_USUAL_CAPTURE_MODE") == "orders":
		game.detail_tabs.current_tab = 1
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := OS.get_environment("THE_USUAL_CAPTURE")
	var error := root.get_texture().get_image().save_png(destination)
	print("CAPTURE_RESULT:", error)
	quit(error)
