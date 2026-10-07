class_name SimulationTests
extends RefCounted

const TOILET := "object.cottage_toilet"
const USE := "affordance.use_toilet"
const SLOT := "object.cottage_toilet/slot.use"

var failures: Array[String] = []
var passed: Array[String] = []
var content: VillageContent


func check(name: String, condition: bool) -> void:
	if condition:
		if not name in passed:
			passed.append(name)
	else:
		failures.append(name)
		push_error("FAIL: " + name)


func fresh(quiet: bool = false) -> VillageSimulation:
	var sim := VillageSimulation.create(content)
	if quiet:
		for who: int in sim.state.residents:
			for need: Dictionary in sim.state.residents[who].needs.values():
				need.value = 0
				need.decay_per_tick = 0
	return sim


func advance(sim: VillageSimulation, count: int) -> void:
	for i: int in count:
		sim.advance_tick()


func until_event(sim: VillageSimulation, kind: String, limit: int = 250) -> bool:
	for i: int in limit:
		if has_event(sim, kind):
			return true
		sim.advance_tick()
	return has_event(sim, kind)


func has_event(sim: VillageSimulation, kind: String) -> bool:
	return sim.state.ledger.any(func(e: Dictionary) -> bool: return e.kind == kind)


func tile(place: int, x: int, y: int) -> Dictionary:
	return {"place": place, "x": x, "y": y}


func reference_events(name: String) -> Array:
	var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/reference/" + name + ".json")
	)
	var events: Array = raw.event_ledger if raw is Dictionary else raw
	var result: Array = []
	for e: Dictionary in events:
		var data: Dictionary = integer_values(e.kind.value)
		if e.kind.kind == "TickCompleted":
			data.keyed_marker = str(data.keyed_marker)
		result.append({"tick": int(e.tick), "kind": e.kind.kind, "data": data})
	return result


func same_events(a: Array, b: Array) -> bool:
	# JSON normalizes the integer widths without changing ordering.
	if a == b:
		return true
	print("Trace sizes: ", a.size(), " / ", b.size())
	for i: int in mini(a.size(), b.size()):
		if a[i] != b[i]:
			print("First difference at ", i, ": actual ", a[i], " expected ", b[i])
			break
	return false


func run() -> Dictionary:
	content = VillageContent.load_default()
	check("content_valid", content.errors.is_empty())
	if not content.errors.is_empty():
		return report()
	test_basics()
	test_navigation()
	test_orders()
	test_autonomy()
	test_social()
	test_initiatives()
	test_saves()
	test_validation()
	test_reference()
	return report()


func report() -> Dictionary:
	var source: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/source_tests.json")
	)
	var missing: Array = []
	for test: Dictionary in source.tests:
		if not test.name in passed:
			missing.append(test.name)
	return {"passed": passed, "failures": failures, "missing_source_tests": missing}


func test_basics() -> void:
	var sim := fresh()
	check(
		"cottage_fixture_assigns_readable_definitions_and_monotonic_sim_ids",
		sim.state.residents[1].definition_id == "person.newcomer_a" and sim.state.next_id == 5
	)
	check(
		"embedded_content_matches_the_on_disk_fixture",
		(
			content.table("maps").size() == 1
			and content.table("plans").size() == 13
			and content.domains.size() == 12
		)
	)
	var snapshot := sim.cottage_snapshot()
	check(
		"the_snapshot_withholds_an_outsiders_inner_life", not snapshot.residents[2].has("private")
	)
	check(
		"the_developer_projection_shows_everyone",
		sim.developer_snapshot().residents[2].has("private")
	)
	check(
		"cottage_snapshot_exposes_authoritative_status_for_a_resident_card",
		snapshot.residents[0].private.needs.Toilet.value == 10
	)
	snapshot.residents[0].position.x = 99
	snapshot.residents[0].private.needs.Toilet.value = 99
	check(
		"snapshots_are_detached",
		sim.state.residents[1].position.x == 1 and sim.state.residents[1].needs.Toilet.value == 10
	)
	var before := sim.time_of_day()
	sim.advance_tick()
	check(
		"in_world_clock_advances_one_minute_per_tick_from_authored_start",
		before == 960 and sim.time_of_day() == 961
	)
	check(
		"published_events_are_only_observable_on_the_next_tick",
		sim.state.ingested.is_empty() and sim.state.pending.size() == 1
	)
	sim.advance_tick()
	check("deferred_events_ingest", sim.state.ingested[0].tick == 1)
	sim.state.tick = 480
	check("time_of_day_maps_and_wraps_across_a_day", sim.time_of_day() == 0)
	var vectors: Array = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/reference/draw.json")
	)
	for v: Array in vectors:
		check("mixer_" + v[0] + "_" + v[1], KeyedDraw.draw(v[0], v[1], v[1]) == v[2])
	var a := fresh()
	var b := fresh()
	advance(a, 30)
	advance(b, 30)
	check("fixed_seed_fixture_has_repeatable_seed_derived_events", a.state.ledger == b.state.ledger)


