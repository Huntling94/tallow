class_name GameData
extends RefCounted
## Reads the game's data files and turns them into the typed values the
## simulation takes (spec 0037). The simulation never reads files itself
## (ADR-0002); this loader does, then checks what it read.

const VALLEYS := "res://data/valleys"
const HERDS := "res://data/herds"


## The named valley from game/data/valleys, or null with an error reported.
static func load_valley(valley_id: String) -> RouteGraph:
	return load_valley_file(VALLEYS.path_join(valley_id + ".json"))


static func load_valley_file(path: String) -> RouteGraph:
	var data: Variant = _read_json(path)
	if data == null:
		return null
	var graph := parse_valley(data)
	var problems := graph.errors()
	if not problems.is_empty():
		push_error("GameData: %s: %s" % [path, "; ".join(problems)])
		return null
	return graph


## Builds a graph from parsed JSON. Problems with the file's shape are added to
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


## The named herd personality from game/data/herds, or null with an error reported.
static func load_herd(herd_id: String) -> HerdPersonality:
	var path := HERDS.path_join(herd_id + ".json")
	var data: Variant = _read_json(path)
	if not data is Dictionary:
		if data != null:
			push_error("GameData: %s: expected an object" % path)
		return null
	var personality: Dictionary = data
	for key: String in ["id", "weights", "herd_size", "band_size"]:
		if not personality.has(key):
			push_error("GameData: %s: missing %s" % [path, key])
			return null
	var weights: Dictionary = personality["weights"]
	var herd_size: Dictionary = personality["herd_size"]
	var band_size: Dictionary = personality["band_size"]
	return HerdPersonality.new(
		str(personality["id"]),
		float(weights["length_per_km"]),
		float(weights["rough_per_km"]),
		float(weights["threat"]),
		int(herd_size["min"]),
		int(herd_size["max"]),
		int(band_size["min"]),
		int(band_size["max"])
	)


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameData: cannot open %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("GameData: %s is not valid JSON" % path)
	return data
