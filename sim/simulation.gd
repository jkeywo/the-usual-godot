class_name VillageSimulation
extends RefCounted

const NEEDS: Array[String] = ["Hunger", "Energy", "Toilet", "Hygiene", "Warmth", "Comfort"]
var content: VillageContent
var definitions: Dictionary = {}
var objects: Dictionary = {}
var map: Dictionary = {}
var plans: Dictionary = {}
var conducts: Dictionary = {}
var recipes: Dictionary = {}
var intentions: Array = []
var social: Dictionary = {}
var initiative_defs: Dictionary = {}
var coordinator_defs: Dictionary = {}
var state: Dictionary = {}


static func create(authored: VillageContent) -> VillageSimulation:
	if not authored.errors.is_empty():
		return null
	var sim := VillageSimulation.new()
	sim.content = authored
	sim.initialize()
	return sim


func initialize() -> void:
	definitions = content.index("people").duplicate(true)
	objects = content.index("objects").duplicate(true)
	map = content.table("maps")[0].duplicate(true)
	plans = content.index("plans")
	conducts = content.index("conducts")
	recipes = content.index("recipes")
	intentions = content.table("intentions")
	social = content.table("social")[0]
	initiative_defs = content.index("initiatives")
	coordinator_defs = content.index("coordinators")
	var scenario: Dictionary = content.table("scenarios")[0]
	state = {
		"tick": 0,
		"seed": str(scenario.seed),
		"start": minutes(scenario.start_time_of_day),
		"residents": {},
		"walks": {},
		"uses": {},
		"requests": [],
		"tasks": {},
		"queues": {},
		"plans": {},
		"stocks": {},
		"carrying": {},
		"quality": {},
		"slots": {},
		"capabilities": {},
		"portals": {},
		"inbox": [],
		"pending": [],
		"ingested": [],
		"ledger": [],
		"commitments": {},
		"calling": [],
		"fired": [],
		"memories": {},
		"moments": {},
		"relationships": {},
		"beliefs": {},
		"knowledge": [],
		"initiatives": {},
		"read_notices": [],
		"started": [],
		"roles": {},
		"next_id": 1
	}
	for person_id: String in scenario.people:
		var person: Dictionary = definitions[person_id]
		var pos: Dictionary = {}
		for placement: Dictionary in scenario.placements:
			if placement.person == person_id:
				pos = placement.position.duplicate(true)
		var id: int = state.next_id
		state.next_id += 1
		var needs: Dictionary = {}
		for need: Dictionary in person.get("needs", []):
			needs[need.kind] = need.duplicate(true)
			needs[need.kind].value = need.initial
		state.residents[id] = {
			"id": id,
			"definition_id": person_id,
			"position": pos,
			"needs": needs,
			"conducts": person.get("conducts", []).duplicate(),
			"household": person.get("household", true),
			"traits": person.get("traits", []).duplicate()
		}
		if not person.get("affordances", []).is_empty():
			objects[person_id] = {
				"id": person_id,
				"display_name": person.display_name,
				"object_type": "object_type.person",
				"position": pos.duplicate(),
				"solid": false,
				"slots": person.slots.duplicate(true),
				"affordances": person.affordances.duplicate(true)
			}
	for id: String in keys(objects):
		if not objects[id].get("stocks", []).is_empty():
			state.stocks[id] = {}
			for stack: Dictionary in objects[id].stocks:
				state.stocks[id][stack.item] = stack.count
	for id: String in keys(initiative_defs):
		state.initiatives[id] = {"stage": initiative_defs[id].opens_at, "spoken": {}}


static func keys(d: Dictionary) -> Array:
	var out := d.keys()
	out.sort()
	return out


static func minutes(time: Dictionary) -> int:
	return int(time.hour) * 60 + int(time.minute)


func time_of_day() -> int:
	return (int(state.start) + int(state.tick)) % 1440


func submit_player_command(command: VillageCommand) -> void:
	state.inbox.append(command.to_data())


func emit(kind: String, fields: Dictionary = {}) -> void:
	var event := {"tick": state.tick, "kind": kind, "data": fields.duplicate(true)}
	state.ledger.append(event)
	state.pending.append(event.duplicate(true))


func resident_by_definition(id: String) -> int:
	for who: int in keys(state.residents):
		if state.residents[who].definition_id == id:
			return who
	return 0


func occupied(pos: Dictionary) -> int:
	for who: int in keys(state.residents):
		if state.residents[who].position == pos:
			return who
	return 0


func walkable(pos: Dictionary) -> bool:
	if not VillageContent.map_walkable(map, pos):
		return false
	for obj: Dictionary in objects.values():
		if obj.get("solid", false) and obj.position == pos:
			return false
	return true


static func tile_key(pos: Dictionary) -> String:
	return "%d:%d:%d" % [pos.place, pos.x, pos.y]


static func tile_less(a: Dictionary, b: Dictionary) -> bool:
	if a.place != b.place:
		return a.place < b.place
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y


func neighbours(pos: Dictionary) -> Array:
	var out: Array = []
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next := {"place": pos.place, "x": pos.x + offset.x, "y": pos.y + offset.y}
		if walkable(next):
			out.append(next)
	for portal: Dictionary in map.portals:
		if portal.from == pos:
			out.append(portal.to)
		elif portal.to == pos:
			out.append(portal.from)
	out.sort_custom(tile_less)
	return out


