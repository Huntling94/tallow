class_name SimBoundary
extends RefCounted
## Finds references that ADR-0002 forbids in simulation code (game/src/sim/):
## scene, node and rendering types, the wall clock, unseeded randomness and
## file or resource loading.

const SIM_DIR := "res://src/sim"

## Each rule pairs a regular expression with the reason it is forbidden.
const RULES: Array[Array] = [
	[
		"\\b(Node|Node2D|Node3D|Control|CanvasItem|Viewport|SceneTree)\\b",
		"scene or node type",
	],
	["\\bget_tree\\s*\\(", "scene tree access"],
	["\\b(MeshInstance3D|Camera3D|RenderingServer|Sprite2D|Sprite3D)\\b", "rendering"],
	["\\bTime\\.", "wall-clock time"],
	["\\bOS\\.get_ticks_", "wall-clock time"],
	# Global functions only: "(?<![.\\w])" skips methods such as _rng.randi_range().
	[
		"(?<![.\\w])(randi|randf|randi_range|randf_range|randomize|seed)\\s*\\(",
		"unseeded randomness",
	],
	["(?<![.\\w])(load|preload)\\s*\\(", "resource loading"],
	["\\b(ResourceLoader|FileAccess|DirAccess)\\b", "file or resource access"],
	["\\bInput\\.", "input"],
]


## Returns one "line N: reason" entry per forbidden reference in the source.
## Comments are ignored.
static func find_violations(source: String) -> PackedStringArray:
	var violations := PackedStringArray()
	var compiled: Array[RegEx] = []
	for rule: Array in RULES:
		compiled.append(RegEx.create_from_string(rule[0]))
	var lines := source.split("\n")
	for index: int in lines.size():
		var code := _strip_comment(lines[index])
		for rule_index: int in compiled.size():
			if compiled[rule_index].search(code) != null:
				violations.append("line %d: %s" % [index + 1, RULES[rule_index][1]])
	return violations


## Scans every .gd file under the simulation folder. A missing folder has no
## violations.
static func scan_sim_folder(folder: String = SIM_DIR) -> PackedStringArray:
	var violations := PackedStringArray()
	for path: String in _gd_files(folder):
		var source := FileAccess.get_file_as_string(path)
		for violation: String in find_violations(source):
			violations.append("%s %s" % [path, violation])
	return violations


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