func test_navigation() -> void:
	var sim := fresh(true)
	var upstairs := tile(1, 5, 6)
	sim.begin_go_to(1, upstairs)
	advance(sim, 40)
	check(
		"go_to_uses_the_paired_stair_portal_and_emits_arrival",
		sim.state.residents[1].position == upstairs and has_event(sim, "GoToArrived")
	)
	var pub := tile(2, 8, 6)
	sim.begin_go_to(1, pub)
	advance(sim, 80)
	check(
		"a_resident_can_travel_from_the_cottage_to_the_kings_head_bar",
		sim.state.residents[1].position == pub
	)
	check(
		"a_solid_fixture_cannot_be_walked_through_or_stood_on",
		(
			not sim.walkable(sim.objects["object.cottage_stove"].position)
			and (
				sim
				. find_path(tile(0, 1, 1), sim.objects["object.cottage_stove"].position)
				. is_empty()
			)
		)
	)
	sim = fresh(true)
	sim.begin_go_to(1, tile(0, 0, 0))
	sim.advance_tick()
	check("impossible_go_to_emits_a_semantic_failure", has_event(sim, "GoToFailed"))
	for mode: int in 3:
		sim = fresh(true)
		sim.state.residents[1].position = tile(2, 4, 4)
		sim.state.residents[2].position = tile(2, 6, 4)
		if mode == 2:
			sim.state.tick = 1
		sim.begin_go_to(2, tile(2, 5, 4), 10 if mode == 1 else 0)
		if mode == 2:
			sim.state.tick = 2
		sim.begin_go_to(1, tile(2, 5, 4))
		sim.advance_tick()
		var winner: int = 1 if mode == 0 else 2
		check(
			[
				"lower_sim_id_wins_an_equal_priority_and_age_shared_live_tile_claim",
				"higher_priority_approach_claim_wins_a_shared_live_tile",
				"older_approach_claim_wins_a_shared_live_tile_before_sim_id"
			][mode],
			sim.occupied(tile(2, 5, 4)) == winner
		)
		check(
			"movement_never_overlaps_" + str(mode),
			sim.state.residents[1].position != sim.state.residents[2].position
		)
	sim = fresh(true)
	sim.state.residents[1].position = tile(2, 4, 4)
	sim.state.residents[2].position = tile(2, 5, 4)
	sim.begin_go_to(1, tile(2, 5, 4))
	sim.advance_tick()
	check(
		"live_tile_occupancy_waits_without_reserving_future_tiles",
		has_event(sim, "GoToWaited") and sim.state.residents[1].position == tile(2, 4, 4)
	)
	sim.begin_go_to(1, tile(2, 7, 4))
	advance(sim, 12)
	check(
		"go_to_replans_when_another_resident_blocks_its_next_step",
		sim.state.residents[1].position == tile(2, 7, 4)
	)
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.go_to(1, 1, tile(0, 4, 1)))
	check("deferred_move_before_tick", sim.state.walks.is_empty())
	advance(sim, 4)
	check(
		"deferred_player_ground_move_uses_the_live_navigation_path",
		sim.state.residents[1].position == tile(0, 4, 1)
	)