func portal_between(a: Dictionary, b: Dictionary) -> Dictionary:
	for portal: Dictionary in map.portals:
		if (portal.from == a and portal.to == b) or (portal.to == a and portal.from == b):
			return portal
	return {}


static func heuristic(a: Dictionary, b: Dictionary) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y) + int(a.place != b.place)


func find_path(origin: Dictionary, destination: Dictionary, avoid: int = 0) -> Array:
	if (
		not walkable(origin)
		or not walkable(destination)
		or (avoid != 0 and occupied(destination) not in [0, avoid])
	):
		return []
	var open: Array = [{"pos": origin, "cost": 0, "estimate": heuristic(origin, destination)}]
	var costs: Dictionary = {tile_key(origin): 0}
	var previous: Dictionary = {}
	while not open.is_empty():
		open.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool:
				if a.estimate != b.estimate:
					return a.estimate < b.estimate
				if a.cost != b.cost:
					return a.cost < b.cost
				return tile_less(a.pos, b.pos)
		)
		var current: Dictionary = open.pop_front()
		if current.pos == destination:
			var path: Array = [current.pos]
			while previous.has(tile_key(path[0])):
				path.push_front(previous[tile_key(path[0])])
			return path
		if costs.get(tile_key(current.pos)) != current.cost:
			continue
		for next: Dictionary in neighbours(current.pos):
			if avoid != 0 and (occupied(next) not in [0, avoid] or next_target(next, avoid)):
				continue
			var cost: int = current.cost + 1
			var key := tile_key(next)
			if not costs.has(key) or cost < costs[key]:
				costs[key] = cost
				previous[key] = current.pos
				open.append(
					{"pos": next, "cost": cost, "estimate": cost + heuristic(next, destination)}
				)
	return []


func next_target(pos: Dictionary, except: int) -> bool:
	for who: int in keys(state.walks):
		if who == except:
			continue
		var walk: Dictionary = state.walks[who]
		if not walk.traversal.is_empty():
			if walk.traversal.destination == pos:
				return true
		elif walk.next < walk.path.size() and walk.path[walk.next] == pos:
			return true
	return false


func approach(who: int, target: Dictionary) -> Dictionary:
	var origin: Dictionary = state.residents[who].position
	if walkable(target) and occupied(target) in [0, who]:
		return target
	var adjacent: Array = []
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		adjacent.append({"place": target.place, "x": target.x + offset.x, "y": target.y + offset.y})
	if origin in adjacent:
		return origin
	for tile: Dictionary in adjacent:
		if walkable(tile) and occupied(tile) in [0, who]:
			return tile
	return {}


func begin_go_to(
	who: int,
	destination: Dictionary,
	priority: int = 0,
	band: int = 0,
	task: int = 0,
	is_approach: bool = false
) -> bool:
	if not state.residents.has(who):
		return false
	state.walks[who] = {
		"destination": destination.duplicate(),
		"path": find_path(state.residents[who].position, destination),
		"next": 1,
		"traversal": {},
		"priority": priority,
		"band": band,
		"age": state.tick,
		"task": task,
		"approach": is_approach
	}
	return true


func affordance(obj: String, action: String) -> Dictionary:
	for a: Dictionary in objects.get(obj, {}).get("affordances", []):
		if a.id == action:
			return a
	return {}


func begin_use(
	who: int, obj: String, action: String, priority: int = 0, band: int = 0, task: int = 0
) -> bool:
	if not state.residents.has(who) or affordance(obj, action).is_empty():
		return false
	if (
		state.uses.has(who)
		or state.requests.any(func(r: Dictionary) -> bool: return r.resident == who)
	):
		return false
	state.requests.append(
		{
			"resident": who,
			"object": obj,
			"affordance": action,
			"priority": priority,
			"band": band,
			"age": state.tick,
			"task": task
		}
	)
	return true


func execution_free(who: int) -> bool:
	return (
		not state.walks.has(who)
		and not state.uses.has(who)
		and not state.requests.any(func(r: Dictionary) -> bool: return r.resident == who)
	)


func finish_task(who: int, task: int, status: String) -> void:
	state.tasks[task] = status
	state.queues[who] = state.queues.get(who, []).filter(
		func(c: Dictionary) -> bool: return c.task != task
	)
	if state.queues[who].is_empty():
		state.queues.erase(who)


func release_walk(who: int) -> void:
	state.walks.erase(who)
	for portal: String in keys(state.portals):
		if state.portals[portal] == who:
			state.portals.erase(portal)


func release_use(who: int) -> Dictionary:
	var active: Dictionary = state.uses.get(who, {})
	if not active.is_empty():
		state.slots.erase(active.object + "/" + active.slot)
		state.capabilities.erase(str(who) + "/" + active.capability)
		state.uses.erase(who)
	return active


func ingest_commands() -> void:
	var inbox: Array = state.inbox
	state.inbox = []
	for c: Dictionary in inbox:
		var reason := ""
		if c.kind == VillageCommand.Kind.CANCEL:
			cancel_task(c.task)
			continue
		if (
			c.kind
			in [VillageCommand.Kind.PROMOTE, VillageCommand.Kind.FORCE, VillageCommand.Kind.REORDER]
		):
			manage_task(c)
			continue
		if c.kind not in [VillageCommand.Kind.GO_TO, VillageCommand.Kind.USE_OBJECT]:
			emit("PlayerCommandRejected", {"task": c.task, "reason": "InvalidCommand"})
			continue
		if state.tasks.has(c.task):
			reason = "DuplicateTask"
		elif not state.residents.has(c.resident) or not state.residents[c.resident].household:
			reason = "UnknownResident"
		elif c.kind == VillageCommand.Kind.GO_TO and not walkable(c.destination):
			reason = "InvalidMoveTarget"
		elif (
			c.kind == VillageCommand.Kind.USE_OBJECT
			and affordance(c.object, c.affordance).is_empty()
		):
			reason = "InvalidUseTarget"
		if not reason.is_empty():
			emit("PlayerCommandRejected", {"task": c.task, "reason": reason})
			continue
		state.tasks[c.task] = "Queued"
		if not state.queues.has(c.resident):
			state.queues[c.resident] = []
		state.queues[c.resident].append(c)
		emit("PlayerCommandAccepted", {"task": c.task})


