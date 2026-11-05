class_name RouteMap
extends Control
## Draws the valley from above: terrain, routes, defences, beasts and the
## marks they leave. Everything it shows arrives in `show_frame`, from a
## SeasonReplay or a DefenceDraft, and nothing it does reaches the simulation.
## While picking, a click on a route is passed on as a segment id.

signal segment_pressed(segment_id: String)

const ROUTE_WIDTH := 6.0
const SHARED_WIDTH := 7.0
const BEAST_LENGTH := 6.0
const BEAST_WIDTH := 4.0
const LABEL_SIZE := 13
const SMALL_SIZE := 11
## How long a fresh kill or breach stays bright, in ticks.
const FLASH_TICKS := 1.5
const BREACH_NOTE_TICKS := 3.0
const GATE_GLOW_RADIUS := 20.0
const LAMP_RADIUS := 7.0
const KILL_SPREAD := Vector2(9.0, 7.0)
## How near a route a click must land, in map units.
const CLICK_TOLERANCE := 12.0
const HOVER_WIDTH := 12.0
const SPOT_RADIUS := 5.0
const STRIPE_LENGTH := 16.0
const NOTE_HEIGHT := 1.2
const NOTE_MARGIN := 4.0

var _layout: ValleyLayout
var _graph: RouteGraph
var _defence_types := {}
var _frame := {}
var _picking := false
var _hover := ""


## Everything that stays the same for a run.
func set_run(setup: RunSetup, layout: ValleyLayout) -> void:
	_graph = setup.graph
	_defence_types = setup.defences
	_layout = layout


func show_frame(frame: Dictionary) -> void:
	_frame = frame
	queue_redraw()


## While picking, routes answer to the mouse and open segments are marked.
func set_picking(picking: bool) -> void:
	_picking = picking
	_hover = ""
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _picking or _layout == null or _scale() <= 0.0:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var over := _segment_under(motion.position)
		if over != _hover:
			_hover = over
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var segment_id := _segment_under(click.position)
		if segment_id != "":
			segment_pressed.emit(segment_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover != "":
		_hover = ""
		queue_redraw()


## The share of the herd expected through the segment under the mouse, as a
## percentage, or -1 when the mouse is on no segment.
func hover_share() -> float:
	if _hover == "":
		return -1.0
	return _layout.herd_share_ppm(_hover, _frame["routes"]) / 10000.0


func _segment_under(point: Vector2) -> String:
	return _layout.segment_at(_to_sheet(point), CLICK_TOLERANCE)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ValleyLayout.PANEL_COLOR)
	if _layout == null or _frame.is_empty() or _scale() <= 0.0:
		return
	_draw_terrain()
	_draw_hover()
	_draw_routes()
	_draw_places()
	_draw_open_spots()
	_draw_hover_note()
	_draw_defences()
	_draw_kill_marks()
	_draw_bands()
	_draw_breach_marks()


## Map units to pixels: the whole sheet, centred, at the largest scale that fits.
func _scale() -> float:
	return minf(size.x / ValleyLayout.SHEET.x, size.y / ValleyLayout.SHEET.y)


func _to_screen(point: Vector2) -> Vector2:
	var sheet := ValleyLayout.SHEET * _scale()
	return (size - sheet) / 2.0 + point * _scale()


func _to_sheet(point: Vector2) -> Vector2:
	var sheet := ValleyLayout.SHEET * _scale()
	return (point - (size - sheet) / 2.0) / _scale()


func _draw_terrain() -> void:
	# Soft rings for the high ground between the routes, as on a survey chart.
	for ring: int in range(0, 4):
		var radius := 26.0 + ring * 22.0
		_draw_ring(Vector2(205, 250), Vector2(radius, radius * 1.5), -0.2)
		_draw_ring(Vector2(388, 238), Vector2(radius * 0.8, radius * 1.3), 0.25)
	for index: int in range(1, ValleyLayout.RIVER.size()):
		draw_dashed_line(
			_to_screen(ValleyLayout.RIVER[index - 1]),
			_to_screen(ValleyLayout.RIVER[index]),
			ValleyLayout.ROUTE_COLORS[0].darkened(0.35),
			3.0 * _scale(),
			6.0 * _scale()
		)


func _draw_ring(centre: Vector2, radii: Vector2, tilt: float) -> void:
	var points := PackedVector2Array()
	for step: int in 49:
		var angle := TAU * step / 48.0
		var spot := Vector2(cos(angle) * radii.x, sin(angle) * radii.y).rotated(tilt)
		points.append(_to_screen(centre + spot))
	draw_polyline(points, ValleyLayout.TERRAIN_COLOR, 2.0 * _scale(), true)


func _draw_routes() -> void:
	for segment_id: String in _layout.drawn_segments():
		if not _layout.is_shared(segment_id):
			_draw_path(segment_id, ROUTE_WIDTH)
	for segment_id: String in _layout.drawn_segments():
		if _layout.is_shared(segment_id):
			_draw_path(segment_id, SHARED_WIDTH)
	for option: Dictionary in _frame["routes"]:
		_draw_route_label(option)