func test_orders() -> void:
	var sim := fresh(true)
	sim.submit_player_command(VillageCommand.use_object(10, 1, TOILET, USE))
	check(
		"command_submission_has_no_claims",
		sim.state.slots.is_empty() and sim.state.ledger.is_empty()
	)
	sim.advance_tick()
	check(
		"player_command_is_validated_next_tick_and_receipt_is_deferred",
		has_event(sim, "PlayerCommandAccepted") and sim.state.ingested.is_empty()
	)
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.use_object(11, 1, "missing", USE))
	sim.advance_tick()
	check(
		"invalid_player_command_is_rejected_without_claims",
		has_event(sim, "PlayerCommandRejected") and sim.state.slots.is_empty()
	)
	sim.submit_player_command(VillageCommand.use_object(12, 1, TOILET, "missing"))
	sim.advance_tick()
	check(
		"a_player_order_still_rejects_an_affordance_the_object_does_not_have",
		not sim.state.tasks.has(12)
	)
	sim.submit_player_command(VillageCommand.go_to(13, 3, tile(3, 10, 2)))
	sim.advance_tick()
	check("the_neighbour_takes_no_player_orders", not sim.state.tasks.has(13))
	sim = fresh(true)
	var bar: Dictionary = sim.objects["object.kings_head_bar"]
	sim.submit_player_command(VillageCommand.use_object(14, 1, bar.id, bar.affordances[0].id))
	sim.advance_tick()
	check("a_player_order_accepts_any_authored_affordance", sim.state.tasks.has(14))
	advance(sim, 150)
	check(
		"the_household_can_be_ordered_to_use_the_pub_fixtures",
		sim.state.tasks[14] == "Completed" and sim.state.residents[1].position.place == 2
	)
	for mode: int in 3:
		sim = fresh(true)
		sim.begin_use(2, TOILET, USE, 2 if mode == 1 else 0, 1000)
		if mode == 2:
			sim.state.tick = 1
		sim.begin_use(1, TOILET, USE, 0, 1000)
		check(
			"object_requests_do_not_claim_a_slot_or_capability_before_execution",
			sim.state.slots.is_empty() and sim.state.capabilities.is_empty()
		)
		sim.advance_tick()
		check(
			[
				"object_claim_order_is_priority_then_request_age_then_sim_id",
				"higher_priority_request_wins_the_same_tick_contention",
				"older_object_request_wins"
			][mode],
			sim.state.slots[SLOT] == (1 if mode == 0 else 2)
		)
		sim.advance_tick()
		check(
			"contested_toilet_waits_then_retries_after_execution_releases_claims",
			sim.state.slots[SLOT] == (2 if mode == 0 else 1)
		)
	sim = fresh(true)
	sim.state.residents[1].position = tile(0, 3, 1)
	sim.submit_player_command(VillageCommand.use_object(20, 1, TOILET, USE))
	sim.advance_tick()
	sim.submit_player_command(VillageCommand.cancel(20))
	sim.advance_tick()
	check(
		"cancelling_an_active_player_task_releases_claims_without_completion",
		(
			sim.state.tasks[20] == "Cancelled"
			and sim.state.slots.is_empty()
			and not has_event(sim, "ObjectUseCompleted")
		)
	)
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.go_to(21, 1, tile(0, 4, 1)))
	sim.submit_player_command(VillageCommand.cancel(21))
	sim.advance_tick()
	check(
		"queued_player_task_can_be_cancelled_before_execution",
		sim.state.tasks[21] == "Cancelled" and sim.state.walks.is_empty()
	)
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.go_to(22, 1, tile(0, 4, 1)))
	sim.submit_player_command(VillageCommand.go_to(23, 1, tile(0, 1, 1)))
	advance(sim, 3)
	check(
		"two_queued_player_orders_execute_in_fifo_order",
		sim.state.tasks[22] == "Completed" and sim.state.tasks[23] == "Queued"
	)
	advance(sim, 3)
	check("queue_drains", sim.state.tasks[23] == "Completed")
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.go_to(24, 1, tile(0, 4, 1)))
	sim.submit_player_command(VillageCommand.go_to(25, 1, tile(0, 1, 1)))
	sim.advance_tick()
	sim.submit_player_command(VillageCommand.cancel(25))
	sim.advance_tick()
	check(
		"a_non_head_queued_task_cancels_without_disturbing_the_head",
		sim.state.tasks[25] == "Cancelled" and sim.state.tasks[24] == "Active"
	)
	sim.submit_player_command(VillageCommand.go_to(26, 1, tile(0, 1, 1)))
	sim.submit_player_command(VillageCommand.cancel(24))
	sim.advance_tick()
	check(
		"cancelling_the_active_head_dispatches_the_next_queued_task",
		sim.state.tasks[24] == "Cancelled" and sim.state.tasks[26] in ["Active", "Completed"]
	)
	sim = fresh(true)
	sim.state.residents[1].needs.Toilet.value = 60
	sim.submit_player_command(VillageCommand.use_object(27, 1, TOILET, USE))
	until_event(sim, "ObjectUseStarted")
	check(
		"player_toilet_order_suppresses_a_competing_autonomous_request",
		(
			sim.state.tasks[27] == "Active"
			and (
				(
					sim
					. state
					. ledger
					. filter(func(e: Dictionary) -> bool: return e.kind == "ObjectUseStarted")
					. size()
				)
				== 1
			)
		)
	)