func cancel_task(task: int) -> void:
	if not state.tasks.has(task) or state.tasks[task] not in ["Queued", "Active", "Paused"]:
		emit(
			"PlayerCommandRejected",
			{
				"task": task,
				"reason": "UnknownTask" if not state.tasks.has(task) else "TaskNotCancellable"
			}
		)
		return
	for who: int in keys(state.queues):
		for c: Dictionary in state.queues[who]:
			if c.task != task:
				continue
			emit("PlayerCommandAccepted", {"task": task})
			var walking: Dictionary = state.walks.get(who, {})
			var was_walking: bool = walking.get("task", 0) == task
			if was_walking:
				release_walk(who)
			if state.uses.get(who, {}).get("task", 0) == task:
				release_use(who)
			state.requests = state.requests.filter(
				func(r: Dictionary) -> bool: return r.task != task
			)
			finish_task(who, task, "Cancelled")
			if was_walking or c.kind == VillageCommand.Kind.GO_TO:
				emit(
					"GoToCancelled",
					{
						"task": task,
						"resident": who,
						"destination": walking.destination if was_walking else c.destination
					}
				)
			else:
				emit(
					"TaskCancelled",
					{"task": task, "resident": who, "object": c.object, "affordance": c.affordance}
				)
			return


func manage_task(command: Dictionary) -> void:
	var reason: String = (
		"UnknownTask" if not state.tasks.has(command.task) else "TaskNotCancellable"
	)
	for who: int in keys(state.queues):
		var queue: Array = state.queues[who]
		var source: int = -1
		for i: int in queue.size():
			if queue[i].task == command.task:
				source = i
		if source < 0:
			continue
		var head: int = queue[0].task
		var active: bool = (
			state.tasks[head] in ["Active", "Paused"]
			or state.requests.any(func(r: Dictionary) -> bool: return r.task == head)
		)
		var first: int = 1 if active else 0
		var target: int = first
		if command.kind == VillageCommand.Kind.REORDER:
			target = command.get("queue_index", -1)
		if (
			command.kind != VillageCommand.Kind.FORCE
			and (source < first or target < first or target >= queue.size())
		):
			reason = "InvalidQueuePosition"
			break
		var task: Dictionary = queue[source]
		if command.kind == VillageCommand.Kind.FORCE:
			pause_head(who)
			if state.plans.get(who, {}).get("band", 0) < 2000:
				if state.walks.get(who, {}).get("task", -1) == 0:
					release_walk(who)
				if state.uses.get(who, {}).get("task", -1) == 0:
					release_use(who)
				state.requests = state.requests.filter(
					func(r: Dictionary) -> bool: return r.resident != who or r.task != 0
				)
				if state.plans.has(who) and not state.plans[who].frames.is_empty():
					state.plans[who].frames[-1].flight = false
			task.priority = 500
			task.forced = true
			target = 0
		queue.remove_at(source)
		queue.insert(target, task)
		emit("PlayerCommandAccepted", {"task": command.task, "operation": command.kind})
		emit(
			"PlayerQueueChanged",
			{"task": command.task, "resident": who, "operation": command.kind, "index": target}
		)
		return
	emit("PlayerCommandRejected", {"task": command.task, "reason": reason})


func dispatch_queues() -> void:
	for who: int in keys(state.queues):
		if not execution_free(who) or state.queues[who].is_empty():
			continue
		var c: Dictionary = state.queues[who][0]
		if c.kind == VillageCommand.Kind.GO_TO:
			if begin_go_to(who, c.destination, c.priority, 1000, c.task):
				state.tasks[c.task] = "Active"
		else:
			var target := approach(who, objects[c.object].position)
			if not target.is_empty() and state.residents[who].position != target:
				if begin_go_to(who, target, c.priority, 1000, c.task, true):
					state.tasks[c.task] = "Active"
			elif begin_use(who, c.object, c.affordance, c.priority, 1000, c.task):
				state.tasks[c.task] = "Queued"


static func claim_less(a: Dictionary, b: Dictionary) -> bool:
	if a.band + a.priority != b.band + b.priority:
		return a.band + a.priority > b.band + b.priority
	if a.age != b.age:
		return a.age < b.age
	return a.resident < b.resident