func _draw_hover() -> void:
	if _hover == "":
		return
	var points := PackedVector2Array()
	for point: Vector2 in ValleyLayout.PATHS[_hover]:
		points.append(_to_screen(point))
	draw_polyline(points, ValleyLayout.LAMP_COLOR, HOVER_WIDTH * _scale(), true)


## The segments that get a ring: open ground with room for a defence, only
## while picking.
func open_spots() -> PackedStringArray:
	var spots: PackedStringArray = []
	if not _picking:
		return spots
	var defences: Dictionary = _frame["defences"]
	for segment_id: String in _layout.drawn_segments():
		if not _graph.is_closed(segment_id) and not defences.has(segment_id):
			spots.append(segment_id)
	return spots


func _draw_open_spots() -> void:
	for segment_id: String in open_spots():
		var centre := _to_screen(_layout.defence_spot(segment_id))
		var radius := SPOT_RADIUS * _scale()
		draw_circle(centre, radius, ValleyLayout.GROUND_COLOR)
		draw_arc(centre, radius, 0.0, TAU, 20, ValleyLayout.LAMP_COLOR, 1.5, true)


func _draw_hover_note() -> void:
	if _hover == "":
		return
	var text := "%.0f%% of the herd" % hover_share()
	var at := _layout.point_at(_hover, 0.5) + Vector2(10, -8)
	var pixels := maxi(int(LABEL_SIZE * _scale()), 8)
	var width := (
		ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	)
	var height := float(pixels) * NOTE_HEIGHT
	var corner := _to_screen(at) - Vector2(NOTE_MARGIN, height - NOTE_MARGIN)
	var box := Rect2(corner, Vector2(width + NOTE_MARGIN * 2.0, height + NOTE_MARGIN))
	draw_rect(box, ValleyLayout.GROUND_COLOR)
	_draw_text(at, text, ValleyLayout.LAMP_COLOR, LABEL_SIZE)


func _draw_path(segment_id: String, width: float) -> void:
	var colors := _layout.segment_colors(segment_id)
	var color := colors[0]
	var points := PackedVector2Array()
	for point: Vector2 in ValleyLayout.PATHS[segment_id]:
		points.append(_to_screen(point))
		draw_circle(_to_screen(point), width * _scale() / 2.0, color)
	draw_polyline(points, color, width * _scale(), true)
	if colors.size() > 1:
		for index: int in range(1, points.size()):
			draw_dashed_line(
				points[index - 1],
				points[index],
				colors[1],
				width * _scale(),
				STRIPE_LENGTH * _scale()
			)


func _draw_route_label(option: Dictionary) -> void:
	var route_id: String = option["route"]
	var label: Dictionary = ValleyLayout.LABELS.get(route_id, {})
	if label.is_empty():
		return
	var name_text := "%s  %.0f%%" % [_graph.route_name(route_id), option["p_ppm"] / 10000.0]
	var detail := "%.1f km" % (option["length_m"] / 1000.0)
	_draw_text(label["at"], name_text, ValleyLayout.INK_COLOR, LABEL_SIZE, label["right_aligned"])
	var below: Vector2 = label["at"] + Vector2(0, 16)
	_draw_text(below, detail, ValleyLayout.MUTED_COLOR, SMALL_SIZE, label["right_aligned"])


func _draw_places() -> void:
	var neck: Vector2 = ValleyLayout.PATHS["neck_pass"][0]
	var gate: Vector2 = ValleyLayout.PATHS["town_approach"][-1]
	_draw_text(neck + Vector2(14, 4), "THE NECK", ValleyLayout.MUTED_COLOR, SMALL_SIZE)
	_draw_text(gate + Vector2(14, 6), "TOWN GATE", ValleyLayout.LAMP_COLOR, LABEL_SIZE)
	var glow := ValleyLayout.LAMP_COLOR
	glow.a = 0.18
	draw_circle(_to_screen(gate), GATE_GLOW_RADIUS * _scale(), glow)
	draw_circle(_to_screen(gate), LAMP_RADIUS * _scale(), ValleyLayout.LAMP_COLOR)


func _draw_defences() -> void:
	var defences: Dictionary = _frame["defences"]
	var fresh: Dictionary = _frame["new_defences"]
	for segment_id: String in defences:
		var defence_id: String = defences[segment_id]
		var spot := _layout.defence_spot(segment_id)
		var color := ValleyLayout.LAMP_COLOR if fresh.has(segment_id) else ValleyLayout.DANGER_COLOR
		_draw_defence_marker(spot, defence_id, color)
		var defence: DefenceType = _defence_types[defence_id]
		var note := defence.display_name.to_upper()
		# Notes sit on the outer side of the map, clear of the other routes.
		var west := spot.x < ValleyLayout.SHEET.x / 2.0
		var at := spot + Vector2(-13 if west else 13, 4)
		_draw_text(at, note, color, SMALL_SIZE, west)


