class_name SimBoundary
extends RefCounted
## Finds references that ADR-0002 forbids in simulation code (game/src/sim/):
## scene, node and resource types, scene access, engine servers, the wall
## clock and frame counters, unseeded randomness, file access and input.
##
## Node and resource types are found by asking the engine (ClassDB), so every
## Node or Resource subclass is caught without a list to maintain.

const SIM_DIR := "res://src/sim"

## Each rule pairs a regular expression with the reason it is forbidden.
const RULES: Array[Array] = [
	["\\bget_tree\\s*\\(", "scene tree access"],
	["\\bget_node(_or_null)?\\s*\\(", "scene access"],
	['\\$[A-Za-z_"]', "scene access"],
	["(?<![\\w%])%[A-Z]\\w*", "scene access"],
	["@(onready|export)\\b", "scene access"],
	["\\.instantiate\\s*\\(", "scene access"],
	[
		"\\b(RenderingServer|PhysicsServer2D|PhysicsServer3D|DisplayServer|AudioServer)\\b",
		"engine server"
	],
	["\\bTime\\.", "wall-clock time"],
	["\\bOS\\.get_ticks_", "wall-clock time"],
	["\\bEngine\\.get_(physics|process)_frames\\b", "frame counter"],
	# Global functions only: "(?<![.\\w])" skips methods such as _rng.randi_range().
	[
		(
			"(?<![.\\w])(randi|randf|randfn|randi_range|randf_range|randomize|seed|rand_from_seed)"
			+ "\\s*\\("
		),
		"unseeded randomness",
	],
	# A generator's own randomize() reseeds it from the clock.
	["\\.randomize\\s*\\(", "unseeded randomness"],
	# Array.shuffle() and Array.pick_random() use the global generator.
	["\\.(shuffle|pick_random)\\s*\\(", "unseeded randomness"],
	["(?<![.\\w])(load|preload)\\s*\\(", "resource loading"],
	["\\b(ResourceLoader|FileAccess|DirAccess)\\b", "file or resource access"],
	["\\bInput\\.", "input"],
]

const TYPE_NAME := "\\b[A-Z][A-Za-z0-9_]*\\b"


## Returns one "line N: reason" entry per forbidden reference in the source.
## Comments are ignored. Known limit: a "#" inside a string starts the comment
## early, and text inside multi-line strings is scanned as code.
static func find_violations(source: String) -> PackedStringArray:
	var violations := PackedStringArray()
	var compiled: Array[RegEx] = []
	for rule: Array in RULES:
		compiled.append(RegEx.create_from_string(rule[0]))
	var type_name := RegEx.create_from_string(TYPE_NAME)
	var lines := source.split("\n")
	for index: int in lines.size():
		var code := _strip_comment(lines[index])
		for rule_index: int in compiled.size():
			if compiled[rule_index].search(code) != null:
				violations.append("line %d: %s" % [index + 1, RULES[rule_index][1]])
		for found: RegExMatch in type_name.search_all(code):
			var reason := _engine_type_reason(found.get_string())
			if reason != "":
				violations.append("line %d: %s %s" % [index + 1, reason, found.get_string()])
	return violations


## Scans every .gd file under a folder. Callers check the folder exists.
static func scan_sim_folder(folder: String = SIM_DIR) -> PackedStringArray:
	var violations := PackedStringArray()
	for path: String in _gd_files(folder):
		var source := FileAccess.get_file_as_string(path)
		for violation: String in find_violations(source):
			violations.append("%s %s" % [path, violation])
	return violations


## "node type" or "resource type" for engine classes the simulation must not
## use, otherwise "".
static func _engine_type_reason(name: String) -> String:
	if not ClassDB.class_exists(name):
		return ""
	if name == "Node" or ClassDB.is_parent_class(name, "Node"):
		return "node type"
	if name == "Resource" or ClassDB.is_parent_class(name, "Resource"):
		return "resource type"
	return ""


static func _strip_comment(line: String) -> String:
	var hash_at := line.find("#")
	return line if hash_at == -1 else line.substr(0, hash_at)


static func _gd_files(folder: String) -> PackedStringArray:
	var files := PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return files
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			files.append(folder.path_join(name))
	for name: String in dir.get_directories():
		files.append_array(_gd_files(folder.path_join(name)))
	return files