func tick_walks() -> void:
	var claims: Array = []
	for who: int in keys(state.walks):
		var w: Dictionary = state.walks[who]
		if not w.traversal.is_empty() or w.next >= w.path.size():
			continue
		var target: Dictionary = w.path[w.next]
		var portal := portal_between(state.residents[who].position, target)
		if occupied(target) != 0 or (not portal.is_empty() and state.portals.has(portal.id)):
			continue
		var claim: Dictionary = w.duplicate()
		claim.resident = who
		claim.target = target
		claims.append(claim)
	claims.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			if a.target != b.target:
				return tile_less(a.target, b.target)
			return claim_less(a, b)
	)
	var winners: Dictionary = {}
	var approved: Array = []
	var waited: Dictionary = {}
	for c: Dictionary in claims:
		var key := tile_key(c.target)
		if winners.has(key):
			waited[c.resident] = {
				"resident": c.resident, "blocked_by": winners[key], "position": c.target
			}
		else:
			winners[key] = c.resident
			approved.append(c.resident)
	approved.sort()
	var all: Array = keys(state.walks)
	for who: int in approved:
		tick_walk(who)
	for who: int in all:
		if who in approved:
			continue
		if waited.has(who):
			emit("GoToWaited", waited[who])
		else:
			tick_walk(who)


func tick_walk(who: int) -> void:
	if not state.walks.has(who):
		return
	var w: Dictionary = state.walks[who]
	state.walks.erase(who)
	var origin: Dictionary = state.residents[who].position
	if not w.traversal.is_empty():
		w.traversal.remaining -= 1
		if w.traversal.remaining == 0:
			state.portals.erase(w.traversal.portal)
			state.residents[who].position = w.traversal.destination
			w.next += 1
			w.traversal = {}
			finish_walk(who, w)
		else:
			state.walks[who] = w
		return
	if w.path.is_empty() or (origin != w.destination and w.next >= w.path.size()):
		if w.task != 0:
			finish_task(who, w.task, "Completed")
		emit("GoToFailed", {"resident": who, "destination": w.destination})
		return
	if origin == w.destination:
		finish_walk(who, w)
		return
	var next: Dictionary = w.path[w.next]
	var blocker := occupied(next)
	if blocker != 0:
		var path := find_path(origin, w.destination, who)
		if not path.is_empty():
			w.path = path
			w.next = 1
		else:
			emit("GoToWaited", {"resident": who, "blocked_by": blocker, "position": next})
		state.walks[who] = w
		return
	var portal := portal_between(origin, next)
	if not portal.is_empty():
		if state.portals.has(portal.id):
			emit(
				"GoToWaited",
				{"resident": who, "blocked_by": state.portals[portal.id], "position": next}
			)
		else:
			state.portals[portal.id] = who
			w.traversal = {
				"portal": portal.id,
				"destination": next,
				"remaining": maxi(1, portal.traversal_ticks)
			}
		state.walks[who] = w
		return
	state.residents[who].position = next
	w.next += 1
	finish_walk(who, w)


func finish_walk(who: int, w: Dictionary) -> void:
	if state.residents[who].position == w.destination:
		if w.task != 0 and not w.approach:
			finish_task(who, w.task, "Completed")
		emit("GoToArrived", {"resident": who, "destination": w.destination})
	else:
		state.walks[who] = w


func tick_uses() -> void:
	for who: int in keys(state.uses):
		var active: Dictionary = state.uses[who]
		active.remaining -= 1
		if active.remaining > 0:
			continue
		var a := affordance(active.object, active.affordance)
		release_use(who)
		if active.task != 0:
			finish_task(who, active.task, "Completed")
		emit(
			"ObjectUseCompleted",
			{"resident": who, "object": active.object, "affordance": active.affordance}
		)
		if a.get("recovers") != null:
			recover_need(who, a.recovers)
		if a.get("restocks") != null:
			restock(who, a.restocks)
	state.requests.sort_custom(claim_less)
	var requests: Array = state.requests
	state.requests = []
	for r: Dictionary in requests:
		var a := affordance(r.object, r.affordance)
		if a.is_empty():
			continue
		var slot: String = r.object + "/" + a.slot
		var capability: String = str(r.resident) + "/" + a.capability
		var blocker: int = state.slots.get(
			slot, r.resident if state.capabilities.has(capability) else 0
		)
		if blocker != 0:
			emit(
				"ObjectUseWaited",
				{
					"resident": r.resident,
					"object": r.object,
					"affordance": r.affordance,
					"blocked_by": blocker
				}
			)
			state.requests.append(r)
			continue
		state.slots[slot] = r.resident
		state.capabilities[capability] = r.object
		var active: Dictionary = r.duplicate()
		active.slot = a.slot
		active.capability = a.capability
		active.remaining = maxi(1, a.duration_ticks)
		state.uses[r.resident] = active
		if r.task != 0:
			state.tasks[r.task] = "Active"
		emit(
			"ObjectUseStarted",
			{"resident": r.resident, "object": r.object, "affordance": r.affordance}
		)
		if objects[r.object].object_type == "object_type.seat" and time_of_day() >= 1080:
			record_seat(r.resident, objects[r.object].position)
		if objects[r.object].object_type == "object_type.person":
			deliver_invitation(r.object)
			for id: String in keys(initiative_defs):
				if initiative_defs[id].proposer == r.object:
					speak(r.resident, id)
		if r.affordance == "affordance.read_the_board":
			read_board(r.resident)


func recover_need(who: int, recovery: Dictionary) -> void:
	var needs: Dictionary = state.residents[who].needs
	if not needs.has(recovery.need):
		return
	needs[recovery.need].value = maxi(0, needs[recovery.need].value - recovery.amount)
	emit(
		"NeedRecovered",
		{"resident": who, "need": recovery.need, "value": needs[recovery.need].value}
	)


