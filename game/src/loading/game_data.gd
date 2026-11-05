class_name GameData
extends RefCounted
## Reads the game's data files and turns them into the typed values the
## simulation takes (specs 0037, 0040 and 0044). The simulation never reads files
## itself (ADR-0002); this loader does, then checks what it read. Every
## problem is reported with push_error, and the loader returns null.

const DATA := "res://data"
const VALLEYS := "res://data/valleys"
const HERDS := "res://data/herds"
const PLANS := "res://data/plans"

const HERD_FIELDS := {
	"id": TYPE_STRING,
	"weights.length_per_km": TYPE_FLOAT,
	"weights.rough_per_km": TYPE_FLOAT,
	"weights.threat": TYPE_FLOAT,
	"herd_size.min": TYPE_INT,
	"herd_size.max": TYPE_INT,
	"band_size.min": TYPE_INT,
	"band_size.max": TYPE_INT,
}
const DEFENCE_FIELDS := {
	"id": TYPE_STRING,
	"name": TYPE_STRING,
	"cost": TYPE_INT,
	"threat": TYPE_INT,
	"kill_ppm": TYPE_INT,
	"capacity": TYPE_INT,
}
const RULE_FIELDS := {
	"start_money": TYPE_INT,
	"season_levy": TYPE_INT,
	"breach_cost_per_beast": TYPE_INT,
	"beast_speed_m_per_tick": TYPE_INT,
	"band_spacing_ticks": TYPE_INT,
	"goods_per_beast": TYPE_INT,
	"price_per_good": TYPE_INT,
}
const COMMAND_FIELDS := {"command": TYPE_STRING, "defence": TYPE_STRING, "segment": TYPE_STRING}


## The valley, herd, defence types and run rules for a run, or null.
static func load_setup(valley_id: String, herd_id: String) -> RunSetup:
	var graph := load_valley(valley_id)
	var herd := load_herd(herd_id)
	var defences := load_defences()
	var rules := load_run_rules()
	if graph == null or herd == null or defences.is_empty() or rules == null:
		return null
	return RunSetup.new(graph, herd, defences, rules)


## The named valley from game/data/valleys, or null.
static func load_valley(valley_id: String) -> RouteGraph:
	return load_valley_file(VALLEYS.path_join(valley_id + ".json"))


static func load_valley_file(path: String) -> RouteGraph:
	var data: Variant = _read_json(path)
	if data == null:
		return null
	var graph := parse_valley(data)
	return graph if _ok(path, graph.errors()) else null


## Builds a graph from parsed JSON. Problems with the file's shape show up in
## the graph's errors() rather than stopping, so every problem is reported.
static func parse_valley(data: Variant) -> RouteGraph:
	if not data is Dictionary:
		return RouteGraph.new("invalid", "", "")
	var valley: Dictionary = data
	var graph := RouteGraph.new(
		str(valley.get("id", "")), str(valley.get("entry", "")), str(valley.get("gate", ""))
	)
	for segment: Dictionary in valley.get("segments", []):
		(
			graph
			. add_segment(
				str(segment.get("id", "")),
				str(segment.get("from", "")),
				str(segment.get("to", "")),
				int(segment.get("length_m", 0)),
				float(segment.get("roughness", 0.0)),
			)
		)
	for route: Dictionary in valley.get("routes", []):
		(
			graph
			. add_route(
				str(route.get("id", "")),
				str(route.get("name", "")),
				PackedStringArray(route.get("segments", [])),
			)
		)
	return graph


## The named herd personality from game/data/herds, or null.
static func load_herd(herd_id: String) -> HerdPersonality:
	return load_herd_file(HERDS.path_join(herd_id + ".json"))


static func load_herd_file(path: String) -> HerdPersonality:
	var data: Variant = _read_json(path)
	if data == null or not _ok(path, check_herd(data)):
		return null
	return HerdPersonality.new(
		str(_lookup(data, "id")),
		_float(data, "weights.length_per_km"),
		_float(data, "weights.rough_per_km"),
		_float(data, "weights.threat"),
		_int(data, "herd_size.min"),
		_int(data, "herd_size.max"),
		_int(data, "band_size.min"),
		_int(data, "band_size.max")
	)


## Problems with a parsed herd file, one line each; empty if it is usable.
static func check_herd(data: Variant) -> PackedStringArray:
	var problems := _check_fields(data, HERD_FIELDS, "")
	if not problems.is_empty():
		return problems
	for size: String in ["herd_size", "band_size"]:
		if _int(data, size + ".min") > _int(data, size + ".max"):
			problems.append("%s.min is above %s.max" % [size, size])
	if _int(data, "herd_size.min") < 1:
		problems.append("herd_size.min must be at least 1")
	if _int(data, "band_size.min") < 1:
		problems.append("band_size.min must be at least 1")
	return problems