func test_autonomy() -> void:
	var sim := fresh(true)
	sim.state.residents[1].needs.Toilet.value = 65
	sim.advance_tick()
	check(
		"the_most_pressing_need_wins_and_then_keeps_its_resident",
		sim.state.plans[1].intention == "intention.relieve_yourself"
	)
	sim.state.residents[1].needs.Hunger.value = 255
	sim.advance_tick()
	check(
		"a_far_more_pressing_need_still_overrides_what_somebody_started",
		sim.state.plans[1].intention == "intention.eat"
	)
	sim = fresh(true)
	sim.state.residents[1].needs.Toilet.value = 65
	until_event(sim, "ObjectUseStarted")
	check("recovery_waits_for_completion", sim.state.residents[1].needs.Toilet.value == 65)
	sim.advance_tick()
	check(
		"autonomous_toilet_need_uses_human_plan_and_recovers_only_on_completion",
		sim.state.residents[1].needs.Toilet.value == 0 and has_event(sim, "ObjectUseCompleted")
	)
	check(
		"toilet_intention_uses_its_own_hysteresis_before_completion_recovers_it",
		has_event(sim, "NeedRecovered")
	)
	sim = fresh(true)
	sim.state.residents[1].needs.Hunger.value = 100
	sim.state.residents[1].needs.Toilet.value = 20
	sim.begin_use(1, "object.cottage_stove", "affordance.make_a_meal", 0, 1000)
	advance(sim, 9)
	check(
		"non_toilet_object_completion_does_not_recover_toilet_need",
		sim.state.residents[1].needs.Toilet.value == 20
	)
	check(
		"an_affordance_answers_the_need_it_declares",
		sim.state.residents[1].needs.Hunger.value < 100
	)
	sim = fresh(true)
	sim.state.residents[1].needs.Hunger.value = 100
	until_event(sim, "MealPrepared")
	var meals: Array = sim.state.ledger.filter(
		func(e: Dictionary) -> bool: return e.kind == "MealPrepared"
	)
	var meal: Dictionary = meals[0]
	check(
		"somebody_hungry_cooks_the_best_thing_the_larder_can_supply",
		meal.data.recipe == "recipe.supper"
	)
	var quality: int = sim.state.quality[1]
	var plain := fresh(true)
	plain.state.stocks["object.cottage_larder"]["item.cheese"] = 0
	plain.cook(1, plain.recipes["recipe.supper"])
	check("cheese_makes_it_a_better_supper", quality > plain.state.quality[1])
	sim = fresh(true)
	sim.state.stocks["object.cottage_larder"]["item.pasta"] = 0
	check(
		"an_empty_cupboard_sends_somebody_to_the_next_best_thing",
		sim.resolve_conduct(1, "conduct.cook") == "plan.make_toast"
	)
	sim = fresh(true)
	sim.submit_player_command(VillageCommand.go_to(30, 1, tile(0, 4, 1)))
	sim.advance_tick()
	sim.state.residents[1].needs.Toilet.value = 90
	sim.advance_tick()
	check("urgent_queue_paused", sim.state.tasks[30] == "Paused")
	advance(sim, 30)
	check(
		"urgent_need_preempts_a_player_move_then_resumes_it",
		sim.state.tasks[30] == "Completed" and not has_event(sim, "GoToCancelled")
	)
	var larder := "object.cottage_larder"
	sim = fresh(true)
	var full := sim.cupboard_emptiness(larder)
	for item: String in sim.state.stocks[larder]:
		sim.state.stocks[larder][item] = 0
	check(
		"a_full_larder_reads_as_nothing_wanted_and_a_bare_one_as_everything",
		full == 0 and sim.cupboard_emptiness(larder) == 100
	)
	check(
		"an_empty_larder_is_an_appetite_like_any_other",
		sim.score_intention(1, content.index("intentions")["intention.get_the_shopping"]) > 0
	)
	advance(sim, 150)
	check("somebody_gets_the_shopping_in_without_being_told", has_event(sim, "CupboardRestocked"))
	var restock: Dictionary = sim.objects["object.shop_counter"].affordances[0].restocks
	for item: String in sim.state.stocks[larder]:
		sim.state.stocks[larder][item] = 0
	sim.restock(1, restock)
	check(
		"the_counter_fills_the_larder_back_to_its_authored_levels",
		sim.cupboard_emptiness(larder) == 0
	)
	sim.state.stocks[larder]["item.bread"] = 20
	sim.restock(1, restock)
	check(
		"coming_home_with_the_shopping_does_not_throw_out_what_was_there",
		sim.state.stocks[larder]["item.bread"] == 20
	)


