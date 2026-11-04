class_name RunSetup
extends RefCounted
## Everything fixed for a run: the valley, the herd, the defence types and the
## run rules. The loader builds it from game/data; the simulation only reads it.

var graph: RouteGraph
var herd: HerdPersonality
## Defence id -> DefenceType.
var defences: Dictionary
var rules: RunRules


func _init(
	valley: RouteGraph,
	herd_personality: HerdPersonality,
	defence_types: Dictionary,
	run_rules: RunRules
) -> void:
	graph = valley
	herd = herd_personality
	defences = defence_types
	rules = run_rules
