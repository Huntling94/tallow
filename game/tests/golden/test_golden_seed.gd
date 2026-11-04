extends GdUnitTestSuite
## Golden seeds: fixed seeds whose results are pinned. If a change to the rules
## or data alters these on purpose, update them in the same pull request and
## say why in its description. CI runs on Linux, so these also check that
## Windows and Linux agree.

## Spec 0037: seed 42's first season with no defences.
const HERD_42 := 24
const BANDS_42: Array[int] = [4, 6, 5, 3, 6]
const ROUTES_42: Array[String] = ["cairn_pass", "low_ford", "low_ford", "low_ford", "cairn_pass"]

## Spec 0040: seed 42 with the demo plan over 5 seasons.
const DEMO_ROUTES_42: Array[String] = [
	"cairn_pass", "split_ridge", "split_ridge", "split_ridge", "split_ridge"
]
const DEMO_KILLED_42 := 2
const DEMO_BREACHED_42 := 22
const DEMO_FINAL_MONEY_42 := -530

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_seed_42_first_season_without_defences() -> void:
	var events := SeasonRun.new(_setup, RandomStreams.new(42)).run(1, {})
	var arrival: Dictionary = events.filter(_of_type("herd_arrived"))[0]
	var choices := events.filter(_of_type("route_chosen"))
	assert_int(arrival["herd_size"]).is_equal(HERD_42)
	assert_array(choices.map(func(e: Dictionary) -> int: return e["beasts"])).is_equal(BANDS_42)
	assert_array(choices.map(func(e: Dictionary) -> String: return e["route"])).is_equal(ROUTES_42)


func test_seed_42_with_the_demo_plan() -> void:
	var run := SeasonRun.new(_setup, RandomStreams.new(42))
	var events := run.run(5, GameData.load_plan("demo"))
	var first_season := events.filter(func(e: Dictionary) -> bool: return e["season"] == 1)
	var first_end: Dictionary = first_season.filter(_of_type("season_ended"))[0]
	(
		assert_array(
			first_season.filter(_of_type("route_chosen")).map(
				func(e: Dictionary) -> String: return e["route"]
			)
		)
		. is_equal(DEMO_ROUTES_42)
	)
	assert_int(first_end["killed"]).is_equal(DEMO_KILLED_42)
	assert_int(first_end["breached"]).is_equal(DEMO_BREACHED_42)
	assert_int(run.state.money).is_equal(DEMO_FINAL_MONEY_42)


func _of_type(type: String) -> Callable:
	return func(e: Dictionary) -> bool: return e["type"] == type
