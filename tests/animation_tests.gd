class_name AnimationTests
extends RefCounted


static func run(game: Control, checks: Dictionary) -> void:
	var before: Dictionary = game.simulation.state.duplicate(true)
	var rig := CharacterAnimation.new()
	var assets_ok := true
	var frames_distinct := true
	var head_swap_ok := true
	for definition: String in CharacterAnimation.PEOPLE:
		for direction: int in 8:
			for clip_name: String in ["walk", "talk", "interact"]:
				var hashes: Array[String] = []
				for index: int in CharacterAnimation.COUNTS[clip_name]:
					var layers := rig.layers(
						definition,
						"navy",
						direction,
						clip_name,
						(index + 0.01) / CharacterAnimation.RATES[clip_name]
					)
					assets_ok = assets_ok and layers.body != null and layers.head != null
					if layers.body == null or layers.head == null:
						continue
					var image: Image = layers.body.get_image().get_region(Rect2i(layers.body_rect))
					hashes.append(image.get_data().hex_encode().sha256_text())
					var other := rig.layers(
						definition,
						"sage",
						direction,
						clip_name,
						(index + 0.01) / CharacterAnimation.RATES[clip_name]
					)
					head_swap_ok = (
						head_swap_ok
						and layers.head == other.head
						and layers.head_rect == other.head_rect
						and layers.head_offset == other.head_offset
						and layers.body != other.body
					)
				var unique: Dictionary = {}
				for hash_value: String in hashes:
					unique[hash_value] = true
				frames_distinct = (
					frames_distinct and unique.size() >= (8 if clip_name == "walk" else 4)
				)
	checks.all_characters_have_eight_direction_clips = assets_ok
	checks.walk_talk_and_interaction_have_distinct_poses = frames_distinct
	checks.outfits_share_head_anchors_and_keep_identity = head_swap_ok
	var direction_ok := true
	for direction: int in 8:
		var vector := Vector2.RIGHT.rotated(direction * PI / 4.0)
		direction_ok = direction_ok and CharacterAnimation.direction(vector) == direction
		var current: Dictionary = game.snapshot.duplicate(true)
		var old: Dictionary = game.snapshot.duplicate(true)
		current.residents[0].position = {
			"place": 0, "x": 5 + roundi(vector.x), "y": 5 - roundi(vector.y)
		}
		old.residents[0].position = {"place": 0, "x": 5, "y": 5}
		game.view.set_snapshot(current, old)
		direction_ok = direction_ok and game.view.facing[1] == direction
	checks.movement_snapshot_selects_all_eight_facings = direction_ok
	checks.standing_preserves_facing = CharacterAnimation.direction(Vector2.ZERO, 7) == 7
	checks.talk_and_use_route_to_separate_clips = (
		CharacterAnimation.clip("affordance.talk_to_landlord") == "talk"
		and CharacterAnimation.clip("affordance.make_a_meal") == "interact"
	)
	checks.walk_loop_wraps = (
		CharacterAnimation.frame("walk", 0.0) == CharacterAnimation.frame("walk", 0.8)
	)
	var conversation: Dictionary = game.snapshot.duplicate(true)
	conversation.residents[0].position = conversation.residents[2].position.duplicate()
	conversation.residents[0].position.x -= 1
	conversation.residents[0].activity = "affordance.talk"
	conversation.residents[0].activity_target = conversation.residents[2].position.duplicate()
	conversation.residents[2].activity = "idle"
	game.view.set_snapshot(conversation, conversation)
	checks.conversation_listener_gestures_without_private_data = (
		game.view.talking_to.has(3) and not conversation.residents[2].has("private")
	)
	var fresh := VillageSimulation.create(game.content)
	fresh.submit_player_command(
		VillageCommand.use_object(940, 1, "object.cottage_toilet", "affordance.use_toilet")
	)
	for tick: int in 30:
		fresh.advance_tick()
		if fresh.state.uses.has(1):
			break
	var projected: Dictionary = fresh.cottage_snapshot()
	var detached_target := false
	for resident: Dictionary in projected.residents:
		if resident.id == 1 and not resident.activity_target.is_empty():
			resident.activity_target.x = -999
			detached_target = fresh.objects["object.cottage_toilet"].position.x != -999
	checks.activity_target_is_detached = detached_target
	for resident: Dictionary in game.snapshot.residents:
		game.view.change_outfit(resident.id, "navy")
	checks.wardrobe_changes_are_presentation_only = before == game.simulation.state
	game.view.outfits.clear()
	game.view.set_snapshot(game.snapshot, game.previous)
