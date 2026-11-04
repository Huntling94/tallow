class_name DefenceType
extends RefCounted
## One kind of defence (spec 0040). Threat steers the herd away from routes
## through its segment; the kill chance and capacity decide how many passing
## beasts it stops in a night.

var id: String
var display_name: String
var cost: int
## Whole units added to the threat of every route through the segment.
var threat: int
## Chance to kill each passing beast, in parts per million.
var kill_ppm: int
## Most beasts it can kill in one night. Resets every night.
var capacity: int


func _init(
	defence_id: String, name_text: String, cost_money: int, threat_units: int, kill: int, most: int
) -> void:
	id = defence_id
	display_name = name_text
	cost = cost_money
	threat = threat_units
	kill_ppm = kill
	capacity = most
