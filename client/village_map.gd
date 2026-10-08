class_name VillageMap
extends Control

var game: Control
var sites: Array = []
var frame: PanelContainer
var canvas: Control
var markers: Array[Button] = []
var active_site: Dictionary = {}
var active_floor: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	sites = JSON.parse_string(FileAccess.get_file_as_string("res://content/navigation.json")).sites
	frame = game.panel()
	add_child(frame)
	var column := VBoxContainer.new()
	frame.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title: Label = game.label(game.tr_text("village_map"), 22, Color("c2e493"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(game.button(game.tr_text("close_menu"), hide))
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(280, 320)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.draw.connect(draw_village)
	canvas.gui_input.connect(click_house)
	canvas.resized.connect(arrange_markers)
	column.add_child(canvas)
	for site: Dictionary in sites:
		var destination := definition(site.floors[0])
		var marker: Button = game.button(
			destination.display_name, view_location.bind(site.floors[0])
		)
		marker.toggle_mode = true
		marker.tooltip_text = destination.display_name
		markers.append(marker)
		canvas.add_child(marker)
	hide()


func definition(id: String) -> Dictionary:
	for place: Dictionary in game.snapshot.places:
		if place.id == id:
			return place
	return {}


func refresh_location() -> void:
	var current: Dictionary = game.view.current_place()
	if current.is_empty():
		return
	active_site = {}
	active_floor = 0
	for site: Dictionary in sites:
		if current.id in site.floors:
			active_site = site
			active_floor = site.floors.find(current.id)
	game.location_label.text = current.display_name
	game.floor_up.visible = (
		not active_site.is_empty() and active_floor + 1 < active_site.floors.size()
	)
	game.floor_down.visible = active_floor > 0
	for index: int in markers.size():
		markers[index].set_pressed_no_signal(sites[index] == active_site)


func change_floor(direction: int) -> void:
	refresh_location()
	if active_site.is_empty():
		return
	var index := active_floor + direction
	if index < 0 or index >= active_site.floors.size():
		return
	view_location(active_site.floors[index])


func view_location(id: String) -> void:
	var place := definition(id)
	if place.is_empty():
		return
	game.view.switch_place(place.place)
	game.follow_button.set_pressed_no_signal(false)
	refresh_location()
	hide()


func open() -> void:
	game.close_menu()
	game.settings_panel.hide()
	refresh_location()
	show()
	arrange()
	markers[0].grab_focus()


func arrange() -> void:
	if frame == null:
		return
	frame.size = Vector2(minf(760, size.x - 20), minf(510, size.y - 20))
	frame.position = (size - frame.size) * 0.5
	arrange_markers()


func arrange_markers() -> void:
	if canvas == null:
		return
	for index: int in markers.size():
		var marker := markers[index]
		marker.size = marker.get_combined_minimum_size().max(Vector2(100, 36))
		var point := Vector2(sites[index].position[0], sites[index].position[1]) * canvas.size
		marker.position = (point - marker.size * 0.5).clamp(
			Vector2.ZERO, (canvas.size - marker.size).max(Vector2.ZERO)
		)
	canvas.queue_redraw()


func click_house(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if not event.pressed:
		return
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	for site: Dictionary in sites:
		if site.floors[0] == "place.lane":
			continue
		var point := Vector2(site.position[0], site.position[1]) * canvas.size
		if Rect2(point - Vector2(36, 77), Vector2(72, 56)).has_point(event.position):
			view_location(site.floors[0])
			canvas.accept_event()
			return


func draw_village() -> void:
	var bounds := canvas.size
	canvas.draw_rect(Rect2(Vector2.ZERO, bounds), Color("647554"))
	canvas.draw_rect(Rect2(0, bounds.y * 0.48, bounds.x, bounds.y * 0.16), Color("b4a589"))
	canvas.draw_rect(Rect2(bounds.x * 0.18, 0, bounds.x * 0.12, bounds.y), Color("b4a589"))
	canvas.draw_rect(Rect2(bounds.x * 0.72, 0, bounds.x * 0.12, bounds.y * 0.56), Color("b4a589"))
	for index: int in sites.size():
		if sites[index].floors[0] == "place.lane":
			continue
		var point := Vector2(sites[index].position[0], sites[index].position[1]) * bounds
		var house := Rect2(point - Vector2(30, 65), Vector2(60, 40))
		canvas.draw_rect(house.grow(4), Color("203d3c"))
		canvas.draw_rect(house, Color("b9a486"))
		canvas.draw_rect(Rect2(house.position - Vector2(6, 12), Vector2(72, 16)), Color("805b44"))
		canvas.draw_rect(Rect2(house.position + Vector2(10, 10), Vector2(12, 12)), Color("d4d3ad"))
		canvas.draw_rect(Rect2(house.position + Vector2(38, 10), Vector2(12, 30)), Color("365b75"))
	for point: Vector2 in [Vector2(0.45, 0.18), Vector2(0.91, 0.8), Vector2(0.1, 0.8)]:
		var at := (point * bounds).floor()
		canvas.draw_rect(Rect2(at, Vector2(6, 26)), Color("805b44"))
		canvas.draw_rect(Rect2(at - Vector2(12, 10), Vector2(30, 22)), Color("3e593e"))


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		hide()
		accept_event()
