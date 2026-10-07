extends Control

var content: VillageContent
var simulation: VillageSimulation
var snapshot: Dictionary = {}
var previous: Dictionary = {}
var strings: Dictionary = {}
var accumulator: float = 0.0
var speed: int = 1
var selected: int = 1
var next_task: int = 1
var event_cursor: int = 0
var developer: bool = false
var muted: bool = false
var view: VillageView
var clock_label: Label
var receipt: Label
var hover_label: Label
var name_label: Label
var intention_label: Label
var needs_box: VBoxContainer
var orders_box: VBoxContainer
var memories_box: VBoxContainer
var feed: RichTextLabel
var viewport_panel: Control
var top_hud: PanelContainer
var bottom_hud: PanelContainer
var details: PanelContainer
var feed_panel: PanelContainer
var place_picker: OptionButton
var follow_button: Button
var details_button: Button
var household: HBoxContainer
var menu: PopupMenu
var menu_target: Dictionary = {}
var sound: AudioStreamPlayer
var narrow: bool = false
var status_signature: String = ""
var ready_ok: bool = false
var feed_lines: Array[String] = []


func tr_text(key: String) -> String:
	return strings.get(key, key)


func _ready() -> void:
	strings = JSON.parse_string(FileAccess.get_file_as_string("res://content/ui.json"))
	content = VillageContent.load_default()
	simulation = VillageSimulation.create(content)
	if simulation == null:
		var error := Label.new()
		error.text = tr_text("content_error") + "\n" + str(content.errors)
		add_child(error)
		return
	snapshot = simulation.cottage_snapshot()
	previous = snapshot.duplicate(true)
	build_ui()
	view.set_snapshot(snapshot, previous)
	refresh_ui()
	resized.connect(responsive_layout)
	responsive_layout()
	ready_ok = true
	if (
		OS.has_feature("web")
		and JavaScriptBridge.eval("new URLSearchParams(location.search).has('persist')")
	):
		var restored := VillageSave.read_slot(content, "user://__usual_acceptance.save")
		var valid: bool = restored != null and restored.next_player_task_id() > 1
		JavaScriptBridge.eval("window.__usualPersistence = " + str(valid).to_lower(), true)
		JavaScriptBridge.eval(
			"document.body.setAttribute('data-usual-persistence', '" + str(valid).to_lower() + "')",
			true
		)
	var test_mode: bool = "--test-suite" in (OS.get_cmdline_args() + OS.get_cmdline_user_args())
	if OS.has_feature("web"):
		test_mode = (
			test_mode or JavaScriptBridge.eval("new URLSearchParams(location.search).has('test')")
		)
	if test_mode:
		call_deferred("run_acceptance_tests")


func run_acceptance_tests() -> void:
	var result := SimulationTests.new().run()
	var client := ClientTests.run(self)
	result.client = client
	result.failures.append_array(client.failures)
	print("BROWSER_TEST_RESULT:" + JSON.stringify(result))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__usualTests = " + JSON.stringify(result), true)
		JavaScriptBridge.eval(
			(
				"document.body.setAttribute('data-usual-tests', "
				+ JSON.stringify(JSON.stringify(result))
				+ ")"
			),
			true
		)
	else:
		sound.stop()
		sound.stream = null
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(
			0 if result.failures.is_empty() and result.missing_source_tests.is_empty() else 1
		)


func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.19, 0.18, 0.94)
	style.border_color = Color("526158")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", style)
	return p


