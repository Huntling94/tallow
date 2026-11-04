extends GdUnitTestSuite
## Spec 0040, AC1: a defence's threat steers the herd away from the routes
## through its segment, and a segment every route shares cannot steer.

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_a_fence_on_low_ford_moves_the_odds_to_the_other_routes() -> void:
	var base := _odds({})
	var fenced := _odds({"ford_crossing": "fence"})
	assert_int(fenced[2]).is_less(base[2])
	assert_int(fenced[0]).is_greater(base[0])
	assert_int(fenced[1]).is_greater(base[1])
	# Placeholder numbers from the spec: about 36.5% falls to about 2.8%.
	assert_float(fenced[2] / 1e6).is_equal_approx(0.028, 0.002)


func test_a_fence_on_a_shared_segment_changes_nothing() -> void:
	var base := _odds({})
	var fenced := _odds({"neck_pass": "fence"})
	for index: int in base.size():
		assert_int(absi(base[index] - fenced[index])).is_less_equal(1)


func test_threat_adds_up_over_a_route() -> void:
	var state := RunState.new(0)
	state.defences = {"cairn_west": "pit", "cairn_south": "fence"}
	var threat := state.threat_by_segment(_setup)
	assert_int(_setup.graph.features("cairn_pass", threat)["threat"]).is_equal(1 + 2)
	assert_int(_setup.graph.features("split_ridge", threat)["threat"]).is_equal(0)


func _odds(defences: Dictionary) -> PackedInt64Array:
	var state := RunState.new(0)
	state.defences = defences
	return RouteChoice.probabilities_ppm(
		RouteChoice.utilities(_setup.graph, _setup.herd, state.threat_by_segment(_setup))
	)