func test_social() -> void:
	var sim := fresh(true)
	advance(sim, 60)
	check(
		"the_neighbour_calls_round_but_says_nothing_until_spoken_to",
		(
			sim.state.residents[3].position == tile(0, 11, 1)
			and not has_event(sim, "NeighbourInvitation")
		)
	)
	sim.begin_use(1, "person.neighbour", sim.objects["person.neighbour"].affordances[0].id)
	sim.advance_tick()
	advance(sim, 3)
	sim.begin_use(1, "person.neighbour", sim.objects["person.neighbour"].affordances[0].id)
	sim.advance_tick()
	check(
		"talking_to_the_neighbour_delivers_the_invitation_exactly_once",
		(
			(
				sim
				. state
				. ledger
				. filter(func(e: Dictionary) -> bool: return e.kind == "NeighbourInvitation")
				. size()
			)
			== 1
		)
	)
	advance(sim, 240)
	check(
		"the_invitation_commits_the_household_and_they_attend_after_it_starts",
		has_event(sim, "QuizArrived") and sim.state.residents[1].position.place == 2
	)
	sim = fresh(true)
	sim.deliver_invitation("person.neighbour")
	sim.state.tick = 180
	sim.submit_player_command(VillageCommand.go_to(40, 1, tile(0, 4, 1)))
	sim.advance_tick()
	check(
		"a_player_order_takes_precedence_over_the_quiz_commitment",
		sim.state.walks[1].task == 40 and sim.state.commitments.has(1)
	)
	sim = fresh(true)
	for who: int in [1, 2]:
		sim.state.residents[who].position = tile(2, who + 3, 5)
	sim.state.tick = 120
	sim.record_seat(1, tile(2, 4, 5))
	check(
		"taking_the_pargeter_seat_while_open_yields_distinct_perceptions_and_knowledge",
		(
			sim.state.memories[1][0].perception == "TookPargeterSeat"
			and sim.state.memories[2][0].perception == "WitnessedPargeterSeat"
			and "PargeterSeatCustom" in sim.state.knowledge
		)
	)
	check(
		"a_witnessed_slight_is_remembered_and_moves_the_witness_against_the_participant",
		sim.state.relationships["2:1"].Respect == -6 and not sim.state.relationships.has("1:2")
	)
	check(
		"one_slight_is_not_enough_but_repetition_settles_into_an_opinion", not sim.holds_label(2, 1)
	)
	sim.record_seat(1, tile(2, 4, 5))
	sim.record_seat(1, tile(2, 4, 5))
	sim.settle_beliefs()
	check("one_slight_is_not_enough_but_repetition_settles_into_an_opinion", sim.holds_label(2, 1))
	sim.state.beliefs["2:1"].confidence = 40
	sim.settle_beliefs()
	check("a_label_needs_a_higher_bar_to_apply_than_to_keep", sim.holds_label(2, 1))
	sim.state.beliefs["2:1"].confidence = 35
	sim.settle_beliefs()
	check("a_label_needs_a_higher_bar_to_apply_than_to_keep", not sim.holds_label(2, 1))
	advance(sim, 100)
	check("an_opinion_nobody_renews_lifts_on_its_own", not sim.holds_label(2, 1))
	check(
		"a_memory_fades_and_lapses_while_the_standing_it_left_remains",
		not sim.state.memories.has(2) and sim.state.relationships.has("2:1")
	)
	sim = fresh(true)
	sim.record_moment(1, 4, "WitnessedPargeterSeat", sim.social.witnessed_pargeter_seat)
	sim.record_moment(2, 4, "WitnessedPargeterSeat", sim.social.witnessed_pargeter_seat)
	advance(sim, 15)
	check(
		"a_moment_passes_while_the_memory_of_it_stays",
		not sim.state.moments.has(1) and sim.state.memories.has(1)
	)
	check(
		"a_thin_skinned_resident_holds_on_longer_than_a_forgiving_one",
		sim.state.memories[1][0].salience > sim.state.memories[2][0].salience
	)
	check(
		"weighted_decay_never_rounds_a_slow_forgetter_down_to_never",
		(
			VillageSimulation.weighted_decay(1, ["ThinSkinned"]) == 1
			and VillageSimulation.weighted_decay(0, ["ThinSkinned"]) == 0
		)
	)
	sim = fresh(true)
	sim.begin_use(1, "object.pargeter_seat", sim.objects["object.pargeter_seat"].affordances[0].id)
	sim.advance_tick()
	check(
		"taking_the_seat_before_the_pub_opens_carries_no_social_charge",
		not has_event(sim, "PargeterSeatTaken")
	)
	sim = fresh(true)
	for i: int in 3:
		sim.record_moment(1, 2, "WitnessedPargeterSeat", sim.social.witnessed_pargeter_seat)
	sim.settle_beliefs()
	sim.deliver_invitation("person.neighbour")
	check(
		"someone_who_disapproves_of_another_attendee_stands_further_off",
		sim.state.commitments[1].destination.x == 12
	)


