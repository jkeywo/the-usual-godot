class_name HouseholdHud
extends RefCounted


static func build(game: Control) -> void:
	game.top_hud = game.panel()
	game.add_child(game.top_hud)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 4)
	game.top_hud.add_child(toolbar)
	game.place_picker = OptionButton.new()
	game.place_picker.custom_minimum_size = Vector2(160, 36)
	for place: Dictionary in game.snapshot.places:
		game.place_picker.add_item(place.display_name, place.place)
	game.place_picker.item_selected.connect(
		func(index: int) -> void:
			game.view.switch_place(game.place_picker.get_item_id(index))
			game.follow_button.set_pressed_no_signal(false)
	)
	toolbar.add_child(game.place_picker)
	game.follow_button = game.button(
		game.tr_text("follow"), func() -> void: game.view.follow = game.follow_button.button_pressed
	)
	game.follow_button.toggle_mode = true
	toolbar.add_child(game.follow_button)
	toolbar.add_child(game.button("-", game.change_zoom.bind(-1)))
	toolbar.add_child(game.button("+", game.change_zoom.bind(1)))
	toolbar.add_child(
		game.button(
			game.tr_text("options"),
			func() -> void: game.settings_panel.visible = not game.settings_panel.visible
		)
	)

	game.bottom_hud = game.panel()
	game.add_child(game.bottom_hud)
	var time_column := VBoxContainer.new()
	game.bottom_hud.add_child(time_column)
	var clock_row := HBoxContainer.new()
	time_column.add_child(clock_row)
	clock_row.add_child(game.label(game.tr_text("live_mode"), 14, Color("c2e493")))
	game.clock_label = game.label("", 22)
	game.clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	clock_row.add_child(game.clock_label)
	game.hover_label = game.label(game.tr_text("day"), 14, Color("aebfce"))
	game.hover_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	time_column.add_child(game.hover_label)
	var speeds := HBoxContainer.new()
	time_column.add_child(speeds)
	for rate: int in [0, 1, 4, 16]:
		var rate_button: Button = game.button(
			game.tr_text("paused") if rate == 0 else str(rate) + "×",
			func() -> void: game.speed = rate
		)
		rate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		speeds.add_child(rate_button)
	var actions := HBoxContainer.new()
	time_column.add_child(actions)
	game.details_button = game.button(game.tr_text("details_toggle"), game.toggle_details)
	actions.add_child(game.details_button)
	actions.add_child(
		game.button(
			game.tr_text("feed_toggle"),
			func() -> void: game.feed_panel.visible = not game.feed_panel.visible
		)
	)
	game.receipt = game.label(game.tr_text("new_evening"), 14, Color("c2e493"))
	game.receipt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.receipt.custom_minimum_size.y = 32
	time_column.add_child(game.receipt)

	game.household_panel = game.panel()
	game.add_child(game.household_panel)
	game.household = BoxContainer.new()
	game.household.vertical = true
	game.household_panel.add_child(game.household)
	for resident: Dictionary in game.snapshot.residents:
		if not resident.household:
			continue
		var portrait: Button = game.button("", game.select_and_follow.bind(resident.id))
		portrait.icon = game.view.characters.portrait(resident.definition_id)
		portrait.expand_icon = true
		portrait.add_theme_constant_override("icon_max_width", 44)
		portrait.custom_minimum_size = Vector2(58, 58)
		portrait.tooltip_text = resident.display_name + " · " + game.tr_text("portrait_hint")
		portrait.toggle_mode = true
		portrait.set_meta("resident_id", resident.id)
		game.household.add_child(portrait)

	game.details = game.panel()
	game.add_child(game.details)
	game.detail_body = BoxContainer.new()
	game.detail_body.add_theme_constant_override("separation", 12)
	game.details.add_child(game.detail_body)
	var identity := HBoxContainer.new()
	identity.custom_minimum_size.x = 210
	game.detail_body.add_child(identity)
	game.selected_portrait = TextureRect.new()
	game.selected_portrait.custom_minimum_size = Vector2(80, 80)
	game.selected_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game.selected_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	game.selected_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	identity.add_child(game.selected_portrait)
	var identity_text := VBoxContainer.new()
	identity_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(identity_text)
	identity_text.add_child(game.label(game.tr_text("household"), 12, Color("aebfce")))
	game.name_label = game.label("", 22)
	game.name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_text.add_child(game.name_label)
	game.intention_label = game.label("", 15, Color("c2e493"))
	game.intention_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_text.add_child(game.intention_label)
	game.detail_tabs = TabContainer.new()
	game.detail_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.detail_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game.detail_tabs.custom_minimum_size = Vector2(330, 150)
	game.detail_body.add_child(game.detail_tabs)
	game.needs_box = GridContainer.new()
	game.needs_box.columns = 2
	game.needs_box.add_theme_constant_override("h_separation", 14)
	game.needs_box.add_theme_constant_override("v_separation", 10)
	game.orders_box = VBoxContainer.new()
	game.memories_box = VBoxContainer.new()
	for spec: Array in [
		["needs_tab", game.needs_box],
		["orders_tab", game.orders_box],
		["mind_tab", game.memories_box]
	]:
		var scroll := ScrollContainer.new()
		scroll.name = game.tr_text(spec[0])
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		game.detail_tabs.add_child(scroll)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(column)
		column.add_child(spec[1])

	game.settings_panel = game.panel()
	game.settings_panel.visible = false
	game.add_child(game.settings_panel)
	var options := VBoxContainer.new()
	game.settings_panel.add_child(options)
	options.add_child(game.label(game.tr_text("title"), 20, Color("c2e493")))
	options.add_child(game.button(game.tr_text("save"), game.save_evening))
	options.add_child(game.button(game.tr_text("load"), game.load_evening))
	options.add_child(game.button(game.tr_text("outfit_toggle"), game.change_outfit))
	game.audio_button = game.button(game.tr_text("audio_on"), game.toggle_audio)
	options.add_child(game.audio_button)
	options.add_child(
		game.button(game.tr_text("close_menu"), func() -> void: game.settings_panel.hide())
	)
	game.feed_panel = game.panel()
	game.feed_panel.visible = false
	game.add_child(game.feed_panel)
	var feed_column := VBoxContainer.new()
	game.feed_panel.add_child(feed_column)
	feed_column.add_child(game.label(game.tr_text("village"), 14, Color("c2e493")))
	game.feed = RichTextLabel.new()
	game.feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game.feed.scroll_following = true
	feed_column.add_child(game.feed)

	game.queue_panel = game.panel()
	game.add_child(game.queue_panel)
	var queue_scroll := ScrollContainer.new()
	queue_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game.queue_panel.add_child(queue_scroll)
	game.queue_box = HBoxContainer.new()
	queue_scroll.add_child(game.queue_box)
	game.queue_panel.hide()


