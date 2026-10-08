class_name VillageView
extends Control

signal resident_selected(id: int)
signal target_requested(target: Dictionary, screen: Vector2)
signal move_requested(tile: Dictionary)
signal hovered(text: String)

var snapshot: Dictionary = {}
var previous: Dictionary = {}
var selected: int = 1
var place: int = 0
var zoom_level: int = 1
var pan := Vector2.ZERO
var follow: bool = false
var alpha: float = 1.0
var dragging: bool = false
var drag_origin := Vector2.ZERO
var drag_distance: float = 0.0
var textures: Dictionary = {}
var fingers: Dictionary = {}
var animation_time: float = 0.0
var facing: Dictionary = {}
var outfits: Dictionary = {}
var characters := CharacterAnimation.new()
var talking_to: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(constrain_pan)
	for key: String in [
		"toilet",
		"sink",
		"stove",
		"table",
		"sofa",
		"hearth",
		"bed",
		"wardrobe",
		"bar",
		"seat",
		"larder",
		"noticeboard",
		"shop_counter"
	]:
		textures[key] = load("res://assets/original/" + key + ".svg")


func set_snapshot(current: Dictionary, old: Dictionary) -> void:
	snapshot = current
	previous = old
	talking_to.clear()
	for resident: Dictionary in snapshot.residents:
		for prior: Dictionary in previous.get("residents", []):
			if prior.id == resident.id and prior.position.place == resident.position.place:
				facing[resident.id] = CharacterAnimation.direction(
					Vector2(
						resident.position.x - prior.position.x,
						prior.position.y - resident.position.y
					),
					facing.get(resident.id, 2)
				)
		var target: Dictionary = resident.get("activity_target", {})
		if not target.is_empty() and target.place == resident.position.place:
			facing[resident.id] = CharacterAnimation.direction(
				Vector2(target.x - resident.position.x, resident.position.y - target.y),
				facing.get(resident.id, 2)
			)
			if CharacterAnimation.clip(resident.get("activity", "idle")) == "talk":
				for listener: Dictionary in snapshot.residents:
					if listener.position == target and listener.id != resident.id:
						talking_to[listener.id] = resident.position.duplicate()
						if listener.get("activity", "idle") == "idle":
							facing[listener.id] = CharacterAnimation.direction(
								Vector2(
									resident.position.x - target.x, target.y - resident.position.y
								),
								facing.get(listener.id, 2)
							)
	if follow:
		for resident: Dictionary in snapshot.residents:
			if resident.id == selected:
				if place != resident.position.place:
					place = resident.position.place
					pan = Vector2.ZERO
				pan = size * 0.5 - base_origin() - world_position(resident.position)
	constrain_pan()
	queue_redraw()


func current_place() -> Dictionary:
	for definition: Dictionary in snapshot.get("places", []):
		if definition.place == place:
			return definition
	return {}


func map_size() -> Vector2:
	var definition := current_place()
	if definition.is_empty():
		return Vector2.ZERO
	return Vector2(definition.rows[0].length(), definition.rows.size()) * 32 * zoom_level


func base_origin() -> Vector2:
	return ((size - map_size()) * 0.5).floor()


func world_position(tile: Dictionary) -> Vector2:
	var definition := current_place()
	if definition.is_empty():
		return Vector2.ZERO
	return Vector2(tile.x + 0.5, definition.rows.size() - 1 - tile.y + 0.5) * 32 * zoom_level


func screen_position(tile: Dictionary) -> Vector2:
	return base_origin() + pan + world_position(tile)


func tile_at(point: Vector2) -> Dictionary:
	var definition := current_place()
	if definition.is_empty():
		return {}
	var at := (point - base_origin() - pan) / (32 * zoom_level)
	return {"place": place, "x": floori(at.x), "y": definition.rows.size() - 1 - floori(at.y)}


func switch_place(index: int) -> void:
	place = index
	pan = Vector2.ZERO
	follow = false
	constrain_pan()
	queue_redraw()


