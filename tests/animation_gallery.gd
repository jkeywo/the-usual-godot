extends SceneTree


class Gallery:
	extends Control
	var rig := CharacterAnimation.new()
	var elapsed: float = 0.0
	var font: Font = load("res://assets/kenney_future_narrow.ttf")

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("e8dfc9"))
		draw_string(
			font,
			Vector2(24, 30),
			"THE USUAL - MODULAR CHARACTER ANIMATION",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			22,
			Color("203d3c")
		)
		var names := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
		for direction: int in 8:
			draw_string(
				font,
				Vector2(40 + direction * 92, 60),
				names[direction],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				17,
				Color("203d3c")
			)
		var row: int = 0
		for definition: String in CharacterAnimation.PEOPLE:
			for direction: int in 8:
				paint(
					definition, "", direction, "walk", Vector2(48 + direction * 92, 72 + row * 100)
				)
			row += 1
		draw_string(
			font,
			Vector2(24, 500),
			"TALK / INTERACT - SHARED NAVY OUTFIT",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color("203d3c")
		)
		var index: int = 0
		for definition: String in CharacterAnimation.PEOPLE:
			paint(definition, "navy", 1, "talk", Vector2(48 + index * 184, 525))
			paint(definition, "navy", 1, "interact", Vector2(120 + index * 184, 525))
			index += 1
		draw_string(
			font,
			Vector2(16, 665),
			"Independent heads + shared garment rig | 8-frame walk | 6-frame gestures",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("203d3c")
		)

	func paint(
		definition: String, outfit: String, direction: int, clip_name: String, at: Vector2
	) -> void:
		var layers := rig.layers(definition, outfit, direction, clip_name, elapsed)
		var rect := Rect2(at, CharacterAnimation.CELL)
		draw_texture_rect_region(layers.body, rect, layers.body_rect)
		rect.position += layers.head_offset
		draw_texture_rect_region(layers.head, rect, layers.head_rect)


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	root.size = Vector2i(840, 700)
	var gallery := Gallery.new()
	gallery.size = Vector2(840, 700)
	root.add_child(gallery)
	var output := "res://build/reports/animation-gallery"
	DirAccess.make_dir_recursive_absolute(output)
	for index: int in 120:
		gallery.elapsed = index / 10.0
		gallery.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/%02d.png" % index)
	quit()