func label(text: String, font_size: int = 18, color: Color = Color("ede7ce")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(
		func() -> void:
			click_sound()
			action.call()
	)
	return b


func build_ui() -> void:
	var t := Theme.new()
	t.default_font = load("res://assets/kenney_future_narrow.ttf")
	t.default_font_size = 19
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("354f48")
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var hover := normal.duplicate()
	hover.bg_color = Color("596954")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("997b4a")
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Color("ede7ce"))
	theme = t
	var background := ColorRect.new()
	background.color = Color("172d2d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	viewport_panel = Control.new()
	viewport_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_panel)
	view = VillageView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_panel.add_child(view)
	view.resident_selected.connect(select_resident)
	view.target_requested.connect(open_menu)
	view.move_requested.connect(queue_move)
	view.hovered.connect(func(text: String) -> void: hover_label.text = text)
	top_hud = panel()
	add_child(top_hud)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	top_hud.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	layout.add_child(header)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	title_box.add_child(label(tr_text("title"), 24, Color("e4c48c")))
	clock_label = label("", 24)
	header.add_child(clock_label)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 8)
	layout.add_child(toolbar)
	place_picker = OptionButton.new()
	place_picker.custom_minimum_size = Vector2(180, 40)
	for place: Dictionary in snapshot.places:
		place_picker.add_item(place.display_name, place.place)
	place_picker.item_selected.connect(
		func(index: int) -> void:
			view.switch_place(place_picker.get_item_id(index))
			follow_button.set_pressed_no_signal(false)
	)
	toolbar.add_child(place_picker)
	follow_button = button(
		tr_text("follow"), func() -> void: view.follow = follow_button.button_pressed
	)
	follow_button.toggle_mode = true
	toolbar.add_child(follow_button)
	toolbar.add_child(button("-", change_zoom.bind(-1)))
	toolbar.add_child(button("+", change_zoom.bind(1)))
	for rate: int in [0, 1, 4, 16]:
		var rate_button := button(
			tr_text("paused") if rate == 0 else str(rate) + "×", func() -> void: speed = rate
		)
		toolbar.add_child(rate_button)
	toolbar.add_child(button(tr_text("save"), save_evening))
	toolbar.add_child(button(tr_text("load"), load_evening))
	details_button = button(tr_text("details_toggle"), toggle_details)
	toolbar.add_child(details_button)
	toolbar.add_child(
		button(tr_text("feed_toggle"), func() -> void: feed_panel.visible = not feed_panel.visible)
	)
	toolbar.add_child(button(tr_text("audio"), func() -> void: muted = not muted))
	hover_label = label(tr_text("day"), 14, Color("b8c0ab"))
	hover_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(hover_label)
	details = panel()
	add_child(details)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(scroll)
	var detail_column := VBoxContainer.new()
	detail_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_column.add_theme_constant_override("separation", 12)
	scroll.add_child(detail_column)
	detail_column.add_child(label(tr_text("details"), 15, Color("baac86")))
	name_label = label("", 28)
	detail_column.add_child(name_label)
	intention_label = label("", 18)
	intention_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_column.add_child(intention_label)
	detail_column.add_child(label(tr_text("needs"), 15, Color("baac86")))
	needs_box = VBoxContainer.new()
	detail_column.add_child(needs_box)
	detail_column.add_child(label(tr_text("orders"), 15, Color("baac86")))
	orders_box = VBoxContainer.new()
	detail_column.add_child(orders_box)
	detail_column.add_child(label(tr_text("memories"), 15, Color("baac86")))
	memories_box = VBoxContainer.new()
	detail_column.add_child(memories_box)
	bottom_hud = panel()
	add_child(bottom_hud)
	var bottom_column := VBoxContainer.new()
	bottom_hud.add_child(bottom_column)
	bottom_column.add_child(label(tr_text("household"), 14, Color("baac86")))
	household = HBoxContainer.new()
	household.add_theme_constant_override("separation", 12)
	bottom_column.add_child(household)
	for resident: Dictionary in snapshot.residents:
		if not resident.household:
			continue
		var portrait := button(resident.display_name, select_and_follow.bind(resident.id))
		portrait.icon = load("res://assets/original/resident_%d.svg" % resident.id)
		portrait.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		portrait.expand_icon = true
		portrait.add_theme_constant_override("icon_max_width", 32)
		portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait.custom_minimum_size.y = 58
		household.add_child(portrait)
	receipt = label(tr_text("new_evening"), 17, Color("e4c48c"))
	receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_column.add_child(receipt)
	feed_panel = panel()
	feed_panel.visible = false
	add_child(feed_panel)
	var feed_column := VBoxContainer.new()
	feed_panel.add_child(feed_column)
	feed_column.add_child(label(tr_text("village"), 14, Color("baac86")))
	feed = RichTextLabel.new()
	feed.custom_minimum_size.y = 65
	feed.scroll_following = true
	feed_column.add_child(feed)
	menu = PopupMenu.new()
	menu.id_pressed.connect(menu_action)
	add_child(menu)
	sound = AudioStreamPlayer.new()
	sound.stream = load("res://assets/click-a.ogg")
	sound.volume_db = -15
	add_child(sound)
	top_hud.resized.connect(responsive_layout)
	bottom_hud.resized.connect(responsive_layout)


func responsive_layout() -> void:
	if top_hud == null or bottom_hud == null:
		return
	var is_narrow: bool = size.x < 900
	if narrow != is_narrow:
		narrow = is_narrow
		details.visible = not narrow
		feed_panel.visible = false
	details_button.visible = true
	var inset: float = 12.0
	var usable: float = maxf(300.0, size.x - inset * 2)
	top_hud.position = Vector2(inset, inset)
	top_hud.size = Vector2(usable, top_hud.get_combined_minimum_size().y)
	bottom_hud.size = Vector2(minf(640, usable), bottom_hud.get_combined_minimum_size().y)
	bottom_hud.position = Vector2(inset, size.y - bottom_hud.size.y - inset)
	var upper: float = top_hud.position.y + top_hud.size.y + inset
	var lower: float = bottom_hud.position.y - inset
	details.position = Vector2(inset if narrow else size.x - 312, upper)
	details.size = Vector2(usable if narrow else 300.0, maxf(120, lower - upper))
	feed_panel.size = Vector2(minf(400, usable), 130)
	feed_panel.position = Vector2(inset, maxf(upper, lower - feed_panel.size.y))
	viewport_panel.visible = true


