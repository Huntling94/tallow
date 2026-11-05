class_name ValleyLayout
extends RefCounted
## Where the valley sits on the map (spec 0043). The valley data has no
## coordinates, so each segment gets a hand-placed path here. This is
## presentation, not rules: it lives outside game/data/ so that redrawing a
## line does not change the rules version. Distance along a path is a share
## of the segment, so a drawn length need not match the segment's metres.

## The sheet the paths are drawn on, in map units.
const SHEET := Vector2(600.0, 440.0)

## Segment id -> points from its start to its end. North is up: the herd
## enters at the top and the town is at the bottom.
const PATHS := {
	"neck_pass": [Vector2(300, 30), Vector2(300, 92)],
	"cairn_west": [Vector2(300, 92), Vector2(210, 128), Vector2(128, 205)],
	"cairn_south": [Vector2(128, 205), Vector2(118, 286), Vector2(190, 350), Vector2(300, 372)],
	"saddle": [Vector2(128, 205), Vector2(205, 234), Vector2(282, 228)],
	"ridge_climb": [Vector2(300, 92), Vector2(318, 160), Vector2(282, 228)],
	"ridge_drop": [Vector2(282, 228), Vector2(312, 300), Vector2(300, 372)],
	"spur": [Vector2(282, 228), Vector2(365, 268), Vector2(452, 300)],
	"ford_bank": [Vector2(300, 92), Vector2(392, 132), Vector2(468, 214)],
	"ford_crossing": [Vector2(468, 214), Vector2(452, 300)],
	"ford_flats": [Vector2(452, 300), Vector2(378, 352), Vector2(300, 372)],
	"town_approach": [Vector2(300, 372), Vector2(300, 418)],
}

## Route id -> where its name is drawn, and whether the text ends there.
const LABELS := {
	"cairn_pass": {"at": Vector2(106, 240), "right_aligned": true},
	"the_saddle": {"at": Vector2(150, 222), "right_aligned": false},
	"split_ridge": {"at": Vector2(328, 170), "right_aligned": false},
	"the_spur": {"at": Vector2(340, 300), "right_aligned": false},
	"low_ford": {"at": Vector2(482, 180), "right_aligned": false},
}

## A river for the Low Ford crossing to cross. Scenery only.
const RIVER: Array[Vector2] = [
	Vector2(372, 214), Vector2(415, 244), Vector2(460, 257), Vector2(520, 285), Vector2(596, 300)
]

const GROUND_COLOR := Color("121a1f")
const PANEL_COLOR := Color("19232a")
const INK_COLOR := Color("e4e6e1")
const MUTED_COLOR := Color("9aa5a3")
const TERRAIN_COLOR := Color("1e2a31")
const LAMP_COLOR := Color("f0a23c")
const DANGER_COLOR := Color("e0715f")
const SHARED_COLOR := MUTED_COLOR
const ROUTE_COLORS: Array[Color] = [
	Color("6fb3d4"), Color("d894b8"), Color("a998dc"), Color("d9c36a"), Color("7fc28f")
]

## How far along its segment a defence stands, in map units. Defences act as
## a band enters their segment, so the marker sits just inside the start.
const DEFENCE_INSET := 18.0

const SPREAD_SIDE := 13.0
const SPREAD_BACK := 16.0
## Fixed irrational steps spread a sequence evenly without any random
## numbers, so a beast keeps its place in the band on every frame.
const SIDE_STEP := 0.618034
const BACK_STEP := 0.754878

var _graph: RouteGraph


func _init(graph: RouteGraph) -> void:
	_graph = graph


## Route segments with no path here, so the viewer can say so, not crash.
func missing_segments() -> PackedStringArray:
	var missing: PackedStringArray = []
	for route_id: String in _graph.route_ids:
		for segment_id: String in _graph.route_segments(route_id):
			if not PATHS.has(segment_id) and not missing.has(segment_id):
				missing.append(segment_id)
	return missing


func route_color(route_id: String) -> Color:
	var index := _graph.route_ids.find(route_id)
	return ROUTE_COLORS[index % ROUTE_COLORS.size()]


## True when every route uses the segment, so it says nothing about the choice.
func is_shared(segment_id: String) -> bool:
	for route_id: String in _graph.route_ids:
		if not _graph.route_segments(route_id).has(segment_id):
			return false
	return true


