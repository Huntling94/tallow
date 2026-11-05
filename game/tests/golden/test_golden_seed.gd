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
## Spec 0054 moved the plan's pit to ridge_drop in season 1, and changed the
## start money and capacities, so these values changed with it.
const DEMO_ROUTES_42: Array[String] = [
	"cairn_pass", "split_ridge", "split_ridge", "split_ridge", "cairn_pass"
]
const DEMO_KILLED_42 := 5
const DEMO_BREACHED_42 := 19
## Spec 0044: no levy, a kill earns 20.
const DEMO_HARVEST_BEASTS_42 := 5
const DEMO_HARVEST_GOODS_42 := 20
const DEMO_HARVEST_INCOME_42 := 100
const DEMO_HARVEST_MONEY_42 := -30
const DEMO_FINAL_MONEY_42 := -540
## Spec 0054: seed 42's first season on the played valley, no defences.
const BRAIDED_HERD_42 := 24
const BRAIDED_DEMO_KILLED_42 := 4
const BRAIDED_DEMO_BREACHED_42 := 20
const BRAIDED_DEMO_FINAL_MONEY_42 := -870
const BRAIDED_ROUTES_42: Array[String] = [
	"cairn_pass", "the_spur", "low_ford", "low_ford", "the_saddle"
]

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
	var harvests := first_season.filter(_of_type("harvest"))
	assert_int(harvests.size()).is_equal(1)
	var first_harvest: Dictionary = {} if harvests.is_empty() else harvests[0]
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
	assert_int(first_harvest.get("beasts", -1)).is_equal(DEMO_HARVEST_BEASTS_42)
	assert_int(first_harvest.get("goods", -1)).is_equal(DEMO_HARVEST_GOODS_42)
	assert_int(first_harvest.get("income", -1)).is_equal(DEMO_HARVEST_INCOME_42)
	assert_int(first_harvest.get("money", -1)).is_equal(DEMO_HARVEST_MONEY_42)
	assert_int(run.state.money).is_equal(DEMO_FINAL_MONEY_42)


func test_seed_42_first_season_on_the_braided_valley() -> void:
	var setup := GameData.load_setup("braided", "steady")
	var events := SeasonRun.new(setup, RandomStreams.new(42)).run(1, {})
	var arrival: Dictionary = events.filter(_of_type("herd_arrived"))[0]
	var choices := events.filter(_of_type("route_chosen"))
	assert_int(arrival["herd_size"]).is_equal(BRAIDED_HERD_42)
	(
		assert_array(choices.map(func(e: Dictionary) -> String: return e["route"]))
		. is_equal(BRAIDED_ROUTES_42)
	)


func test_seed_42_with_the_demo_plan_on_the_braided_valley() -> void:
	var setup := GameData.load_setup("braided", "steady")
	var run := SeasonRun.new(setup, RandomStreams.new(42))
	var events := run.run(5, GameData.load_plan("demo"))
	var first_end: Dictionary = events.filter(_of_type("season_ended"))[0]
	assert_int(events.filter(_of_type("command_applied")).size()).is_equal(3)
	assert_int(first_end["killed"]).is_equal(BRAIDED_DEMO_KILLED_42)
	assert_int(first_end["breached"]).is_equal(BRAIDED_DEMO_BREACHED_42)
	assert_int(run.state.money).is_equal(BRAIDED_DEMO_FINAL_MONEY_42)


func test_the_demo_plan_repeats_exactly() -> void:
	var plan := GameData.load_plan("demo")
	var first := SeasonRun.new(_setup, RandomStreams.new(42)).run(5, plan)
	var second := SeasonRun.new(_setup, RandomStreams.new(42)).run(5, plan)
	assert_int(first.filter(_of_type("beast_killed")).size()).is_greater(0)
	assert_array(second).is_equal(first)


func _of_type(type: String) -> Callable:
	return func(e: Dictionary) -> bool: return e["type"] == type