func restock(who: int, definition: Dictionary) -> void:
	var id: String = definition.cupboard
	if not state.stocks.has(id):
		state.stocks[id] = {}
	var brought: int = 0
	for stack: Dictionary in definition.levels:
		var before: int = state.stocks[id].get(stack.item, 0)
		var after := maxi(before, stack.count)
		brought += after - before
		state.stocks[id][stack.item] = after
	emit("CupboardRestocked", {"shopper": who, "cupboard": id, "brought": brought})


func cupboard_with(who: int, item: String, count: int) -> String:
	for id: String in keys(state.stocks):
		if (
			objects[id].position.place == state.residents[who].position.place
			and state.stocks[id].get(item, 0) >= count
		):
			return id
	return ""


func can_prepare(who: int, recipe: String) -> bool:
	if not recipes.has(recipe):
		return false
	for ingredient: Dictionary in recipes[recipe].ingredients:
		if (
			not ingredient.get("optional", false)
			and cupboard_with(who, ingredient.item, ingredient.count).is_empty()
		):
			return false
	return true


func cook(who: int, recipe: Dictionary) -> void:
	var taken: Array = []
	var extras: int = 0
	for ingredient: Dictionary in recipe.ingredients:
		var cupboard := cupboard_with(who, ingredient.item, ingredient.count)
		if cupboard.is_empty():
			if ingredient.get("optional", false):
				continue
			return
		taken.append([cupboard, ingredient.item, ingredient.count])
		if ingredient.get("optional", false):
			extras += 1
	for item: Array in taken:
		state.stocks[item[0]][item[1]] = maxi(0, state.stocks[item[0]][item[1]] - item[2])
	state.carrying[who] = recipe.output
	state.quality[who] = mini(
		255, recipe.recovers.amount + mini(255, recipe.get("quality_bonus", 0) * extras)
	)
	emit("MealPrepared", {"cook": who, "recipe": recipe.id, "extras": extras})


func consume(who: int) -> void:
	if not state.carrying.has(who):
		return
	var item: String = state.carrying[who]
	var amount: int = state.quality.get(who, 0)
	state.carrying.erase(who)
	state.quality.erase(who)
	for id: String in keys(recipes):
		if recipes[id].output == item:
			recover_need(who, {"need": recipes[id].recovers.need, "amount": amount})
			break
	emit("MealEaten", {"eater": who, "item": item})


func cupboard_emptiness(id: String) -> int:
	var full: int = 0
	var held: int = 0
	for stack: Dictionary in objects.get(id, {}).get("stocks", []):
		full += stack.count
		held += mini(stack.count, state.stocks.get(id, {}).get(stack.item, 0))
	return 0 if full == 0 else (full - held) * 100 / full


static func curve_score(points: Array, input: int) -> int:
	if points.is_empty():
		return 0
	if input <= points[0].input:
		return points[0].score
	for i: int in range(1, points.size()):
		var left: Dictionary = points[i - 1]
		var right: Dictionary = points[i]
		if input <= right.input:
			var span: int = right.input - left.input
			return (
				right.score
				if span <= 0
				else left.score + (int(right.score - left.score) * int(input - left.input) / span)
			)
	return points[-1].score


func score_intention(who: int, definition: Dictionary) -> Variant:
	var source: Variant = definition.source
	var kind: String = source.kind if source is Dictionary else source
	var input: int = 0
	match kind:
		"Need":
			if not state.residents[who].needs.has(source.value):
				return null
			input = state.residents[who].needs[source.value].value
		"CommitmentDue":
			if not state.commitments.has(who):
				return null
			input = state.commitments[who].active_from - time_of_day()
		"HoldingARole":
			if not state.roles.has(who):
				return null
			input = 100
		"CupboardRunningLow":
			input = cupboard_emptiness(source.value)
	var score := curve_score(definition.curve.points, input)
	for modifier: Dictionary in definition.get("modifiers", []):
		if modifier.when == "AnotherAttendeeIsDisapprovedOf":
			for other: int in keys(state.commitments):
				if other != who and holds_label(who, other):
					score += modifier.delta
					break
	if state.plans.get(who, {}).get("intention", "") == definition.id:
		score += definition.get("commitment_bonus", 0)
	return score


func resolve_conduct(who: int, slot: String) -> String:
	var result := ""
	var best_layer: int = -1
	var best_priority: int = -2147483648
	for id: String in state.residents[who].conducts:
		var conduct: Dictionary = conducts.get(id, {})
		if conduct.is_empty():
			continue
		var layer: int = ["Intrinsic", "Persistent", "Contextual"].find(conduct.layer)
		for method: Dictionary in conduct.methods:
			if method.slot != slot:
				continue
			if method.get("needs_recipe") != null and not can_prepare(who, method.needs_recipe):
				continue
			if layer > best_layer or (layer == best_layer and method.priority >= best_priority):
				result = method.plan
				best_layer = layer
				best_priority = method.priority
	return result


func run_autonomy() -> void:
	for who: int in keys(state.residents):
		var best: Dictionary = {}
		var best_score: int = 0
		for definition: Dictionary in intentions:
			var score: Variant = score_intention(who, definition)
			if score != null and score > 0 and score >= best_score:
				best = definition
				best_score = score
		if not best.is_empty() and state.plans.get(who, {}).get("intention", "") != best.id:
			var plan_id := resolve_conduct(who, best.conduct)
			if not plan_id.is_empty():
				var urgent: bool = (
					best.source is Dictionary
					and best.source.kind == "Need"
					and (
						state.residents[who].needs[best.source.value].value
						>= state.residents[who].needs[best.source.value].get("urgent_at", 255)
					)
				)
				state.plans[who] = {
					"intention": best.id,
					"frames": [{"plan": plan_id, "step": 0, "flight": false}],
					"band": 2000 if urgent else 0,
					"priority": plans[plan_id].get("priority", 0)
				}
		advance_plan(who)


