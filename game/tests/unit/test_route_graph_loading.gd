extends GdUnitTestSuite
## Spec 0037, AC1: the valley and herd files load into checked, typed values.

const FIXTURES := "res://tests/fixtures/valleys"


func test_the_grey_box_valley_loads_with_three_connected_routes() -> void:
	var graph := GameData.load_valley("grey_box")
	assert_object(graph).is_not_null()
	assert_array(Array(graph.route_ids)).is_equal(["cairn_pass", "split_ridge", "low_ford"])
	assert_array(Array(graph.errors())).is_empty()


func test_every_grey_box_route_has_at_least_a_quarter_of_the_odds() -> void:
	var ppm := RouteChoice.probabilities_ppm(
		RouteChoice.utilities(GameData.load_valley("grey_box"), GameData.load_herd("steady"))
	)
	for share: int in ppm:
		assert_int(share).is_greater_equal(250000)


func test_a_closed_flag_that_is_not_true_or_false_names_its_segment() -> void:
	var segment := {"id": "neck", "from": "a", "to": "b", "length_m": 100, "closed": "yes"}
	var route := {"id": "only", "name": "Only", "segments": ["neck"]}
	var data := {"id": "bad", "entry": "a", "gate": "b", "segments": [segment], "routes": [route]}
	var errors := GameData.parse_valley(data).errors()
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("neck").contains("closed")


func test_a_segment_is_open_unless_the_valley_says_otherwise() -> void:
	var graph := GameData.load_valley("braided")
	assert_bool(graph.is_closed("neck_pass")).is_true()
	assert_bool(graph.is_closed("town_approach")).is_true()
	assert_bool(graph.is_closed("saddle")).is_false()
	assert_bool(GameData.load_valley("grey_box").is_closed("neck_pass")).is_false()


func test_the_steady_herd_loads_its_weights_and_sizes() -> void:
	var herd := GameData.load_herd("steady")
	assert_object(herd).is_not_null()
	assert_float(herd.weight_length_per_km).is_equal(-1.0)
	assert_float(herd.weight_rough_per_km).is_equal(-2.0)
	assert_float(herd.weight_threat).is_equal(-1.5)
	assert_int(herd.herd_min).is_equal(18)
	assert_int(herd.herd_max).is_equal(30)
	assert_int(herd.band_min).is_equal(3)
	assert_int(herd.band_max).is_equal(6)


func test_a_herd_with_a_missing_key_is_rejected() -> void:
	_assert_herd_rejected("missing_key.json", "weights.threat")


func test_a_herd_with_a_mistyped_value_is_rejected() -> void:
	_assert_herd_rejected("wrong_type.json", "weights.length_per_km must be a number")


func test_a_herd_with_min_above_max_is_rejected() -> void:
	_assert_herd_rejected("min_above_max.json", "herd_size.min is above herd_size.max")


func test_a_herd_with_empty_bands_is_rejected() -> void:
	_assert_herd_rejected("empty_bands.json", "band_size.min must be at least 1")


func test_the_defences_and_run_rules_load() -> void:
	var setup := GameData.load_setup("grey_box", "steady")
	assert_object(setup).is_not_null()
	assert_array(setup.defences.keys()).contains_exactly_in_any_order(
		["fence", "pit", "harpoon_tower"]
	)
	assert_int(setup.rules.start_money).is_equal(300)
	assert_int(setup.defences["pit"].capacity).is_equal(2)
	assert_int(setup.defences["harpoon_tower"].capacity).is_equal(8)
	assert_int(setup.rules.goods_per_beast).is_equal(4)
	assert_int(setup.rules.price_per_good).is_equal(5)


func test_the_demo_plan_loads_by_season() -> void:
	var plan := GameData.load_plan("demo")
	assert_array(plan.keys()).contains_exactly([1])
	assert_str(plan[1][0]["defence"]).is_equal("fence")


func test_the_chokepoints_plan_builds_a_tower_on_each_shared_segment() -> void:
	var plan := GameData.load_plan("chokepoints")
	assert_array(plan.keys()).contains_exactly([1])
	var segments: Array = plan[1].map(func(c: Dictionary) -> String: return c["segment"])
	assert_array(segments).contains_exactly(["neck_pass", "town_approach"])
	for command: Dictionary in plan[1]:
		assert_str(command["defence"]).is_equal("harpoon_tower")


func test_an_unknown_segment_is_reported_with_its_route() -> void:
	_assert_rejected("unknown_segment.json", "west: unknown segment ghost_leg")


func test_a_broken_chain_is_reported_with_its_route() -> void:
	_assert_rejected("broken_chain.json", "west: segment west_leg does not start where")


func test_a_route_that_misses_the_gate_is_reported() -> void:
	_assert_rejected("misses_gate.json", "west: ends at fork, not the gate")


func test_a_missing_file_gives_no_valley() -> void:
	assert_object(GameData.load_valley_file(FIXTURES.path_join("missing.json"))).is_null()


func _assert_rejected(file_name: String, expected: String) -> void:
	var path := FIXTURES.path_join(file_name)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var errors := GameData.parse_valley(data).errors()
	assert_str("\n".join(errors)).contains(expected)
	assert_object(GameData.load_valley_file(path)).is_null()


func _assert_herd_rejected(file_name: String, expected: String) -> void:
	var path := "res://tests/fixtures/herds".path_join(file_name)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_str("\n".join(GameData.check_herd(data))).contains(expected)
	assert_object(GameData.load_herd_file(path)).is_null()
