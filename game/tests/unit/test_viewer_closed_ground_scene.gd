extends GdUnitTestSuite
## Closed ground and the herd through a segment, on the played valley (spec 0054,
## AC6 and AC7).

const SCENE := "res://scenes/season_viewer.tscn"


func _viewer() -> SeasonViewer:
	var viewer: SeasonViewer = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(viewer)
	return viewer


## A viewer past its first release, watching season 1.
func _setup() -> RunSetup:
	return GameData.load_setup("braided", "steady")


## The same choices, played straight on the simulation. `seasons` holds one
## list of [defence, segment] pairs for each season.
func _text(viewer: SeasonViewer, node: String) -> String:
	return (viewer.get_node(node) as Label).text


## A real mouse click on the middle of a segment, in a map of this size.
func _click(viewer: SeasonViewer, segment_id: String, map_size := Vector2(600, 440)) -> void:
	var map := viewer.get_node("%Map") as RouteMap
	map.size = map_size
	var fit := minf(map_size.x / ValleyLayout.SHEET.x, map_size.y / ValleyLayout.SHEET.y)
	var layout := ValleyLayout.new(_setup().graph)
	var offset := (map_size - ValleyLayout.SHEET * fit) / 2.0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = offset + layout.point_at(segment_id, 0.5) * fit
	map._gui_input(click)


func _frame(viewer: SeasonViewer) -> Dictionary:
	return (viewer.get_node("%Map") as RouteMap)._frame


func _odds_text(viewer: SeasonViewer) -> String:
	var parts: PackedStringArray = []
	for row: Node in viewer.get_node("%Odds").get_children():
		parts.append((row.get_child(0) as Label).text)
	return " ".join(parts)


func test_a_closed_segment_has_no_room_and_the_panel_says_why() -> void:
	var viewer := _viewer()
	var spots := Array((viewer.get_node("%Map") as RouteMap).open_spots())
	assert_array(spots).contains(["cairn_west", "saddle"])
	assert_array(spots).not_contains(["neck_pass", "town_approach"])
	var odds := _odds_text(viewer)
	viewer.pick_defence("harpoon_tower")
	for segment_id: String in ["neck_pass", "town_approach"]:
		_click(viewer, segment_id)
		assert_str(_text(viewer, "%Hint")).is_equal(SeasonViewer.HINT_CLOSED)
		assert_dict(_frame(viewer)["defences"]).is_empty()
		assert_str(_text(viewer, "%Totals")).contains("Money  300")
		assert_str(_odds_text(viewer)).is_equal(odds)


func test_a_closed_segment_says_so_with_nothing_picked() -> void:
	var viewer := _viewer()
	_click(viewer, "neck_pass")
	assert_str(_text(viewer, "%Hint")).is_equal(SeasonViewer.HINT_CLOSED)


func test_hovering_a_segment_shows_the_herd_through_it() -> void:
	var viewer := _viewer()
	var map := viewer.get_node("%Map") as RouteMap
	map.size = ValleyLayout.SHEET
	var motion := InputEventMouseMotion.new()
	motion.position = ValleyLayout.new(_setup().graph).point_at("ridge_drop", 0.5)
	map._gui_input(motion)
	var before_fence := map.hover_share()
	var routes: Array = _frame(viewer)["routes"]
	var expected := 0
	for option: Dictionary in routes:
		if option["route"] in ["the_saddle", "split_ridge"]:
			expected += option["p_ppm"]
	assert_float(before_fence).is_equal_approx(expected / 10000.0, 0.001)
	viewer.pick_defence("fence")
	_click(viewer, "ridge_climb")
	assert_float(map.hover_share()).is_not_equal(before_fence)