static func layout(game: Control) -> void:
	if game.top_hud == null:
		return
	var is_narrow: bool = game.size.x < 1000
	if game.narrow != is_narrow:
		game.narrow = is_narrow
		game.details.visible = not is_narrow
		game.feed_panel.hide()
	var inset := 10.0
	var usable: float = maxf(300.0, game.size.x - 2 * inset)
	game.top_hud.size = Vector2(minf(500, usable), game.top_hud.get_combined_minimum_size().y)
	game.top_hud.position = Vector2(game.size.x - game.top_hud.size.x - inset, inset)
	game.bottom_hud.size = Vector2(
		usable if is_narrow else maxf(250.0, game.bottom_hud.get_combined_minimum_size().x),
		game.bottom_hud.get_combined_minimum_size().y
	)
	game.bottom_hud.position = Vector2(inset, game.size.y - game.bottom_hud.size.y - inset)
	game.household.vertical = not is_narrow
	game.household_panel.size = game.household_panel.get_combined_minimum_size()
	game.household_panel.position = Vector2(
		inset, game.bottom_hud.position.y - game.household_panel.size.y - 8
	)
	game.detail_body.vertical = is_narrow
	game.selected_portrait.custom_minimum_size = Vector2(56, 56) if is_narrow else Vector2(80, 80)
	game.details.size = Vector2(
		usable if is_narrow else usable - game.bottom_hud.size.x - 10.0, 300 if is_narrow else 200
	)
	game.details.position = Vector2(
		inset if is_narrow else inset + game.bottom_hud.size.x + 10.0,
		(
			game.bottom_hud.position.y - game.details.size.y - 8
			if is_narrow
			else game.size.y - game.details.size.y - inset
		)
	)
	game.settings_panel.size = Vector2(
		minf(260, usable), game.settings_panel.get_combined_minimum_size().y
	)
	game.settings_panel.position = Vector2(
		game.size.x - game.settings_panel.size.x - inset,
		game.top_hud.position.y + game.top_hud.size.y + 8
	)
	game.feed_panel.size = Vector2(minf(360, usable), 220)
	game.feed_panel.position = Vector2(
		game.size.x - game.feed_panel.size.x - inset,
		game.top_hud.position.y + game.top_hud.size.y + 8
	)
	game.queue_panel.position = Vector2(
		inset, game.top_hud.position.y + game.top_hud.size.y + 8 if is_narrow else inset
	)
	game.queue_panel.size = Vector2(
		usable if is_narrow else minf(600, usable - game.top_hud.size.x - 10), 92
	)
	game.viewport_panel.visible = true
