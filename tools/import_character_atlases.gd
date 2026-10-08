extends SceneTree
# Technical atlas import only: alpha cutoff, trim, nearest sampling and registration.
# All drawing comes from the imagegen sources; this tool never paints character features.
const CELL := Vector2i(48, 80)
const OUTFITS := ["sage", "ochre", "landlord", "neighbour", "navy"]


func _initialize() -> void:
	for outfit: String in OUTFITS:
		import_body(outfit)
	import_heads()
	import_seated()
	quit()


func source(path: String) -> Image:
	var image := Image.load_from_file("res://art/source/" + path + ".png")
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x, y)
			pixel.a = 1.0 if pixel.a >= 0.5 else 0.0
			image.set_pixel(x, y, pixel if pixel.a > 0 else Color.TRANSPARENT)
	return image


func bands(image: Image, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var start := -1
	for y: int in image.get_height():
		var occupied := false
		for x: int in image.get_width():
			if image.get_pixel(x, y).a > 0:
				occupied = true
				break
		if occupied and start < 0:
			start = y
		elif not occupied and start >= 0:
			result.append(Vector2i(start, y))
			start = -1
	if start >= 0:
		result.append(Vector2i(start, image.get_height()))
	# Tiny empty stripes inside a head/body are not row separators.
	while result.size() > count:
		var smallest := 0
		var gap := 100000
		for i: int in result.size() - 1:
			if result[i + 1].x - result[i].y < gap:
				gap = result[i + 1].x - result[i].y
				smallest = i
		result[smallest].y = result[smallest + 1].y
		result.remove_at(smallest + 1)
	assert(result.size() == count, "Unexpected source row count " + str(result.size()))
	return result


func frame_image(image: Image, row: Vector2i, column: int, columns: int) -> Image:
	var width := image.get_width() / columns
	return image.get_region(Rect2i(column * width, row.x, width, row.y - row.x))


func place_body(atlas: Image, frame: Image, column: int, row: int, scale_factor: float) -> void:
	var rect := frame.get_used_rect()
	var trimmed := frame.get_region(rect)
	# Register the collar, not the hand/foot bounds (gestures can extend to one side).
	var sum_x := 0.0
	var pixels := 0
	for y: int in mini(4, trimmed.get_height()):
		for x: int in trimmed.get_width():
			if trimmed.get_pixel(x, y).a > 0:
				sum_x += x
				pixels += 1
	var neck_x := sum_x / maxi(1, pixels)
	trimmed.resize(
		maxi(1, roundi(trimmed.get_width() * scale_factor)),
		maxi(1, roundi(trimmed.get_height() * scale_factor)),
		Image.INTERPOLATE_NEAREST
	)
	var at := Vector2i(column * CELL.x + 24 - roundi(neck_x * scale_factor), row * CELL.y + 20)
	atlas.blit_rect(trimmed, Rect2i(Vector2i.ZERO, trimmed.get_size()), at)


func import_body(outfit: String) -> void:
	var walk := source("walk_" + outfit)
	var gestures := source("gestures_" + outfit)
	var walking_rows := bands(walk, 8)
	var gesture_rows := bands(gestures, 12)
	var walk_scale := 58.0 / (walking_rows[2].y - walking_rows[2].x)
	var gesture_scale := 58.0 / (gesture_rows[8].y - gesture_rows[8].x)
	for clip: String in ["idle", "walk", "talk", "interact", "sit", "sleep"]:
		var columns := 8 if clip == "walk" else (6 if clip in ["talk", "interact"] else 1)
		var atlas := Image.create(CELL.x * columns, CELL.y * 8, false, Image.FORMAT_RGBA8)
		for direction: int in 8:
			for index: int in columns:
				var frame: Image
				var scale_factor: float
				if clip in ["walk", "idle", "sit", "sleep"]:
					frame = frame_image(
						walk, walking_rows[direction], index if clip == "walk" else 2, 8
					)
					scale_factor = walk_scale
				else:
					var rear := direction in [5, 6, 7]
					var gesture_row := (10 if rear else 8) + (1 if clip == "interact" else 0)
					frame = frame_image(
						gestures, gesture_rows[gesture_row], index if columns > 1 else 6, 8
					)
					if direction in [3, 4, 7]:
						frame.flip_x()
					scale_factor = gesture_scale
				place_body(atlas, frame, index, direction, scale_factor)
		assert(atlas.save_png("res://assets/characters/body_%s_%s.png" % [outfit, clip]) == OK)


func import_heads() -> void:
	var expressions: Array[Image] = [source("heads"), source("heads_blink"), source("heads_talk")]
	for person: int in 4:
		var atlas := Image.create(CELL.x * 3, CELL.y * 8, false, Image.FORMAT_RGBA8)
		for expression: int in 3:
			var rows := bands(expressions[expression], 8)
			for direction: int in 8:
				var frame := frame_image(expressions[expression], rows[direction], person, 4)
				var trimmed := frame.get_region(frame.get_used_rect())
				var scale_factor := 21.0 / trimmed.get_height()
				trimmed.resize(
					maxi(1, roundi(trimmed.get_width() * scale_factor)),
					21,
					Image.INTERPOLATE_NEAREST
				)
				atlas.blit_rect(
					trimmed,
					Rect2i(Vector2i.ZERO, trimmed.get_size()),
					Vector2i(
						expression * CELL.x + 24 - trimmed.get_width() / 2, direction * CELL.y + 1
					)
				)
		assert(atlas.save_png("res://assets/characters/head_%d.png" % (person + 1)) == OK)


func import_seated() -> void:
	var seated := source("seated")
	var rows := bands(seated, 8)
	var scale_factor := 46.0 / (rows[2].y - rows[2].x)
	for outfit: int in OUTFITS.size():
		var atlas := Image.create(CELL.x, CELL.y * 8, false, Image.FORMAT_RGBA8)
		for direction: int in 8:
			place_body(
				atlas, frame_image(seated, rows[direction], outfit, 5), 0, direction, scale_factor
			)
		assert(atlas.save_png("res://assets/characters/body_%s_sit.png" % OUTFITS[outfit]) == OK)