func pause_head(who: int) -> void:
	var task: int = state.walks.get(who, {}).get("task", 0)
	if task != 0:
		release_walk(who)
		state.tasks[task] = "Paused"
		return
	task = state.uses.get(who, {}).get("task", 0)
	if task != 0:
		release_use(who)
		state.tasks[task] = "Paused"
		return
	for r: Dictionary in state.requests:
		if r.resident == who and r.task != 0:
			state.tasks[r.task] = "Paused"
			state.requests.erase(r)
			return


func advance_plan(who: int) -> void:
	if not state.plans.has(who):
		return
	var p: Dictionary = state.plans[who]
	if not state.queues.get(who, []).is_empty():
		if p.band != 2000:
			if state.walks.has(who) and state.walks[who].task == 0:
				release_walk(who)
				if not p.frames.is_empty():
					p.frames[-1].flight = false
			return
		var engaged: bool = (
			(state.walks.has(who) and state.walks[who].task == 0)
			or (state.uses.has(who) and state.uses[who].task == 0)
		)
		if not engaged:
			pause_head(who)
	for iteration: int in 8:
		if p.frames.is_empty():
			state.plans.erase(who)
			for definition: Dictionary in intentions:
				if (
					definition.id == p.intention
					and definition.source is String
					and definition.source == "HoldingARole"
				):
					discharge_role(who)
			return
		var frame: Dictionary = p.frames[-1]
		var steps: Array = plans[frame.plan].steps
		if frame.step >= steps.size():
			p.frames.pop_back()
			if not p.frames.is_empty():
				p.frames[-1].step += 1
				p.frames[-1].flight = false
			continue
		var step: Variant = steps[frame.step]
		var kind: String = step.kind if step is Dictionary else step
		var args: Dictionary = step.value if step is Dictionary else {}
		if kind in ["Plan", "Conduct"]:
			var next: String = args.plan if kind == "Plan" else resolve_conduct(who, args.slot)
			if next.is_empty():
				state.plans.erase(who)
				return
			if p.frames.size() >= 8:
				p.frames.clear()
			else:
				p.frames.append({"plan": next, "step": 0, "flight": false})
			continue
		if kind == "Consume":
			consume(who)
			frame.step += 1
			frame.flight = false
			continue
		if not frame.flight:
			if kind == "GoTo":
				begin_go_to(who, args.tile, p.priority, p.band)
			else:
				var target_id: String = args.object if kind == "Use" else recipes[args.recipe].tool
				var target := approach(who, objects[target_id].position)
				if not target.is_empty():
					if state.residents[who].position != target:
						begin_go_to(who, target, p.priority, p.band)
					elif kind == "Use":
						begin_use(who, args.object, args.affordance, p.priority, p.band)
					else:
						cook(who, recipes[args.recipe])
			frame.flight = true
			return
		if not execution_free(who):
			return
		var done: bool = kind == "GoTo" or (kind == "Prepare" and state.carrying.has(who))
		if kind == "Use":
			for event: Dictionary in state.ledger.slice(maxi(0, state.ledger.size() - 24)):
				if (
					event.kind == "ObjectUseCompleted"
					and event.data.resident == who
					and event.data.object == args.object
					and event.data.affordance == args.affordance
				):
					done = true
		if done:
			frame.step += 1
		frame.flight = false


func send_callers() -> void:
	var invitations: Array = content.table("scenarios")[0].get("invitations", [])
	for i: int in invitations.size():
		var invitation: Dictionary = invitations[i]
		if i in state.fired or i in state.calling or time_of_day() < minutes(invitation.invite_at):
			continue
		var host := resident_by_definition(invitation.host)
		if host == 0:
			continue
		state.calling.append(i)
		begin_go_to(host, invitation.call_at_tile)


func deliver_invitation(host: String) -> void:
	var invitations: Array = content.table("scenarios")[0].get("invitations", [])
	for i: int in invitations.size():
		var invitation: Dictionary = invitations[i]
		if i in state.fired or invitation.host != host:
			continue
		state.fired.append(i)
		emit("NeighbourInvitation", {"host": host, "event_at": invitation.event_at})
		var household: Array = keys(state.residents).filter(
			func(w: int) -> bool: return state.residents[w].household
		)
		for n: int in household.size():
			var who: int = household[n]
			var distance: int = 0
			for other: int in household:
				if other != who and holds_label(who, other):
					distance = 4
			var destination: Dictionary = invitation.venue_tile.duplicate()
			destination.x += n + distance
			if not walkable(destination):
				destination = invitation.venue_tile.duplicate()
			state.commitments[who] = {
				"destination": destination, "active_from": minutes(invitation.event_at)
			}


func settle_arrivals() -> void:
	for who: int in keys(state.commitments):
		var c: Dictionary = state.commitments[who]
		if (
			time_of_day() >= c.active_from
			and state.residents[who].position.place == c.destination.place
		):
			state.commitments.erase(who)
			emit("QuizArrived", {"resident": who})


