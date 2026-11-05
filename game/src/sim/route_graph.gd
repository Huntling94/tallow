class_name RouteGraph
extends RefCounted
## The valley as a graph: segments between named points, and named routes made
## of segments from the valley entry to the town gate (spec 0037). Route
## features add up over segments, so a segment shared by every route shifts
## every route equally and cannot change which way the herd comes.

var id: String
var entry: String
var gate: String
## Route ids in the order the valley file lists them; telemetry keeps this order.
var route_ids: PackedStringArray = []

var _segments := {}  # segment id -> {from, to, length_m, rough_m, closed}
var _routes := {}  # route id -> {name, segments}
var _problems: PackedStringArray = []  # bad file values found while loading


func _init(valley_id: String, entry_point: String, gate_point: String) -> void:
	id = valley_id
	entry = entry_point
	gate = gate_point


## Adds a segment. Rough metres are length × roughness, rounded to whole
## metres so they are exact on every platform. A closed segment is walked like
## any other, but nothing can be built on it (spec 0054).
func add_segment(
	segment_id: String,
	from: String,
	to: String,
	length_m: int,
	roughness: float,
	closed: bool = false
) -> void:
	_segments[segment_id] = {
		"from": from,
		"to": to,
		"length_m": length_m,
		"rough_m": roundi(length_m * roughness),
		"closed": closed,
	}


func add_route(route_id: String, display_name: String, segments: PackedStringArray) -> void:
	route_ids.append(route_id)
	_routes[route_id] = {"name": display_name, "segments": segments}


func route_name(route_id: String) -> String:
	return _routes[route_id]["name"]


func has_segment(segment_id: String) -> bool:
	return _segments.has(segment_id)


## The route's segments, from the entry to the gate.
func route_segments(route_id: String) -> PackedStringArray:
	return _routes[route_id]["segments"]


func segment_length(segment_id: String) -> int:
	return _segments[segment_id]["length_m"]


## True when the valley refuses building on this segment.
func is_closed(segment_id: String) -> bool:
	return _segments[segment_id]["closed"]


## Records a bad value from the valley file, reported by errors().
func add_problem(problem: String) -> void:
	_problems.append(problem)


## Total length, rough metres and threat over the route's segments. Threat
## comes from the defences standing on them (segment id -> threat units).
func features(route_id: String, threat_by_segment: Dictionary = {}) -> Dictionary:
	var totals := {"length_m": 0, "rough_m": 0, "threat": 0}
	for segment_id: String in _routes[route_id]["segments"]:
		var segment: Dictionary = _segments[segment_id]
		totals["length_m"] += segment["length_m"]
		totals["rough_m"] += segment["rough_m"]
		totals["threat"] += threat_by_segment.get(segment_id, 0)
	return totals


## Problems that make the graph unusable, one line each, naming the route or
## segment.
## Empty when every route is a connected chain from the entry to the gate.
func errors() -> PackedStringArray:
	var found := _problems.duplicate()
	if route_ids.is_empty():
		found.append("%s: no routes" % id)
	for route_id: String in route_ids:
		var segments: PackedStringArray = _routes[route_id]["segments"]
		var at := entry
		var broken := false
		for segment_id: String in segments:
			if not _segments.has(segment_id):
				found.append("%s: unknown segment %s" % [route_id, segment_id])
				broken = true
				break
			var segment: Dictionary = _segments[segment_id]
			if segment["from"] != at:
				found.append(
					(
						"%s: segment %s does not start where the route is (%s)"
						% [route_id, segment_id, at]
					)
				)
				broken = true
				break
			at = segment["to"]
		if not broken and at != gate:
			found.append("%s: ends at %s, not the gate" % [route_id, at])
	return found