## Defence id -> DefenceType from game/data/defences.json, or empty.
static func load_defences() -> Dictionary:
	var path := DATA.path_join("defences.json")
	var data: Variant = _read_json(path)
	var file: Dictionary = data if data is Dictionary else {}
	var problems: PackedStringArray = []
	if not file.get("defences") is Array:
		problems.append("expected an object with a defences list")
	else:
		var entries: Array = file["defences"]
		for index: int in entries.size():
			var entry: Variant = entries[index]
			problems.append_array(_check_fields(entry, DEFENCE_FIELDS, "defences[%d]." % index))
			if problems.is_empty():
				if _int(entry, "kill_ppm") < 0 or _int(entry, "kill_ppm") > Night.PPM:
					problems.append("defences[%d].kill_ppm must be 0 to 1000000" % index)
				for field: String in ["cost", "threat", "capacity"]:
					if _int(entry, field) < 0:
						problems.append("defences[%d].%s must not be negative" % [index, field])
	if data == null or not _ok(path, problems):
		return {}
	var defences := {}
	for entry: Dictionary in file["defences"]:
		var defence := DefenceType.new(
			entry["id"],
			entry["name"],
			int(entry["cost"]),
			int(entry["threat"]),
			int(entry["kill_ppm"]),
			int(entry["capacity"])
		)
		defences[defence.id] = defence
	return defences


## The run rules from game/data/run_rules.json, or null.
static func load_run_rules() -> RunRules:
	var path := DATA.path_join("run_rules.json")
	var data: Variant = _read_json(path)
	if data == null or not _ok(path, check_run_rules(data)):
		return null
	return RunRules.new(
		_int(data, "start_money"),
		_int(data, "season_levy"),
		_int(data, "breach_cost_per_beast"),
		_int(data, "beast_speed_m_per_tick"),
		_int(data, "band_spacing_ticks"),
		_int(data, "goods_per_beast"),
		_int(data, "price_per_good")
	)


## Problems with parsed run rules, one line each; empty if they are usable.
static func check_run_rules(data: Variant) -> PackedStringArray:
	var problems := _check_fields(data, RULE_FIELDS, "")
	if not problems.is_empty():
		return problems
	for field: String in ["beast_speed_m_per_tick", "band_spacing_ticks"]:
		if _int(data, field) < 1:
			problems.append("%s must be at least 1" % field)
	for field: String in ["goods_per_beast", "price_per_good"]:
		if _int(data, field) < 0:
			problems.append("%s must not be negative" % field)
	return problems


## A scripted plan from game/data/plans: season number -> list of commands.
## Returns an empty plan, with an error reported, if the file is unusable.
## Whether each command can be carried out is the simulation's call.
static func load_plan(plan_id: String) -> Dictionary:
	var path := PLANS.path_join(plan_id + ".json")
	var data: Variant = _read_json(path)
	var file: Dictionary = data if data is Dictionary else {}
	var seasons: Dictionary = file.get("seasons") if file.get("seasons") is Dictionary else {}
	var problems: PackedStringArray = []
	if not file.get("seasons") is Dictionary:
		problems.append("expected an object with a seasons object")
	else:
		for season: String in seasons:
			if not season.is_valid_int() or season.to_int() < 1:
				problems.append("season %s must be a whole number from 1" % season)
			elif not seasons[season] is Array:
				problems.append("season %s must be a list of commands" % season)
			else:
				var commands: Array = seasons[season]
				for index: int in commands.size():
					var command: Variant = commands[index]
					var prefix := "seasons.%s[%d]." % [season, index]
					problems.append_array(_check_fields(command, COMMAND_FIELDS, prefix))
	if data == null or not _ok(path, problems):
		return {}
	var plan := {}
	for season: String in seasons:
		plan[season.to_int()] = seasons[season]
	return plan


## Checks that each dotted field exists with the right type. JSON numbers
## arrive as floats, so TYPE_INT means a number with no fraction.
static func _check_fields(data: Variant, fields: Dictionary, prefix: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	if not data is Dictionary:
		problems.append("%sexpected an object" % prefix)
		return problems
	for field: String in fields:
		var value: Variant = _lookup(data, field)
		var name := prefix + field
		if value == null:
			problems.append("missing %s" % name)
		elif fields[field] == TYPE_STRING and not value is String:
			problems.append("%s must be text" % name)
		elif fields[field] != TYPE_STRING and not (value is float or value is int):
			problems.append("%s must be a number" % name)
		elif fields[field] == TYPE_INT and float(value) != floorf(float(value)):
			problems.append("%s must be a whole number" % name)
	return problems


static func _lookup(data: Variant, field: String) -> Variant:
	var value: Variant = data
	for part: String in field.split("."):
		if not value is Dictionary:
			return null
		var level: Dictionary = value
		if not level.has(part):
			return null
		value = level[part]
	return value


static func _int(data: Variant, field: String) -> int:
	return int(_lookup(data, field))


static func _float(data: Variant, field: String) -> float:
	return float(_lookup(data, field))


static func _ok(path: String, problems: PackedStringArray) -> bool:
	if problems.is_empty():
		return true
	push_error("GameData: %s: %s" % [path, "; ".join(problems)])
	return false


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: cannot open %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("GameData: %s is not valid JSON" % path)
	return data
