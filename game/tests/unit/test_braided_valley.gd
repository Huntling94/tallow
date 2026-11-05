extends GdUnitTestSuite
## Spec 0054, AC1 and AC2: five routes that overlap in part, with odds close
## enough that every route matters.

const ENDS := ["neck_pass", "town_approach"]
const MIN_SHARE := 120000
const MAX_SHARE := 280000


func _graph() -> RouteGraph:
	return GameData.load_valley("braided")


func _routes_through(graph: RouteGraph, segment_id: String) -> int:
	var count := 0
	for route_id: String in graph.route_ids:
		if graph.route_segments(route_id).has(segment_id):
			count += 1
	return count


func test_it_loads_five_connected_routes() -> void:
	var graph := _graph()
	assert_object(graph).is_not_null()
	assert_int(graph.route_ids.size()).is_equal(5)
	assert_array(Array(graph.errors())).is_empty()


func test_every_route_shares_a_middle_segment_with_another() -> void:
	var graph := _graph()
	for route_id: String in graph.route_ids:
		var shared := 0
		for segment_id: String in graph.route_segments(route_id):
			if not ENDS.has(segment_id) and _routes_through(graph, segment_id) > 1:
				shared += 1
		assert_int(shared).is_greater(0)


func test_only_the_ends_are_on_more_than_two_routes() -> void:
	var graph := _graph()
	for route_id: String in graph.route_ids:
		for segment_id: String in graph.route_segments(route_id):
			if not ENDS.has(segment_id):
				assert_int(_routes_through(graph, segment_id)).is_less_equal(2)


func test_no_route_is_left_out_or_runs_away_with_the_herd() -> void:
	var utilities := RouteChoice.utilities(_graph(), GameData.load_herd("steady"))
	for share: int in RouteChoice.probabilities_ppm(utilities):
		assert_int(share).is_between(MIN_SHARE, MAX_SHARE)
