extends GdUnitTestSuite
## Spec 0037: the multinomial logit route choice, in whole parts per million.


func test_probabilities_match_hand_computed_values() -> void:
	var ppm := RouteChoice.probabilities_ppm(PackedFloat64Array([-4.4, -4.1, -4.0]))
	assert_float(ppm[0] / 1e6).is_equal_approx(0.2603, 0.00005)
	assert_float(ppm[1] / 1e6).is_equal_approx(0.3514, 0.00005)
	assert_float(ppm[2] / 1e6).is_equal_approx(0.3883, 0.00005)


func test_probabilities_sum_to_exactly_one_million() -> void:
	for utilities: PackedFloat64Array in [
		PackedFloat64Array([-4.4, -4.1, -4.0]),
		PackedFloat64Array([0.0, 0.0, 0.0]),
		PackedFloat64Array([-1.0, -30.0]),
		PackedFloat64Array([2.5, -0.3, 1.1, -7.0]),
	]:
		var total := 0
		for share: int in RouteChoice.probabilities_ppm(utilities):
			assert_int(share).is_greater_equal(0)
			total += share
		assert_int(total).is_equal(RouteChoice.PPM)


func test_adding_a_constant_to_every_utility_changes_nothing() -> void:
	var base := RouteChoice.probabilities_ppm(PackedFloat64Array([-4.4, -4.1, -4.0]))
	var shifted := RouteChoice.probabilities_ppm(PackedFloat64Array([-0.7, -0.4, -0.3]))
	for index: int in base.size():
		# One part per million of slack for the last bit of floating point.
		assert_int(absi(base[index] - shifted[index])).is_less_equal(1)


func test_a_segment_shared_by_every_route_cannot_change_the_odds() -> void:
	var herd := _herd()
	var short_shared := RouteChoice.probabilities_ppm(RouteChoice.utilities(_graph(500, 0.1), herd))
	var long_shared := RouteChoice.probabilities_ppm(RouteChoice.utilities(_graph(4000, 0.9), herd))
	for index: int in short_shared.size():
		assert_int(absi(short_shared[index] - long_shared[index])).is_less_equal(1)


func test_route_features_add_up_over_segments() -> void:
	var graph := _graph(500, 0.1)
	var features := graph.features("west")
	assert_int(features["length_m"]).is_equal(500 + 2000)
	assert_int(features["rough_m"]).is_equal(50 + 400)
	assert_int(features["threat"]).is_equal(0)


func test_utility_follows_the_herd_weights() -> void:
	var utilities := RouteChoice.utilities(_graph(500, 0.1), _herd())
	# west: 2.5 km and 0.45 rough km; east: 1.5 km and 0.95 rough km.
	assert_float(utilities[0]).is_equal_approx(-1.0 * 2.5 - 2.0 * 0.45, 1e-9)
	assert_float(utilities[1]).is_equal_approx(-1.0 * 1.5 - 2.0 * 0.95, 1e-9)


func test_a_draw_picks_the_route_whose_share_it_falls_in() -> void:
	var ppm := PackedInt64Array([200000, 300000, 500000])
	assert_int(RouteChoice.choose(ppm, 0)).is_equal(0)
	assert_int(RouteChoice.choose(ppm, 199999)).is_equal(0)
	assert_int(RouteChoice.choose(ppm, 200000)).is_equal(1)
	assert_int(RouteChoice.choose(ppm, 499999)).is_equal(1)
	assert_int(RouteChoice.choose(ppm, 500000)).is_equal(2)
	assert_int(RouteChoice.choose(ppm, 999999)).is_equal(2)


## Two routes, west and east, sharing one entry segment of the given size.
func _graph(shared_length_m: int, shared_roughness: float) -> RouteGraph:
	var graph := RouteGraph.new("test", "entry", "gate")
	graph.add_segment("shared", "entry", "fork", shared_length_m, shared_roughness)
	graph.add_segment("west_leg", "fork", "gate", 2000, 0.2)
	graph.add_segment("east_leg", "fork", "gate", 1000, 0.9)
	graph.add_route("west", "West", PackedStringArray(["shared", "west_leg"]))
	graph.add_route("east", "East", PackedStringArray(["shared", "east_leg"]))
	return graph


func _herd() -> HerdPersonality:
	return HerdPersonality.new("test", -1.0, -2.0, -1.5, 18, 30, 3, 6)