func test_initiatives() -> void:
	var sim := fresh(true)
	var id: String = VillageSimulation.keys(sim.initiative_defs)[0]
	check(
		"an_initiative_is_posted_but_unknown_until_somebody_reads_the_board",
		not sim.notices().is_empty() and sim.cottage_snapshot().notices.is_empty()
	)
	sim.read_board(1)
	check(
		"reading_the_board_is_how_the_household_learn_of_it",
		not sim.cottage_snapshot().notices.is_empty() and has_event(sim, "NoticeRead")
	)
	var proposer := sim.resident_by_definition(sim.initiative_defs[id].proposer)
	sim.state.relationships[sim.relationship_key(1, proposer)] = {"Respect": 12, "Trust": 8}
	check(
		"a_stance_comes_from_what_somebody_already_holds",
		sim.stance_strength(1, id) == 20 and sim.stance_strength(2, id) == 0
	)
	for who: int in [1, 2]:
		sim.state.relationships[sim.relationship_key(who, proposer)] = {"Respect": 20}
		sim.speak(who, id)
	var original: String = sim.state.initiatives[id].stage
	sim.advance_tick()
	check(
		"enough_voices_carry_the_application",
		sim.state.initiatives[id].stage != original and has_event(sim, "InitiativeMoved")
	)
	check(
		"something_that_needs_several_people_hands_out_a_role_each",
		sim.state.roles.size() == 2 and sim.state.roles[1] != sim.state.roles[2]
	)
	var assigned: int = (
		sim.state.ledger.filter(func(e: Dictionary) -> bool: return e.kind == "RoleAccepted").size()
	)
	sim.advance_coordinators()
	check(
		"a_coordinator_arranges_the_thing_once_rather_than_every_tick",
		(
			assigned
			== (
				sim
				. state
				. ledger
				. filter(func(e: Dictionary) -> bool: return e.kind == "RoleAccepted")
				. size()
			)
		)
	)
	sim.state.residents[1].needs.Hunger.value = 255
	sim.run_autonomy()
	check(
		"somebody_can_simply_not_turn_up",
		sim.state.plans[1].intention == "intention.eat" and sim.state.roles.has(1)
	)
	sim.state.residents[1].needs.Hunger.value = 0
	advance(sim, 140)
	check(
		"a_role_is_something_you_do_rather_than_a_state_you_are_put_into",
		has_event(sim, "RoleDischarged")
	)
	sim = fresh(true)
	sim.state.tick = 400
	sim.advance_initiatives()
	check(
		"a_meeting_nobody_spoke_at_lets_the_application_lapse",
		sim.state.initiatives[id].stage != original and has_event(sim, "InitiativeMoved")
	)


