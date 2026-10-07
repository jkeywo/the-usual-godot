class_name VillageCommand
extends RefCounted

enum Kind { GO_TO, USE_OBJECT, CANCEL }
var kind: Kind = Kind.GO_TO
var task: int = 0
var resident: int = 0
var destination: Dictionary = {}
var object: String = ""
var affordance: String = ""
var priority: int = 0


func to_data() -> Dictionary:
	return {
		"kind": kind,
		"task": task,
		"resident": resident,
		"destination": destination.duplicate(true),
		"object": object,
		"affordance": affordance,
		"priority": priority
	}


static func go_to(id: int, who: int, tile: Dictionary, weight: int = 0) -> VillageCommand:
	var c := VillageCommand.new()
	c.task = id
	c.resident = who
	c.destination = tile.duplicate(true)
	c.priority = weight
	return c


static func use_object(
	id: int, who: int, target: String, action: String, weight: int = 0
) -> VillageCommand:
	var c := go_to(id, who, {}, weight)
	c.kind = Kind.USE_OBJECT
	c.object = target
	c.affordance = action
	return c


static func cancel(id: int) -> VillageCommand:
	var c := VillageCommand.new()
	c.kind = Kind.CANCEL
	c.task = id
	return c