## A fence reads as a bar, a pit as a diamond and a tower as a triangle.
func _draw_defence_marker(spot: Vector2, defence_id: String, color: Color) -> void:
	var centre := _to_screen(spot)
	var unit := _scale()
	match defence_id:
		"fence":
			draw_rect(Rect2(centre - Vector2(11, 3) * unit, Vector2(22, 6) * unit), color)
		"pit":
			draw_colored_polygon(_polygon(centre, unit, [[0, -9], [9, 0], [0, 9], [-9, 0]]), color)
		_:
			draw_colored_polygon(_polygon(centre, unit, [[0, -10], [9, 7], [-9, 7]]), color)


func _polygon(centre: Vector2, unit: float, corners: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for corner: Array in corners:
		points.append(centre + Vector2(corner[0], corner[1]) * unit)
	return points


func _draw_kill_marks() -> void:
	var count := 0
	for mark: Dictionary in _frame["marks"]:
		if mark["kind"] != SeasonReplay.KILL:
			continue
		count += 1
		var spot := _layout.defence_spot(mark["segment"])
		# Kills at the same defence fan out, so each one can be counted.
		var scatter := ValleyLayout.beast_spread(count, count) / ValleyLayout.SPREAD_BACK
		var at := _to_screen(spot + scatter * KILL_SPREAD * 2.0)
		var arm := 4.0 * _scale()
		var fresh := clampf(1.0 - float(mark["age"]) / FLASH_TICKS, 0.0, 1.0)
		var color := ValleyLayout.DANGER_COLOR.lerp(ValleyLayout.INK_COLOR, fresh)
		draw_line(at - Vector2(arm, arm), at + Vector2(arm, arm), color, 2.0 * _scale(), true)
		draw_line(at - Vector2(arm, -arm), at + Vector2(arm, -arm), color, 2.0 * _scale(), true)
		if fresh > 0.0:
			var ring := ValleyLayout.DANGER_COLOR
			ring.a = fresh
			draw_arc(at, (8.0 + 12.0 * (1.0 - fresh)) * _scale(), 0.0, TAU, 24, ring, 2.0, true)


func _draw_bands() -> void:
	for band: Dictionary in _frame["bands"]:
		if band["state"] == SeasonReplay.GONE:
			continue
		for index: int in band["beasts"]:
			_draw_beast(band, index)


func _draw_beast(band: Dictionary, index: int) -> void:
	var spread := ValleyLayout.beast_spread(band["band"], index)
	var spot := _layout.route_spot(band["route"], band["progress"], spread.y)
	var angle: float = spot["angle"]
	var place: Vector2 = spot["position"] + Vector2(0.0, spread.x).rotated(angle)
	var color := _layout.route_color(band["route"])
	var stretch := Vector2(BEAST_LENGTH, BEAST_WIDTH) / BEAST_WIDTH
	draw_set_transform(_to_screen(place), angle, stretch)
	draw_circle(Vector2.ZERO, BEAST_WIDTH * _scale(), color)
	draw_arc(Vector2.ZERO, BEAST_WIDTH * _scale(), 0.0, TAU, 16, ValleyLayout.GROUND_COLOR, 1.0)
	draw_set_transform(Vector2.ZERO)


func _draw_breach_marks() -> void:
	var gate: Vector2 = ValleyLayout.PATHS["town_approach"][-1]
	for mark: Dictionary in _frame["marks"]:
		if mark["kind"] != SeasonReplay.BREACH or mark["age"] > BREACH_NOTE_TICKS:
			continue
		var fresh := 1.0 - float(mark["age"]) / BREACH_NOTE_TICKS
		var color := ValleyLayout.DANGER_COLOR
		color.a = fresh
		var radius := (GATE_GLOW_RADIUS + 18.0 * (1.0 - fresh)) * _scale()
		draw_arc(_to_screen(gate), radius, 0.0, TAU, 32, color, 3.0, true)
	var note: Dictionary = _frame["breach_note"]
	if not note.is_empty() and note["age"] <= BREACH_NOTE_TICKS:
		var note_color := ValleyLayout.DANGER_COLOR
		note_color.a = 1.0 - float(note["age"]) / BREACH_NOTE_TICKS
		var text := "BREACH %d" % note["beasts"]
		_draw_text(gate + Vector2(-32, 5), text, note_color, LABEL_SIZE, true)


func _draw_text(
	at: Vector2, text: String, color: Color, text_size: int, right_aligned: bool = false
) -> void:
	var font := ThemeDB.fallback_font
	var pixels := maxi(int(text_size * _scale()), 8)
	var spot := _to_screen(at)
	if right_aligned:
		spot.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(font, spot, text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, color)
