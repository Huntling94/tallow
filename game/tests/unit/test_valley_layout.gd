extends GdUnitTestSuite
## The map layout covers the valley: every route is drawn, joined end to end
## (spec 0043, AC1).

const JOIN_TOLERANCE := 0.01


func _layout() -> ValleyLayout:
	return ValleyLayout.new(GameData.load_valley("grey_box"))


func test_every_segment_on_every_route_has_a_path() -> void:
	assert_array(Array(_layout().missing_segments())).is_empty()


func test_a_segment_the_layout_does_not_know_is_reported() -> void:
	var graph := RouteGraph.new("other", "a", "b")
	graph.add_segment("unmapped", "a", "b", 100, 0.0)
	graph.add_route("only", "Only", PackedStringArray(["unmapped"]))
	var missing := ValleyLayout.new(graph).missing_segments()
	assert_array(Array(missing)).contains_exactly(["unmapped"])


func test_each_route_joins_end_to_end_from_the_neck_to_the_gate() -> void:
	var graph := GameData.load_valley("grey_box")
	var layout := ValleyLayout.new(graph)
	var entry: Vector2 = ValleyLayout.PATHS["neck_pass"][0]
	var gate: Vector2 = ValleyLayout.PATHS["town_approach"][-1]
	for route_id: String in graph.route_ids:
		var at := entry
		for segment_id: String in graph.route_segments(route_id):
			var start := layout.point_at(segment_id, 0.0)
			assert_float(start.distance_to(at)).is_less(JOIN_TOLERANCE)
			at = layout.point_at(segment_id, 1.0)
		assert_float(at.distance_to(gate)).is_less(JOIN_TOLERANCE)


func test_shared_segments_are_neutral_and_the_rest_take_their_route_colour() -> void:
	var graph := GameData.load_valley("grey_box")
	var layout := ValleyLayout.new(graph)
	assert_bool(layout.is_shared("neck_pass")).is_true()
	assert_bool(layout.is_shared("town_approach")).is_true()
	assert_that(layout.segment_color("neck_pass")).is_equal(ValleyLayout.SHARED_COLOR)
	assert_that(layout.segment_color("ford_bank")).is_equal(layout.route_color("low_ford"))
	assert_that(layout.segment_color("ridge_drop")).is_equal(layout.route_color("split_ridge"))
	assert_that(layout.route_color("cairn_pass")).is_not_equal(layout.route_color("low_ford"))


func test_a_share_of_a_segment_is_that_share_of_its_drawn_length() -> void:
	var layout := _layout()
	var path: Array = ValleyLayout.PATHS["neck_pass"]
	var middle: Vector2 = (path[0] + path[1]) / 2.0
	assert_float(layout.point_at("neck_pass", 0.5).distance_to(middle)).is_less(JOIN_TOLERANCE)


func test_a_place_on_a_route_follows_its_segments() -> void:
	var layout := _layout()
	var spot := layout.route_spot("low_ford", 2.5, 0.0)
	var expected := layout.point_at("ford_crossing", 0.5)
	assert_float((spot["position"] as Vector2).distance_to(expected)).is_less(JOIN_TOLERANCE)


func test_a_beast_held_back_stays_on_the_route_at_the_entry() -> void:
	var layout := _layout()
	var spot := layout.route_spot("low_ford", 0.0, 40.0)
	var entry := layout.point_at("neck_pass", 0.0)
	assert_float((spot["position"] as Vector2).distance_to(entry)).is_less(JOIN_TOLERANCE)


func test_a_beasts_place_in_its_band_never_changes() -> void:
	assert_that(ValleyLayout.beast_spread(2, 3)).is_equal(ValleyLayout.beast_spread(2, 3))
	assert_that(ValleyLayout.beast_spread(2, 3)).is_not_equal(ValleyLayout.beast_spread(2, 4))
