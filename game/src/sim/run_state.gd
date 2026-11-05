class_name RunState
extends RefCounted
## What carries over between seasons (spec 0040): money and the defences
## standing on each segment.

var money: int
## Segment id -> defence id. One defence per segment.
var defences := {}


func _init(starting_money: int) -> void:
	money = starting_money


## Builds a defence if it can. Returns "" on success, or the reason it was
## rejected: unknown_defence, unknown_segment, segment_closed, segment_taken
## or not_enough_money. A rejected build changes nothing.
func build(setup: RunSetup, defence_id: String, segment_id: String) -> String:
	if not setup.defences.has(defence_id):
		return "unknown_defence"
	if not setup.graph.has_segment(segment_id):
		return "unknown_segment"
	if setup.graph.is_closed(segment_id):
		return "segment_closed"
	if defences.has(segment_id):
		return "segment_taken"
	var defence: DefenceType = setup.defences[defence_id]
	if money < defence.cost:
		return "not_enough_money"
	money -= defence.cost
	defences[segment_id] = defence_id
	return ""


## Segment id -> threat from the defence on it.
func threat_by_segment(setup: RunSetup) -> Dictionary:
	var threat := {}
	for segment_id: String in defences:
		var defence: DefenceType = setup.defences[defences[segment_id]]
		threat[segment_id] = defence.threat
	return threat
