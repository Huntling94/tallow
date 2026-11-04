extends GdUnitTestSuite
## Spec 0037: each season a herd arrives, splits into bands, and each band
## chooses a route on the route graph.

## Seed 42's first season, pinned. If a change to the rules alters these on
## purpose, update them in the same pull request.
const GOLDEN_HERD_SIZE := 24
const GOLDEN_BAND_SIZES: Array[int] = [4, 6, 5, 3, 6]
const GOLDEN_ROUTES: Array[String] = [
	"cairn_pass", "low_ford", "low_ford", "low_ford", "cairn_pass"
]

var _graph: RouteGraph
var _herd: HerdPersonality


func before() -> void:
	_graph = GameData.load_valley("grey_box")
	_herd = GameData.load_herd("steady")


func test_each_season_runs_arrival_options_choices_then_end() -> void:
	var events := _run(42, 3)
	var by_season := {}
	for event: Dictionary in events:
		var types: Array = by_season.get_or_add(event["season"], [])
		types.append(event["type"])
	assert_array(by_season.keys()).is_equal([1, 2, 3])
	for season: int in by_season:
		var types: Array = by_season[season]
		assert_str(types[0]).is_equal("herd_arrived")
		assert_str(types[1]).is_equal("route_options")
		assert_str(types[-1]).is_equal("season_ended")
		for type: String in types.slice(2, -1):
			assert_str(type).is_equal("route_chosen")


func test_events_are_ordered_by_season_tick_and_seq() -> void:
	var events := _run(42, 4)
	for index: int in range(1, events.size()):
		var before_key := _key(events[index - 1])
		var after_key := _key(events[index])
		assert_bool(before_key < after_key).is_true()


func test_bands_add_up_to_the_herd_and_stay_in_range() -> void:
	var events := _run(7, 20)
	var arrival: Dictionary
	var beasts := 0
	var bands := 0
	for event: Dictionary in events:
		match event["type"]:
			"herd_arrived":
				arrival = event
				beasts = 0
				bands = 0
				assert_int(event["herd_size"]).is_between(_herd.herd_min, _herd.herd_max)
			"route_chosen":
				beasts += event["beasts"]
				bands += 1
				assert_int(event["band"]).is_equal(bands)
				assert_int(event["beasts"]).is_between(
					_herd.band_min, _herd.band_max + _herd.band_min - 1
				)
				assert_array(Array(_graph.route_ids)).contains([event["route"]])
			"season_ended":
				assert_int(beasts).is_equal(arrival["herd_size"])
				assert_int(bands).is_equal(arrival["bands"])


func test_route_options_list_every_route_with_its_odds() -> void:
	var options: Dictionary = _run(42, 1)[1]
	var routes: Array = options["routes"]
	var total := 0
	for index: int in routes.size():
		var option: Dictionary = routes[index]
		assert_str(option["route"]).is_equal(_graph.route_ids[index])
		var features := _graph.features(option["route"])
		assert_int(option["length_m"]).is_equal(features["length_m"])
		assert_int(option["rough_m"]).is_equal(features["rough_m"])
		assert_int(option["threat"]).is_equal(0)
		total += option["p_ppm"]
	assert_int(total).is_equal(RouteChoice.PPM)


func test_the_same_seed_gives_the_same_events() -> void:
	assert_array(_run(42, 5)).is_equal(_run(42, 5))
	assert_array(_run(42, 5)).is_not_equal(_run(43, 5))


func test_seed_42_matches_the_golden_first_season() -> void:
	var events := _run(42, 1)
	var sizes: Array[int] = []
	var routes: Array[String] = []
	for event: Dictionary in events:
		if event["type"] == "route_chosen":
			sizes.append(event["beasts"])
			routes.append(event["route"])
	assert_int(events[0]["herd_size"]).is_equal(GOLDEN_HERD_SIZE)
	assert_array(sizes).is_equal(GOLDEN_BAND_SIZES)
	assert_array(routes).is_equal(GOLDEN_ROUTES)


func test_the_season_run_never_creates_its_own_streams() -> void:
	var source := FileAccess.get_file_as_string("res://src/sim/season_run.gd")
	assert_str(source).is_not_empty()
	assert_str(source).not_contains("RandomStreams.new")


func _run(run_seed: int, seasons: int) -> Array[Dictionary]:
	return SeasonRun.new().run(RandomStreams.new(run_seed), _graph, _herd, seasons)


func _key(event: Dictionary) -> Array:
	return [event["season"], event["tick"], event["seq"]]