func constrain_pan() -> void:
	var bounds := map_size()
	var margin: float = 32 * zoom_level
	pan.x = (clampf(pan.x, -(bounds.x + size.x) * 0.5 + margin, (bounds.x + size.x) * 0.5 - margin))
	pan.y = (clampf(pan.y, -(bounds.y + size.y) * 0.5 + margin, (bounds.y + size.y) * 0.5 - margin))
	pan = pan.round()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("203d3c"))
	var definition := current_place()
	if definition.is_empty():
		return
	var cell: float = 32 * zoom_level
	var origin := base_origin() + pan
	var outside: bool = place == 3
	for row: int in definition.rows.size():
		for x: int in definition.rows[row].length():
			var rect := Rect2(origin + Vector2(x, row) * cell, Vector2.ONE * cell)
			var wall: bool = definition.rows[row][x] == "#"
			var color := (
				Color("b4ad92") if wall else (Color("8a9273") if outside else Color("a68b68"))
			)
			if not wall and (row + x) % 2 == 0:
				color = color.lightened(0.035)
			draw_rect(rect, color)
			if wall:
				draw_rect(Rect2(rect.position, Vector2(cell, 5 * zoom_level)), Color("d2cab1"))
				draw_line(
					rect.position + Vector2(0, cell - 2),
					rect.end - Vector2(0, 2),
					Color("596454"),
					2
				)
			else:
				draw_line(
					rect.position + Vector2(0, cell - 1),
					rect.end - Vector2(0, 1),
					Color("76694e33"),
					1
				)
	for portal: Dictionary in snapshot.portals:
		for tile: Dictionary in [portal.from, portal.to]:
			if tile.place != place:
				continue
			var point := screen_position(tile)
			draw_rect(
				Rect2(point - Vector2.ONE * cell * 0.45, Vector2.ONE * cell * 0.9), Color("dfc889")
			)
			for step: int in 4:
				draw_line(
					point + Vector2(-10, -10 + step * 6) * zoom_level,
					point + Vector2(10, -10 + step * 6) * zoom_level,
					Color("8e7956"),
					2 * zoom_level
				)
	var things: Array = []
	for object: Dictionary in snapshot.objects:
		if object.position.place == place and object.object_type != "object_type.person":
			things.append({"type": "object", "value": object, "y": object.position.y})
	for resident: Dictionary in snapshot.residents:
		if resident.position.place == place:
			things.append({"type": "resident", "value": resident, "y": resident.position.y})
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.y > b.y)
	for thing: Dictionary in things:
		var value: Dictionary = thing.value
		var point := screen_position(value.position)
		if thing.type == "object":
			var key: String = value.object_type.trim_prefix("object_type.")
			if not textures.has(key):
				key = "noticeboard" if "noticeboard" in value.id else "shop_counter"
			draw_texture_rect(
				textures[key],
				Rect2(point - Vector2(32, 44) * zoom_level, Vector2(64, 64) * zoom_level),
				false
			)
		else:
			var moving := false
			for old: Dictionary in previous.get("residents", []):
				if old.id == value.id and old.position.place == place:
					moving = old.position != value.position
					point = screen_position(old.position).lerp(point, alpha).round()
			if value.id == selected:
				draw_arc(
					point + Vector2(0, 8) * zoom_level,
					15 * zoom_level,
					0,
					TAU,
					24,
					Color("f8dfa2"),
					2 * zoom_level
				)
			var activity: String = value.get("activity", "idle")
			if activity == "idle" and talking_to.has(value.id):
				activity = "affordance.talk"
			var clip_name := "walk" if moving else CharacterAnimation.clip(activity)
			var layers := characters.layers(
				value.definition_id,
				outfits.get(value.id, ""),
				facing.get(value.id, 2),
				clip_name,
				animation_time + value.id * 0.17
			)
			var rotation: float = -PI / 2 if clip_name == "sleep" else 0.0
			draw_set_transform(point, rotation)
			var rect := Rect2(-Vector2(24, 66) * zoom_level, CharacterAnimation.CELL * zoom_level)
			draw_texture_rect_region(layers.body, rect, layers.body_rect)
			rect.position += layers.head_offset * zoom_level
			draw_texture_rect_region(layers.head, rect, layers.head_rect)
			draw_set_transform(Vector2.ZERO)


func interact(point: Vector2, primary: bool) -> bool:
	var tile := tile_at(point)
	if tile.is_empty():
		return false
	for resident: Dictionary in snapshot.residents:
		if resident.position.place != place:
			continue
		var at := screen_position(resident.position)
		if Rect2(at - Vector2(22, 66) * zoom_level, Vector2(44, 80) * zoom_level).has_point(point):
			if primary and resident.household:
				resident_selected.emit(resident.id)
				return true
			if not primary:
				for object: Dictionary in snapshot.objects:
					if object.id == resident.definition_id:
						target_requested.emit(object, global_position + point)
						return true
	if primary:
		return false
	var target: Dictionary = context_target(tile)
	if not target.is_empty():
		target_requested.emit(target, global_position + point)
		return true
	move_requested.emit(tile)

	return true


func context_target(tile: Dictionary) -> Dictionary:
	for object: Dictionary in snapshot.get("objects", []):
		if object.position == tile and not object.affordances.is_empty():
			return object.duplicate(true)
	for portal: Dictionary in snapshot.get("portals", []):
		if tile == portal.from or tile == portal.to:
			var from_side: bool = tile == portal.from
			return {
				"id": portal.id,
				"display_name": portal.display_name,
				"destination": portal.to if from_side else portal.from,
				"affordances":
				[
					{
						"id": portal.id,
						"display_name": portal.from_label if from_side else portal.to_label
					}
				]
			}
	return {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom_level = clampi(
				zoom_level + (1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1), 1, 4
			)
			constrain_pan()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				dragging = true
				drag_origin = event.position
				drag_distance = 0
			else:
				dragging = false
				if drag_distance < 8:
					interact(event.position, event.button_index == MOUSE_BUTTON_LEFT)
	elif event is InputEventMouseMotion:
		if dragging:
			drag_distance += event.relative.length()
			if drag_distance >= 8:
				pan += event.relative
				follow = false
				constrain_pan()
		else:
			var tile := tile_at(event.position)
			var text := ""
			for object: Dictionary in snapshot.get("objects", []):
				if object.position == tile:
					text = object.display_name
			hovered.emit(text)
	elif event is InputEventScreenTouch:
		if event.pressed:
			fingers[event.index] = event.position
			drag_distance = 0
		else:
			fingers.erase(event.index)
			if drag_distance < 8:
				if not interact(event.position, true):
					interact(event.position, false)
	elif event is InputEventScreenDrag:
		drag_distance += event.relative.length()
		if fingers.size() == 1:
			pan += event.relative
			follow = false
		elif fingers.size() == 2:
			var before: Array = fingers.values()
			var distance: float = before[0].distance_to(before[1])
			fingers[event.index] = event.position
			var after: Array = fingers.values()
			var change: float = after[0].distance_to(after[1]) - distance
			if absf(change) > 12:
				zoom_level = clampi(zoom_level + signi(int(change)), 1, 4)
		fingers[event.index] = event.position
		constrain_pan()
	accept_event()


func change_outfit(resident: int, outfit: String) -> void:
	if outfit in CharacterAnimation.OUTFITS:
		outfits[resident] = outfit
		queue_redraw()