func test_saves() -> void:
	var sim := fresh()
	advance(sim, 37)
	var text := VillageSave.encode(sim)
	var restored := VillageSave.decode(text, content)
	check(
		"a_save_round_trips_through_its_stored_text",
		restored != null and restored.state == sim.state
	)
	if restored != null:
		advance(sim, 90)
		advance(restored, 90)
		check("a_village_saved_mid_plan_reloads_into_the_same_evening", sim.state == restored.state)
	check(
		"a_corrupted_save_is_refused_rather_than_half_loaded",
		VillageSave.decode(text.replace("payload", "broken"), content) == null
	)
	var changed := VillageContent.load_default()
	changed.fingerprint = "changed"
	check(
		"a_save_refuses_content_it_was_not_played_against",
		VillageSave.decode(text, changed) == null
	)
	for tick: int in [1, 30, 60, 120, 200]:
		sim = fresh()
		advance(sim, tick)
		restored = VillageSave.decode(VillageSave.encode(sim), content)
		if restored != null:
			advance(sim, 20)
			advance(restored, 20)
		check("resume_" + str(tick), restored != null and restored.state == sim.state)

	for scenario: String in ["movement", "contention", "cooking", "urgent", "initiative"]:
		sim = fresh()
		if scenario == "movement" or scenario == "urgent":
			sim.submit_player_command(VillageCommand.go_to(101, 1, tile(0, 4, 1)))
		elif scenario == "contention":
			sim.submit_player_command(VillageCommand.use_object(101, 1, TOILET, USE))
			sim.submit_player_command(VillageCommand.use_object(102, 2, TOILET, USE))
		elif scenario == "cooking":
			sim.state.residents[1].needs.Hunger.value = 90
		elif scenario == "initiative":
			advance(sim, 190)
		sim.advance_tick()
		if scenario == "urgent":
			sim.state.residents[1].needs.Toilet.value = 95
			sim.advance_tick()
		for checkpoint: int in 15:
			restored = VillageSave.decode(VillageSave.encode(sim), content)
			var valid: bool = restored != null
			if valid:
				var uninterrupted := VillageSave.decode(VillageSave.encode(sim), content)
				advance(restored, 30)
				advance(uninterrupted, 30)
				valid = restored.state == uninterrupted.state
			check("save_" + scenario + "_" + str(checkpoint), valid)
			sim.advance_tick()


func test_validation() -> void:
	var changed := VillageContent.load_default()
	changed.domains.scenarios[0].placements[1].position = (
		changed.domains.scenarios[0].placements[0].position.duplicate()
	)
	changed.validate()
	check(
		"duplicate_initial_placements_are_rejected",
		not changed.errors.is_empty() and VillageSimulation.create(changed) == null
	)
	changed = VillageContent.load_default()
	changed.domains.objects[0].objects[0].solid = true
	changed.domains.objects[0].objects[0].position = (
		changed.domains.maps[0].portals[0].from.duplicate()
	)
	changed.validate()
	check("solid_furniture_may_not_block_a_threshold", not changed.errors.is_empty())
	changed = VillageContent.load_default()
	changed.domains.intentions[0].intentions[0].conduct = "missing.conduct"
	changed.validate()
	check("an_intention_nobody_can_answer_is_refused_at_load", not changed.errors.is_empty())