func record_seat(who: int, position: Dictionary) -> void:
	var witnesses: Array = []
	for other: int in keys(state.residents):
		if other != who and state.residents[other].position.place == position.place:
			witnesses.append(other)
	record_moment(who, who, "TookPargeterSeat", social.took_pargeter_seat)
	for witness: int in witnesses:
		record_moment(witness, who, "WitnessedPargeterSeat", social.witnessed_pargeter_seat)
	if not "PargeterSeatCustom" in state.knowledge:
		state.knowledge.append("PargeterSeatCustom")
	emit("PargeterSeatTaken", {"participant": who, "witnessed_by": witnesses})


static func relationship_key(observer: int, about: int) -> String:
	return "%d:%d" % [observer, about]


func record_moment(observer: int, about: int, perception: String, outcome: Dictionary) -> void:
	state.moments[observer] = {
		"perception": perception, "expires_tick": state.tick + outcome.moment_ticks
	}
	if not state.memories.has(observer):
		state.memories[observer] = []
	state.memories[observer].append(
		{
			"perception": perception,
			"about": about,
			"formed_tick": state.tick,
			"salience": outcome.salience
		}
	)
	var key := relationship_key(observer, about)
	if not state.relationships.has(key):
		state.relationships[key] = {}
	for delta: Dictionary in outcome.relationship:
		state.relationships[key][delta.dimension] = clampi(
			state.relationships[key].get(delta.dimension, 0) + delta.delta, -32768, 32767
		)
	if observer == about:
		return
	if not state.beliefs.has(key):
		state.beliefs[key] = {
			"observer": observer,
			"about": about,
			"topic": "Inconsiderate",
			"evidence": [],
			"confidence": 0,
			"trend": "Steady",
			"labelled": false
		}
	state.beliefs[key].evidence.append({"tick": state.tick, "perception": perception})
	state.beliefs[key].confidence = mini(
		100, state.beliefs[key].confidence + social.disapproval.confidence_per_evidence
	)


func holds_label(observer: int, about: int) -> bool:
	return state.beliefs.get(relationship_key(observer, about), {}).get("labelled", false)


static func weighted_decay(authored: int, traits: Array) -> int:
	if authored == 0:
		return 0
	var numerator: int = authored
	var denominator: int = 1
	for temperament: String in traits:
		if temperament == "ThinSkinned":
			denominator *= 2
		if temperament == "Forgiving":
			numerator *= 2
	return clampi(numerator / denominator, 1, 255)


func fade_memories() -> void:
	for who: int in keys(state.moments):
		if state.moments[who].expires_tick <= state.tick:
			state.moments.erase(who)
	for who: int in keys(state.memories):
		var kept: Array = []
		for memory: Dictionary in state.memories[who]:
			var outcome: Dictionary = (
				social.took_pargeter_seat
				if memory.perception == "TookPargeterSeat"
				else social.witnessed_pargeter_seat
			)
			memory.salience = maxi(
				0,
				(
					memory.salience
					- weighted_decay(outcome.salience_decay_per_tick, state.residents[who].traits)
				)
			)
			if memory.salience > 0:
				kept.append(memory)
		if kept.is_empty():
			state.memories.erase(who)
		else:
			state.memories[who] = kept


func settle_beliefs() -> void:
	var d: Dictionary = social.disapproval
	for key: String in keys(state.beliefs):
		var b: Dictionary = state.beliefs[key]
		var before: int = b.confidence
		b.confidence = maxi(0, before - d.confidence_decay_per_tick)
		b.trend = "Softening" if b.confidence < before else "Steady"
		b.labelled = b.confidence > d.exit_at if b.labelled else b.confidence >= d.enter_at
		if b.confidence == 0 and not b.labelled:
			state.beliefs.erase(key)


func stance_strength(who: int, id: String) -> int:
	var proposer := resident_by_definition(initiative_defs[id].proposer)
	if proposer == 0 or proposer == who:
		return 0
	var entries: Dictionary = state.relationships.get(relationship_key(who, proposer), {})
	return (
		entries.get("Respect", 0)
		+ entries.get("Affection", 0)
		+ entries.get("Trust", 0)
		- entries.get("Grievance", 0)
		- (40 if holds_label(who, proposer) else 0)
	)


func speak(who: int, id: String) -> void:
	var feeling := stance_strength(who, id)
	if absi(feeling) < 8:
		return
	var stance := "For" if feeling >= 8 else "Against"
	var spoken: Dictionary = state.initiatives[id].spoken
	var already := spoken.has(who)
	spoken[who] = stance
	if not already:
		emit("SpokeOnInitiative", {"resident": who, "initiative": id, "stance": stance})


func notices() -> Array:
	var result: Array = []
	for id: String in keys(state.initiatives):
		for stage: Dictionary in initiative_defs[id].stages:
			if stage.id == state.initiatives[id].stage and stage.get("notice") != null:
				result.append({"id": id, "text": stage.notice})
	return result


func read_board(who: int) -> void:
	if not state.residents[who].household:
		return
	for notice: Dictionary in notices():
		if not notice.id in state.read_notices:
			state.read_notices.append(notice.id)
			emit("NoticeRead", {"resident": who, "initiative": notice.id})


func advance_initiatives() -> void:
	for id: String in keys(state.initiatives):
		var current: Dictionary = state.initiatives[id]
		for stage: Dictionary in initiative_defs[id].stages:
			if stage.id != current.stage or stage.get("concluded", false):
				continue
			for edge: Dictionary in stage.get("transitions", []):
				var condition: Dictionary = edge.when
				var met := false
				match condition.kind:
					"SupportAtLeast":
						met = current.spoken.values().count("For") >= condition.value
					"OppositionAtLeast":
						met = current.spoken.values().count("Against") >= condition.value
					"OnOrAfter":
						met = time_of_day() >= minutes(condition.value)
				if met:
					current.stage = edge.to
					emit("InitiativeMoved", {"initiative": id, "stage": edge.to})
					break
			break


