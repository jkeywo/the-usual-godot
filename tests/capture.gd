extends SceneTree


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var game: Control = load("res://client/main.tscn").instantiate()
	root.add_child(game)
	game.speed = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var destination := OS.get_environment("THE_USUAL_CAPTURE")
	var error := root.get_texture().get_image().save_png(destination)
	print("CAPTURE_RESULT:", error)
	quit(error)
