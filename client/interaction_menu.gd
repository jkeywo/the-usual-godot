class_name InteractionMenu
extends Control

var game: Control
var choices: Array[Button] = []
var hub: PanelContainer
var origin := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func open(target: Dictionary, point: Vector2) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	choices.clear()
	hub = game.panel()
	add_child(hub)
	var title: Label = game.label(target.display_name, 16, Color("c2e493"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub.add_child(title)
	for index: int in target.affordances.size():
		var choice: Button = game.button(target.affordances[index].display_name, choose.bind(index))
		choice.custom_minimum_size.x = 140
		choices.append(choice)
		add_child(choice)
	origin = point
	show()
	arrange()
	if not choices.is_empty():
		choices[0].grab_focus()


func arrange() -> void:
	if not visible:
		return
	var compact := size.x < 700
	var centre := origin
	centre.x = clampf(centre.x, 210, size.x - 210) if not compact else size.x * 0.5
	centre.y = clampf(centre.y, 150, size.y - 210)
	hub.size = Vector2(150, 52)
	hub.position = centre - hub.size * 0.5
	var directions := [
		Vector2(-1, 0),
		Vector2(1, 0),
		Vector2(0, 1),
		Vector2(0, -1),
		Vector2(-1, 1),
		Vector2(1, 1),
		Vector2(-1, -1),
		Vector2(1, -1)
	]
	if compact:
		var height := 60 + choices.size() * 44
		var top := clampf(origin.y - height * 0.5, 12, maxf(12, size.y - height - 12))
		hub.position = Vector2(centre.x - 75, top)
		for index: int in choices.size():
			var choice := choices[index]
			choice.size = Vector2(minf(size.x - 32, 320), 40)
			choice.position = Vector2(centre.x - choice.size.x * 0.5, top + 60 + index * 44)
	else:
		for index: int in choices.size():
			var choice := choices[index]
			choice.size = choice.get_combined_minimum_size().max(Vector2(140, 40))
			var direction: Vector2 = directions[index % directions.size()]
			var offset := Vector2(direction.x * (90 + choice.size.x * 0.5), direction.y * 90)
			choice.position = (centre + offset - choice.size * 0.5).clamp(
				Vector2(8, 8), size - choice.size - Vector2(8, 8)
			)
	queue_redraw()


func choose(index: int) -> void:
	hide()
	game.menu_action(index)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		hide()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventKey
		and event.pressed
		and event.physical_keycode == KEY_ESCAPE
	):
		hide()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if hub == null:
		return
	for choice: Button in choices:
		draw_line(
			hub.position + hub.size * 0.5, choice.position + choice.size * 0.5, Color("90adbd"), 2
		)