func advance_coordinators() -> void:
	for id: String in keys(coordinator_defs):
		if id in state.started:
			continue
		var c: Dictionary = coordinator_defs[id]
		if not state.initiatives.values().any(
			func(i: Dictionary) -> bool: return i.stage == c.starts_when
		):
			continue
		state.started.append(id)
		var available: Array = keys(state.residents).filter(
			func(w: int) -> bool: return state.residents[w].household and not state.roles.has(w)
		)
		for role: Dictionary in c.roles:
			if available.is_empty():
				break
			var who: int = available.pop_front()
			state.roles[who] = role.id
			if not role.conduct in state.residents[who].conducts:
				state.residents[who].conducts.append(role.conduct)
			emit("RoleAccepted", {"resident": who, "coordinator": id, "role": role.id})


func discharge_role(who: int) -> void:
	if not state.roles.has(who):
		return
	var id: String = state.roles[who]
	state.roles.erase(who)
	for c: Dictionary in coordinator_defs.values():
		for role: Dictionary in c.roles:
			if role.id == id:
				state.residents[who].conducts.erase(role.conduct)
	emit("RoleDischarged", {"resident": who, "role": id})


func advance_tick() -> void:
	state.ingested = state.pending
	state.pending = []
	state.tick += 1
	ingest_commands()
	send_callers()
	for who: int in keys(state.residents):
		var resident: Dictionary = state.residents[who]
		if objects.has(resident.definition_id):
			objects[resident.definition_id].position = resident.position.duplicate()
	fade_memories()
	settle_beliefs()
	for who: int in keys(state.residents):
		for need: Dictionary in state.residents[who].needs.values():
			need.value = mini(255, need.value + need.decay_per_tick)
	run_autonomy()
	settle_arrivals()
	advance_initiatives()
	advance_coordinators()
	dispatch_queues()
	tick_walks()
	tick_uses()
	emit(
		"TickCompleted",
		{"keyed_marker": KeyedDraw.draw(state.seed, str(state.tick), str(state.tick))}
	)


func cottage_snapshot() -> Dictionary:
	return project(false)


func developer_snapshot() -> Dictionary:
	return project(true)


func project(developer: bool) -> Dictionary:
	var result: Dictionary = {
		"tick": state.tick,
		"time_of_day": time_of_day(),
		"places": map.places.duplicate(true),
		"portals": map.portals.duplicate(true),
		"objects": [],
		"residents": [],
		"notices": [],
		"household_knows_pargeter_custom": "PargeterSeatCustom" in state.knowledge
	}
	for id: String in keys(objects):
		result.objects.append(objects[id].duplicate(true))
	for who: int in keys(state.residents):
		var r: Dictionary = state.residents[who]
		var view := {
			"id": who,
			"definition_id": r.definition_id,
			"display_name": definitions[r.definition_id].display_name,
			"position": r.position.duplicate(),
			"household": r.household,
			"activity":
			"walking" if state.walks.has(who) else state.uses.get(who, {}).get("affordance", "idle")
		}
		if r.household or developer:
			var tasks: Array = state.queues.get(who, []).duplicate(true)
			for task: Dictionary in tasks:
				task.status = state.tasks[task.task]
			var label := ""
			for i: Dictionary in intentions:
				if i.id == state.plans.get(who, {}).get("intention", ""):
					label = i.display_name
			var labels: Array = []
			for belief: Dictionary in state.beliefs.values():
				if belief.observer == who and belief.labelled:
					labels.append(belief.duplicate(true))
			view.private = {
				"needs": r.needs.duplicate(true),
				"autonomous_intention": label,
				"player_tasks": tasks,
				"recent_perception": state.moments.get(who, {}).duplicate(true),
				"attending_quiz": state.commitments.has(who),
				"memories": state.memories.get(who, []).duplicate(true),
				"labels": labels,
				"carrying": state.carrying.get(who, ""),
				"role": state.roles.get(who, "")
			}
		result.residents.append(view)
	for notice: Dictionary in notices():
		if developer or notice.id in state.read_notices:
			result.notices.append(notice.text)
	return result


func events_since(cursor: int, developer: bool = false) -> Dictionary:
	var visible: Array = []
	for event: Dictionary in state.ledger.slice(cursor):
		if event.kind == "TickCompleted":
			continue
		var data: Dictionary = event.data
		var allowed: bool = developer or event.kind == "PlayerCommandRejected"
		if data.has("task") and state.tasks.has(data.task):
			allowed = true
		for field: String in ["resident", "cook", "eater", "shopper", "participant"]:
			if data.has(field) and state.residents.get(data[field], {}).get("household", false):
				allowed = true
		if event.kind == "NeighbourInvitation":
			allowed = true
		if data.has("initiative") and data.initiative in state.read_notices:
			allowed = true
		if allowed:
			visible.append(event.duplicate(true))
	return {"cursor": state.ledger.size(), "events": visible}


func next_player_task_id() -> int:
	var result: int = 1
	for id: int in state.tasks:
		result = maxi(result, id + 1)
	for command: Dictionary in state.inbox:
		result = maxi(result, command.task + 1)
	return result
