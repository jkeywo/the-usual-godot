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
var needs_box: GridContainer
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
var household: BoxContainer
var menu: PopupMenu
var menu_target: Dictionary = {}
var sound: AudioStreamPlayer
var narrow: bool = false
var status_signature: String = ""
var ready_ok: bool = false
var feed_lines: Array[String] = []
var pending_operations: Dictionary = {}
var waiting_messages: Dictionary = {}
var audio: VillageAudio
var audio_button: Button
var footstep_timer: float = 0.0
var cancelled_work: Dictionary = {}
var pending_crossings: Dictionary = {}
var household_panel: PanelContainer
var settings_panel: PanelContainer
var detail_body: BoxContainer
var detail_tabs: TabContainer
var selected_portrait: TextureRect
var queue_panel: PanelContainer
var queue_box: HBoxContainer
var interaction_menu: InteractionMenu


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
	view.zoom_level = 1 if size.x < 900 else 2
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
		audio.stop()
		sound.stop()
		sound.stream = null
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(
			0 if result.failures.is_empty() and result.missing_source_tests.is_empty() else 1
		)


func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233e55")
	style.border_color = Color("8babbc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.border_width_bottom = 4
	style.border_width_right = 4
	style.shadow_color = Color("142638")
	style.shadow_size = 3
	style.shadow_offset = Vector2(3, 3)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", style)
	return p


func label(text: String, font_size: int = 18, color: Color = Color("e8f0e7")) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 36
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
	t.default_font_size = 16
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("365b75")
	normal.border_color = Color("7299b1")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover := normal.duplicate()
	hover.bg_color = Color("4b7590")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("546e42")
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Color("ede7ce"))
	var focus := normal.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("c2e493")
	t.set_stylebox("focus", "Button", focus)
	for kind: String in ["OptionButton", "TabBar", "TabContainer"]:
		t.set_stylebox("normal" if kind == "OptionButton" else "tab_unselected", kind, normal)
		t.set_stylebox("hover" if kind == "OptionButton" else "tab_hovered", kind, hover)
		t.set_stylebox("pressed" if kind == "OptionButton" else "tab_selected", kind, pressed)
	var bank := normal.duplicate()
	bank.bg_color = Color("1b3043")
	bank.content_margin_top = 10
	bank.content_margin_bottom = 10
	t.set_stylebox("panel", "TabContainer", bank)
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
	HouseholdHud.build(self)
	menu = PopupMenu.new()
	menu.id_pressed.connect(menu_action)
	add_child(menu)
	interaction_menu = InteractionMenu.new()
	interaction_menu.game = self
	add_child(interaction_menu)
	sound = AudioStreamPlayer.new()
	sound.stream = load("res://assets/click-a.ogg")
	sound.volume_db = -15
	add_child(sound)
	audio = VillageAudio.new()
	add_child(audio)
	top_hud.resized.connect(responsive_layout)
	bottom_hud.resized.connect(responsive_layout)


func responsive_layout() -> void:
	HouseholdHud.layout(self)
	if interaction_menu != null:
		interaction_menu.arrange()


func toggle_details() -> void:
	details.visible = not details.visible
	responsive_layout()


func _input(event: InputEvent) -> void:
	if audio == null:
		return
	if (
		(event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey)
		and event.pressed
	):
		audio.unlock()


func click_sound() -> void:
	if audio != null:
		audio.play("click")


func toggle_audio() -> void:
	muted = not muted
	audio.set_muted(muted)
	audio_button.text = tr_text("audio_off" if muted else "audio_on")