func toggle_details() -> void:
	details.visible = not details.visible
	responsive_layout()


func click_sound() -> void:
	if sound != null and not muted and DisplayServer.get_name() != "headless":
		sound.pitch_scale = randf_range(0.94, 1.06)
		sound.play()


func _process(delta: float) -> void:
	if not ready_ok:
		return
	accumulator += delta * speed
	var consumed: int = 0
	while accumulator >= 0.25 and consumed < 64:
		previous = snapshot
		simulation.advance_tick()
		snapshot = simulation.developer_snapshot() if developer else simulation.cottage_snapshot()
		accumulator -= 0.25
		consumed += 1
	if consumed > 0:
		view.set_snapshot(snapshot, previous)
		refresh_ui()
		consume_feedback()
	view.alpha = clampf(accumulator / 0.25, 0, 1)
	view.queue_redraw()
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		direction.y += 1
	if direction != Vector2.ZERO:
		view.pan -= direction * 400 * delta
		view.follow = false
		view.constrain_pan()
	place_picker.select(place_picker.get_item_index(view.place))
	follow_button.set_pressed_no_signal(view.follow)


func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_ok or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F5:
			save_evening()
		KEY_F9:
			load_evening()
		KEY_F3:
			developer = not developer
			snapshot = (
				simulation.developer_snapshot() if developer else simulation.cottage_snapshot()
			)
			previous = snapshot
			view.set_snapshot(snapshot, previous)
			refresh_ui()
		KEY_SPACE:
			speed = 1 if speed == 0 else 0
		KEY_1:
			select_resident(1)
		KEY_2:
			select_resident(2)
		KEY_TAB:
			select_resident(2 if selected == 1 else 1)
		KEY_F:
			view.follow = not view.follow
		KEY_ESCAPE:
			menu.hide()
		KEY_BRACKETLEFT:
			view.switch_place(posmod(view.place - 1, snapshot.places.size()))
		KEY_BRACKETRIGHT:
			view.switch_place((view.place + 1) % snapshot.places.size())


