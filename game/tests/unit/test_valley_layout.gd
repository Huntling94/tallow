extends GdUnitTestSuite
## The map layout covers the valley: every route is drawn, joined end to end
## (spec 0043, AC1).

const JOIN_TOLERANCE := 0.01


func _layout() -> ValleyLayout:
	return ValleyLayout.new(GameData.load_valley("grey_box"))


func _braided() -> ValleyLayout:
	return ValleyLayout.new(GameData.load_valley("braided"))


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


func test_each_valley_draws_only_its_own_segments() -> void:
	assert_array(Array(_layout().drawn_segments())).not_contains(["saddle", "spur"])
	assert_array(Array(_braided().drawn_segments())).contains(["saddle", "spur"])


func test_every_braided_route_has_a_path_joined_end_to_end() -> void:
	var graph := GameData.load_valley("braided")
	var layout := ValleyLayout.new(graph)
	assert_array(Array(layout.missing_segments())).is_empty()
	var gate: Vector2 = ValleyLayout.PATHS["town_approach"][-1]
	for route_id: String in graph.route_ids:
		var at: Vector2 = ValleyLayout.PATHS["neck_pass"][0]
		for segment_id: String in graph.route_segments(route_id):
			assert_float(layout.point_at(segment_id, 0.0).distance_to(at)).is_less(JOIN_TOLERANCE)
			at = layout.point_at(segment_id, 1.0)
		assert_float(at.distance_to(gate)).is_less(JOIN_TOLERANCE)


func test_five_routes_have_five_colours() -> void:
	var graph := GameData.load_valley("braided")
	var layout := ValleyLayout.new(graph)
	var colours := []
	for route_id: String in graph.route_ids:
		var colour := layout.route_color(route_id)
		assert_array(colours).not_contains([colour])
		colours.append(colour)


func test_a_segment_two_routes_share_shows_both_colours() -> void:
	var layout := _braided()
	var colours := layout.segment_colors("ridge_drop")
	assert_array(colours).is_equal(
		[layout.route_color("the_saddle"), layout.route_color("split_ridge")]
	)
	assert_int(layout.segment_colors("saddle").size()).is_equal(1)
	assert_array(layout.segment_colors("neck_pass")).is_equal([ValleyLayout.SHARED_COLOR])


func test_the_share_through_a_segment_adds_up_its_routes() -> void:
	var layout := _braided()
	var routes := [
		{"route": "the_saddle", "p_ppm": 100000},
		{"route": "split_ridge", "p_ppm": 250000},
		{"route": "low_ford", "p_ppm": 650000},
	]
	assert_int(layout.herd_share_ppm("ridge_drop", routes)).is_equal(350000)
	assert_int(layout.herd_share_ppm("ford_bank", routes)).is_equal(650000)
	assert_int(layout.herd_share_ppm("neck_pass", routes)).is_equal(1000000)


func test_a_point_on_a_line_finds_that_segment() -> void:
	var layout := _braided()
	for segment_id: String in ValleyLayout.PATHS:
		var middle := layout.point_at(segment_id, 0.5)
		assert_str(layout.segment_at(middle, 12.0)).is_equal(segment_id)


func test_a_point_just_inside_the_tolerance_counts_and_one_outside_does_not() -> void:
	var layout := _layout()
	var middle := layout.point_at("neck_pass", 0.5)
	assert_str(layout.segment_at(middle + Vector2(11.5, 0), 12.0)).is_equal("neck_pass")
	assert_str(layout.segment_at(middle + Vector2(12.5, 0), 12.0)).is_empty()


func test_a_point_far_from_every_line_finds_nothing() -> void:
	assert_str(_layout().segment_at(Vector2(560, 40), 12.0)).is_empty()


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


func test_beasts_in_a_band_stand_in_different_places() -> void:
	assert_that(ValleyLayout.beast_spread(2, 3)).is_not_equal(ValleyLayout.beast_spread(2, 4))