func _process(delta: float) -> void:
	if not ready_ok:
		return
	view.animation_time += delta * minf(speed, 4)
	audio.set_place(view.place)
	footstep_timer += delta
	if speed > 0 and footstep_timer >= 0.3:
		footstep_timer = 0
		for resident: Dictionary in snapshot.residents:
			if (
				resident.id == selected
				and resident.position.place == view.place
				and resident.get("activity") == "walking"
			):
				audio.play("step")
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
		update_crossing_focus()
		refresh_ui()
		consume_feedback()
	view.alpha = clampf(accumulator / 0.25, 0, 1)
	view.update_follow()
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
			close_menu()
			settings_panel.hide()
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
	for portrait: Button in household.get_children():
		portrait.set_pressed_no_signal(portrait.get_meta("resident_id") == selected)
	var resident: Dictionary = {}
	for r: Dictionary in snapshot.residents:
		if r.id == selected:
			resident = r
	selected_portrait.texture = (
		null if resident.is_empty() else view.characters.portrait(resident.definition_id)
	)
	if resident.is_empty() or not resident.has("private"):
		name_label.text = resident.get("display_name", tr_text("no_selection"))
		intention_label.text = tr_text("outsider_card") if not resident.is_empty() else ""
		clear_box(needs_box)
		clear_box(orders_box)
		clear_box(queue_box)
		queue_panel.hide()
		clear_box(memories_box)
		status_signature = "!"
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
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		needs_box.add_child(row)
		var title := label(strings.need_labels[kind], 14)
		title.custom_minimum_size.x = 76
		row.add_child(title)
		var bar := ProgressBar.new()
		bar.max_value = 255
		bar.value = private.needs[kind].value
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(40, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("d79756") if bar.value >= 80 else Color("9cce6a")
		fill.set_corner_radius_all(0)
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		row.add_child(label(str(int(bar.value)), 15, Color("c2cbb5")))
	var signature := JSON.stringify(private.player_tasks)
	if status_signature != signature:
		status_signature = signature
		clear_box(orders_box)
		refresh_queue(private.player_tasks)
		if private.player_tasks.is_empty():
			var empty := label(tr_text("empty_orders"), 16)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			orders_box.add_child(empty)
		for index: int in private.player_tasks.size():
			var task: Dictionary = private.player_tasks[index]
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
			var actions := HFlowContainer.new()
			row.add_child(actions)
			var promote_button := button(
				tr_text("promote"), manage_order.bind(task.task, VillageCommand.Kind.PROMOTE, 0)
			)
			promote_button.disabled = index < 1
			promote_button.tooltip_text = tr_text("promote_hint")
			actions.add_child(promote_button)
			var force_button := button(
				tr_text("force"), manage_order.bind(task.task, VillageCommand.Kind.FORCE, 0)
			)
			force_button.disabled = index == 0 and task.status == "Active"
			force_button.tooltip_text = tr_text("force_hint")
			actions.add_child(force_button)
			for direction: int in [-1, 1]:
				var move_button := button(
					tr_text("move_up" if direction < 0 else "move_down"),
					manage_order.bind(task.task, VillageCommand.Kind.REORDER, index + direction)
				)
				move_button.disabled = (
					index == 0
					or index + direction < 1
					or index + direction >= private.player_tasks.size()
				)
				move_button.tooltip_text = tr_text("reorder_hint")
				actions.add_child(move_button)
			actions.add_child(button(tr_text("cancel"), cancel_order.bind(task.task)))

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


func refresh_queue(tasks: Array) -> void:
	clear_box(queue_box)
	queue_panel.visible = not tasks.is_empty()
	for task: Dictionary in tasks:
		var card := VBoxContainer.new()
		card.custom_minimum_size.x = 110
		queue_box.add_child(card)
		var heading := HBoxContainer.new()
		card.add_child(heading)
		var state_label := label(strings.states[task.status], 12, Color("c2e493"))
		state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(state_label)
		var cancel := button("X", cancel_order.bind(task.task))
		cancel.custom_minimum_size.y = 24
		cancel.tooltip_text = tr_text("cancel")
		heading.add_child(cancel)
		var title: String = (
			tr_text("move")
			if task.kind == VillageCommand.Kind.GO_TO
			else action_name(task.object, task.affordance)
		)
		var action_button := button(
			title,
			func() -> void:
				details.show()
				detail_tabs.current_tab = 1
				responsive_layout()
		)
		action_button.custom_minimum_size.x = 110
		card.add_child(action_button)


func select_resident(id: int) -> void:
	selected = id
	view.selected = id
	status_signature = "!"
	refresh_ui()
	view.queue_redraw()


func queue_move(tile: Dictionary) -> void:
	submit_order(VillageCommand.go_to(next_task, selected, tile), "accepted")
	next_task += 1
	receipt.text = tr_text("pending")
	click_sound()


func open_menu(target: Dictionary, point: Vector2) -> void:
	menu_target = target.duplicate(true)
	menu.clear()
	menu.add_separator(target.display_name)
	for i: int in target.affordances.size():
		menu.add_item(target.affordances[i].display_name, i)
	interaction_menu.open(target, point)


func close_menu() -> void:
	menu.hide()
	interaction_menu.hide()


func menu_action(index: int) -> void:
	if index < 0 or index >= menu_target.affordances.size():
		return
	if menu_target.has("destination"):
		pending_crossings[next_task] = {
			"resident": selected, "destination": menu_target.destination.duplicate(true)
		}
		queue_move(menu_target.destination)
		return
	submit_order(
		VillageCommand.use_object(
			next_task, selected, menu_target.id, menu_target.affordances[index].id
		),
		"accepted"
	)
	next_task += 1
	receipt.text = tr_text("pending")
	click_sound()


func update_crossing_focus() -> void:
	for task: int in pending_crossings.keys():
		var crossing: Dictionary = pending_crossings[task]
		for resident: Dictionary in snapshot.residents:
			if resident.id == crossing.resident and resident.position == crossing.destination:
				if selected == resident.id:
					if view.follow:
						view.update_follow()
					else:
						view.switch_place(resident.position.place)
				pending_crossings.erase(task)
				break


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
			var operations: Array = pending_operations.get(event.data.task, [])
			if operations.is_empty() or event.tick <= operations[0].tick:
				continue
			receipt.text = tr_text(
				operations.pop_front().feedback if not operations.is_empty() else "accepted"
			)
			audio.play("accept")
			continue
		if event.kind in ["PlayerCommandRejected", "TaskCancelled", "GoToCancelled"]:
			pending_crossings.erase(event.data.get("task", 0))
		if event.kind == "PlayerCommandRejected":
			var operations: Array = pending_operations.get(event.data.task, [])
			if not operations.is_empty():
				operations.pop_front()
			receipt.text = (
				tr_text("rejected") + " " + strings.rejection_reasons.get(event.data.reason, "")
			)
			audio.play("reject")
			continue
		var text: String = strings.events.get(event.kind, "")
		var who: int = event.data.get(
			"resident",
			event.data.get("cook", event.data.get("eater", event.data.get("shopper", 0)))
		)
		if event.kind in ["GoToWaited", "ObjectUseWaited"]:
			var key: String = event.kind + str(event.data.get("object", ""))
			if waiting_messages.get(who) == key:
				continue
			waiting_messages[who] = key
		elif who != 0:
			waiting_messages.erase(who)
		text = text.replace(
			"{need}", strings.need_labels.get(event.data.get("need", ""), tr_text("needs"))
		)
		text = text.replace("{name}", resident_name(who))
		text = text.replace(
			"{action}", action_name(event.data.get("object", ""), event.data.get("affordance", ""))
		)
		if event.kind in ["GoToCancelled", "TaskCancelled"]:
			if cancelled_work.get(event.data.get("task", 0), false):
				text = tr_text("queued_cancelled").replace("{name}", resident_name(who))
			cancelled_work.erase(event.data.get("task", 0))
			receipt.text = text
			audio.play("cancel")
		elif event.kind in ["ObjectUseCompleted", "GoToArrived"]:
			audio.play("complete")
		elif event.kind in ["NeighbourInvitation", "InitiativeMoved", "NoticeRead"]:
			audio.play("notice")
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
	pending_crossings.clear()
	snapshot = simulation.developer_snapshot() if developer else simulation.cottage_snapshot()
	previous = snapshot.duplicate(true)
	accumulator = 0
	event_cursor = simulation.events_since(0).cursor
	next_task = 1
	next_task = simulation.next_player_task_id()
	status_signature = "!"
	feed_lines.clear()
	pending_operations.clear()
	cancelled_work.clear()
	waiting_messages.clear()
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
	for resident: Dictionary in snapshot.residents:
		for queued: Dictionary in resident.get("private", {}).get("player_tasks", []):
			if queued.task == task:
				cancelled_work[task] = queued.status == "Queued"
	submit_order(VillageCommand.cancel(task), "cancel_accepted")
	receipt.text = tr_text("pending")


func submit_order(command: VillageCommand, feedback: String) -> void:
	if not pending_operations.has(command.task):
		pending_operations[command.task] = []
	pending_operations[command.task].append(
		{"feedback": feedback, "tick": simulation.cottage_snapshot().tick}
	)
	simulation.submit_player_command(command)


func manage_order(task: int, operation: VillageCommand.Kind, index: int) -> void:
	var feedback: String = "reorder_accepted"
	if operation == VillageCommand.Kind.PROMOTE:
		feedback = "promote_accepted"
	elif operation == VillageCommand.Kind.FORCE:
		feedback = "force_accepted"
	submit_order(VillageCommand.manage(task, operation, index), feedback)
	receipt.text = tr_text("pending")


func change_outfit() -> void:
	for resident: Dictionary in snapshot.residents:
		if resident.id == selected:
			var original: String = CharacterAnimation.PEOPLE.get(resident.definition_id, {}).get(
				"outfit", "sage"
			)
			var current: String = view.outfits.get(selected, original)
			view.change_outfit(selected, original if current == "navy" else "navy")
			return