func clear_box(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()


func refresh_ui() -> void:
	clock_label.text = tr_text("clock") % [snapshot.time_of_day / 60, snapshot.time_of_day % 60]
	if developer:
		clock_label.text += " · " + tr_text("developer")
	var resident: Dictionary = {}
	for r: Dictionary in snapshot.residents:
		if r.id == selected:
			resident = r
	if resident.is_empty() or not resident.has("private"):
		return
	name_label.text = resident.display_name
	var private: Dictionary = resident.private
	intention_label.text = (
		tr_text("intention")
		+ (
			private.autonomous_intention
			if not private.autonomous_intention.is_empty()
			else tr_text("idle")
		)
	)
	clear_box(needs_box)
	for kind: String in VillageSimulation.NEEDS:
		if not private.needs.has(kind):
			continue
		var row := HBoxContainer.new()
		needs_box.add_child(row)
		var title := label(strings.need_labels[kind], 17)
		title.custom_minimum_size.x = 90
		row.add_child(title)
		var bar := ProgressBar.new()
		bar.max_value = 255
		bar.value = private.needs[kind].value
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 12
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("c49464") if bar.value >= 80 else Color("95ad86")
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		row.add_child(label(str(int(bar.value)), 15, Color("c2cbb5")))
	var signature := JSON.stringify(private.player_tasks)
	if status_signature != signature:
		status_signature = signature
		clear_box(orders_box)
		if private.player_tasks.is_empty():
			var empty := label(tr_text("empty_orders"), 16)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			orders_box.add_child(empty)
		for task: Dictionary in private.player_tasks:
			var row := VBoxContainer.new()
			orders_box.add_child(row)
			var name: String = (
				tr_text("move")
				if task.kind == VillageCommand.Kind.GO_TO
				else action_name(task.object, task.affordance)
			)
			var title := label(strings.states[task.status] + " · " + name, 16)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(title)
			row.add_child(button(tr_text("cancel"), cancel_order.bind(task.task)))

	clear_box(memories_box)
	var texts: Array[String] = []
	if private.attending_quiz:
		texts.append(tr_text("attending"))
	if not private.carrying.is_empty():
		texts.append(
			(
				tr_text("carry")
				+ content.index("items").get(private.carrying, {}).get(
					"display_name", private.carrying
				)
			)
		)
	if not private.role.is_empty():
		for coordinator: Dictionary in content.table("coordinators"):
			for role: Dictionary in coordinator.roles:
				if role.id == private.role:
					texts.append(tr_text("role") + role.display_name)
	for memory: Dictionary in private.memories.slice(0, 3):
		texts.append(strings.perceptions[memory.perception])
	for opinion: Dictionary in private.labels:
		texts.append(
			tr_text("about") + resident_name(opinion.about) + ": " + tr_text("inconsiderate")
		)
	for notice: String in snapshot.notices:
		texts.append(notice)
	if texts.is_empty():
		texts.append(tr_text("empty_memories"))
	for text: String in texts:
		var line := label(text, 16, Color("c3c9b6"))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		memories_box.add_child(line)


func select_resident(id: int) -> void:
	selected = id
	view.selected = id
	status_signature = "!"
	refresh_ui()
	view.queue_redraw()


func queue_move(tile: Dictionary) -> void:
	simulation.submit_player_command(VillageCommand.go_to(next_task, selected, tile))
	next_task += 1
	receipt.text = tr_text("pending")
	click_sound()


func open_menu(target: Dictionary, point: Vector2) -> void:
	menu_target = target.duplicate(true)
	menu.clear()
	menu.add_separator(target.display_name)
	for i: int in target.affordances.size():
		menu.add_item(target.affordances[i].display_name, i)
	menu.position = Vector2i(point)
	menu.popup()


func menu_action(index: int) -> void:
	if index < 0 or index >= menu_target.affordances.size():
		return
	simulation.submit_player_command(
		VillageCommand.use_object(
			next_task, selected, menu_target.id, menu_target.affordances[index].id
		)
	)
	next_task += 1
	receipt.text = tr_text("pending")
	click_sound()


func action_name(object: String, affordance: String) -> String:
	for target: Dictionary in snapshot.objects:
		if target.id == object:
			for action: Dictionary in target.affordances:
				if action.id == affordance:
					return action.display_name
	return tr_text("waiting")


func resident_name(id: int) -> String:
	for resident: Dictionary in snapshot.residents:
		if resident.id == id:
			return resident.display_name
	return ""


func consume_feedback() -> void:
	var batch := simulation.events_since(event_cursor, developer)
	event_cursor = batch.cursor
	for event: Dictionary in batch.events:
		if event.kind == "PlayerCommandAccepted":
			receipt.text = tr_text("accepted")
			continue
		if event.kind == "PlayerCommandRejected":
			receipt.text = tr_text("rejected")
			continue
		if event.kind in ["GoToWaited", "ObjectUseWaited", "NeedRecovered"]:
			continue
		var text: String = strings.events.get(event.kind, "")
		var who: int = event.data.get(
			"resident",
			event.data.get("cook", event.data.get("eater", event.data.get("shopper", 0)))
		)
		text = text.replace("{name}", resident_name(who))
		text = text.replace(
			"{action}", action_name(event.data.get("object", ""), event.data.get("affordance", ""))
		)
		if not text.is_empty():
			feed_lines.append(text)
			if feed_lines.size() > 60:
				feed_lines.pop_front()
	feed.text = "\n".join(feed_lines)


func save_evening() -> void:
	receipt.text = (
		tr_text("saved") if VillageSave.write_slot(simulation) == OK else tr_text("save_failed")
	)


func load_evening() -> void:
	var restored := VillageSave.read_slot(content)
	if restored == null:
		receipt.text = tr_text("load_failed")
		return
	simulation = restored
	snapshot = simulation.developer_snapshot() if developer else simulation.cottage_snapshot()
	previous = snapshot.duplicate(true)
	accumulator = 0
	event_cursor = simulation.events_since(0).cursor
	next_task = 1
	next_task = simulation.next_player_task_id()
	status_signature = "!"
	feed_lines.clear()
	feed.text = ""
	view.set_snapshot(snapshot, previous)
	refresh_ui()
	receipt.text = tr_text("loaded")


func change_zoom(change: int) -> void:
	view.zoom_level = clampi(view.zoom_level + change, 1, 4)
	view.constrain_pan()


func select_and_follow(id: int) -> void:
	select_resident(id)
	for resident: Dictionary in snapshot.residents:
		if resident.id == id:
			view.switch_place(resident.position.place)
	view.follow = true
	follow_button.set_pressed_no_signal(true)


func cancel_order(task: int) -> void:
	simulation.submit_player_command(VillageCommand.cancel(task))
	receipt.text = tr_text("pending")