func test_reference() -> void:
	var sim := fresh()
	for tick: int in 241:
		if tick in [0, 1, 2, 10, 30, 60, 120, 240]:
			var reference: Dictionary = integer_values(
				JSON.parse_string(
					FileAccess.get_file_as_string("res://tests/reference/autonomous_%d.json" % tick)
				)
			)
			var matches: bool = sim.state.tick == reference.tick
			for resident: Dictionary in reference.residents:
				matches = matches and sim.state.residents[resident.id].position == resident.position
			for need: Array in reference.needs:
				for field: String in need[2]:
					matches = (
						matches
						and sim.state.residents[need[0]].needs[need[1]][field] == need[2][field]
					)
			check("rust_snapshot_" + str(tick), matches)
		sim.advance_tick()
	sim = fresh()
	advance(sim, 240)
	check(
		"rust_autonomous_240_tick_trace",
		same_events(sim.state.ledger, reference_events("autonomous_240"))
	)
	sim = fresh()
	sim.submit_player_command(VillageCommand.go_to(201, 1, tile(0, 4, 1)))
	sim.submit_player_command(VillageCommand.use_object(202, 1, TOILET, USE))
	sim.submit_player_command(VillageCommand.go_to(203, 1, tile(0, 1, 1)))
	sim.advance_tick()
	sim.state.residents[1].needs.Toilet.value = 90
	sim.submit_player_command(VillageCommand.cancel(203))
	advance(sim, 24)
	check(
		"queue_and_preemption_script_is_deterministic",
		same_events(sim.state.ledger, reference_events("queue_preemption"))
	)
	sim = fresh(true)
	sim.begin_go_to(1, tile(2, 7, 8))
	sim.begin_go_to(2, tile(2, 8, 7))
	advance(sim, 80)
	var arrived: bool = (
		sim.state.residents[1].position == tile(2, 7, 8)
		and sim.state.residents[2].position == tile(2, 8, 7)
	)
	sim.begin_use(1, "object.kings_head_bar", "affordance.order_drink", 1, 1000)
	sim.begin_use(2, "object.kings_head_bar", "affordance.order_drink", 0, 1000)
	advance(sim, 8)
	check(
		"two_residents_travel_to_the_pub_and_contend_for_the_single_bar_slot",
		(
			arrived
			and has_event(sim, "ObjectUseWaited")
			and (
				(
					sim
					. state
					. ledger
					. filter(func(e: Dictionary) -> bool: return e.kind == "ObjectUseCompleted")
					. size()
				)
				== 2
			)
		)
	)
	# The complete source contention script is exercised separately below.
	sim = fresh()
	var targets: Array = [[tile(1, 5, 6), tile(1, 6, 5)], [tile(0, 3, 1), tile(0, 2, 2)]]
	for pair: Array in targets:
		sim.begin_go_to(1, pair[0])
		sim.begin_go_to(2, pair[1])
		for i: int in 100:
			# Source helper holds needs down before every tick.
			for who: int in [1, 2]:
				for need: Dictionary in sim.state.residents[who].needs.values():
					need.value = 0
			sim.advance_tick()
			if (
				sim.state.residents[1].position == pair[0]
				and sim.state.residents[2].position == pair[1]
			):
				for who: int in [1, 2]:
					for need: Dictionary in sim.state.residents[who].needs.values():
						need.value = 0
				sim.advance_tick()
				break
	sim.begin_use(2, TOILET, USE, 0, 1000)
	sim.submit_player_command(VillageCommand.use_object(600, 1, TOILET, USE, 1))
	sim.advance_tick()
	sim.submit_player_command(VillageCommand.cancel(600))
	sim.advance_tick()
	sim.advance_tick()
	check(
		"cottage_contention_fixture_is_deterministic_and_semantically_complete",
		same_events(sim.state.ledger, reference_events("contention"))
	)


func integer_values(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(integer_values(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = integer_values(value[key])
		return result
	return value