## The segments of the loaded valley that have a path, in drawing order.
func drawn_segments() -> PackedStringArray:
	var found: PackedStringArray = []
	for segment_id: String in PATHS:
		if _graph.has_segment(segment_id):
			found.append(segment_id)
	return found


## The routes that use this segment, in the valley's order.
func routes_through(segment_id: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for route_id: String in _graph.route_ids:
		if _graph.route_segments(route_id).has(segment_id):
			found.append(route_id)
	return found


## The colours a segment is drawn in: both routes' on a segment two share,
## otherwise the one from segment_color.
func segment_colors(segment_id: String) -> Array[Color]:
	var routes := routes_through(segment_id)
	if routes.size() == 2 and not is_shared(segment_id):
		return [route_color(routes[0]), route_color(routes[1])]
	return [segment_color(segment_id)]


## The share of the herd expected through a segment, in parts per million:
## the odds of every route that uses it. `routes` holds route_options entries.
func herd_share_ppm(segment_id: String, routes: Array) -> int:
	var through := routes_through(segment_id)
	var total := 0
	for option: Dictionary in routes:
		if through.has(option["route"]):
			total += option["p_ppm"]
	return total


## Shared segments are neutral; the rest take the colour of their first route.
func segment_color(segment_id: String) -> Color:
	if is_shared(segment_id):
		return SHARED_COLOR
	for route_id: String in _graph.route_ids:
		if _graph.route_segments(route_id).has(segment_id):
			return route_color(route_id)
	return SHARED_COLOR


## The point `share` of the way along a segment, from 0 to 1.
func point_at(segment_id: String, share: float) -> Vector2:
	var points: Array = PATHS[segment_id]
	return _along(points, _length(points) * clampf(share, 0.0, 1.0))["position"]


## The valley segment whose line is nearest this point on the sheet, within
## `tolerance` map units, or "" if none is that close.
func segment_at(point: Vector2, tolerance: float) -> String:
	var nearest := ""
	var best := tolerance
	for segment_id: String in PATHS:
		if not _graph.has_segment(segment_id):
			continue
		var points: Array = PATHS[segment_id]
		for index: int in range(1, points.size()):
			var closest := Geometry2D.get_closest_point_to_segment(
				point, points[index - 1], points[index]
			)
			if point.distance_to(closest) <= best:
				best = point.distance_to(closest)
				nearest = segment_id
	return nearest


## Where a defence on this segment is drawn.
func defence_spot(segment_id: String) -> Vector2:
	var points: Array = PATHS[segment_id]
	return _along(points, minf(DEFENCE_INSET, _length(points) / 2.0))["position"]


## Position and heading at `progress` along a route, where 2.5 is halfway
## along its third segment, moved `back` map units towards the entry.
func route_spot(route_id: String, progress: float, back: float) -> Dictionary:
	var segments := _graph.route_segments(route_id)
	var index := mini(int(progress), segments.size() - 1)
	var share := progress - index
	var walked := 0.0
	var points: Array = []
	for position: int in segments.size():
		var path: Array = PATHS[segments[position]]
		if position < index:
			walked += _length(path)
		elif position == index:
			walked += _length(path) * share
		points.append_array(path if points.is_empty() else path.slice(1))
	return _along(points, maxf(walked - back, 0.0))


## A beast's offset within its band: x is to the side of the route, y is
## behind the band's front. Fixed for the beast, and look only.
static func beast_spread(band: int, index: int) -> Vector2:
	var side := fposmod((index + band) * SIDE_STEP, 1.0) - 0.5
	var back := fposmod(index * BACK_STEP + band * 0.1, 1.0)
	return Vector2(side * SPREAD_SIDE, back * SPREAD_BACK)


static func _length(points: Array) -> float:
	var total := 0.0
	for index: int in range(1, points.size()):
		var start: Vector2 = points[index - 1]
		total += start.distance_to(points[index])
	return total


static func _along(points: Array, distance: float) -> Dictionary:
	var left := distance
	for index: int in range(1, points.size()):
		var start: Vector2 = points[index - 1]
		var end: Vector2 = points[index]
		var length := start.distance_to(end)
		if left <= length or index == points.size() - 1:
			var weight := clampf(left / length, 0.0, 1.0) if length > 0.0 else 0.0
			return {"position": start.lerp(end, weight), "angle": start.angle_to_point(end)}
		left -= length
	return {"position": points[0], "angle": 0.0}
