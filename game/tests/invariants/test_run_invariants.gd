extends GdUnitTestSuite
## Spec 0040, AC5 and AC7, spec 0044, AC4, and spec 0054: over many seeds,
## plans and both valleys, beasts and money always add up, and events keep
## their order.

const SEEDS := 60
const SEASONS := 5
const RICH_MONEY := 2000

var _cases: Array[Array] = []  # [setup, plan]
var _later_builds: Array = []  # [setup, plan]


func before() -> void:
	var grey := GameData.load_setup("grey_box", "steady")
	var braided := GameData.load_setup("braided", "steady")
	# Rich enough that the later builds are applied on every seed.
	var rich := GameData.load_setup("grey_box", "steady")
	rich.rules.start_money = RICH_MONEY
	_later_builds = [
		rich,
		{
			1:
			[
				_build("pit", "neck_pass"),
				_build("harpoon_tower", "ridge_climb"),
				_build("fence", "cairn_west"),
			],
			3: [_build("harpoon_tower", "town_approach"), _build("pit", "ford_bank")],
		},
	]
	var demo := GameData.load_plan("demo")
	var closed := {
		1: [_build("harpoon_tower", "neck_pass"), _build("pit", "ridge_drop")],
		2: [_build("fence", "saddle")],
	}
	_cases = [
		[grey, {}],
		[grey, demo],
		[grey, GameData.load_plan("chokepoints")],
		_later_builds,
		[braided, {}],
		[braided, demo],
		[braided, closed],
	]


func test_every_band_is_either_killed_or_breaches() -> void:
	for case: Array in _cases:
		for run_seed: int in range(1, SEEDS + 1):
			var killed := {}
			var breached := {}
			var sizes := {}
			for event: Dictionary in _run(case, run_seed):
				var key := "%d/%d" % [event["season"], event.get("band", 0)]
				match event["type"]:
					"route_chosen":
						sizes[key] = event["beasts"]
					"beast_killed":
						killed[key] = killed.get(key, 0) + 1
					"breach":
						breached[key] = event["beasts"]
			for key: String in sizes:
				assert_int(killed.get(key, 0) + breached.get(key, 0)).is_equal(sizes[key])


func test_money_follows_the_levy_costs_breaches_and_harvest() -> void:
	for case: Array in _cases:
		var setup: RunSetup = case[0]
		for run_seed: int in range(1, SEEDS + 1):
			var money := setup.rules.start_money
			for event: Dictionary in _run(case, run_seed):
				match event["type"]:
					"season_started":
						money += setup.rules.season_levy
						assert_int(event["money"]).is_equal(money)
					"command_applied":
						money -= event["cost"]
						assert_int(event["money"]).is_equal(money)
					"breach":
						money -= event["cost"]
						assert_int(event["money"]).is_equal(money)
					"harvest":
						money += event["income"]
						assert_int(event["money"]).is_equal(money)
					"season_ended":
						assert_int(event["money"]).is_equal(money)


func test_season_totals_match_the_night() -> void:
	for run_seed: int in range(1, SEEDS + 1):
		var killed := 0
		var breached := 0
		for event: Dictionary in _run(_later_builds, run_seed):
			match event["type"]:
				"beast_killed":
					killed += 1
				"breach":
					breached += event["beasts"]
				"harvest":
					assert_int(event["beasts"]).is_equal(killed)
				"season_ended":
					assert_int(event["killed"]).is_equal(killed)
					assert_int(event["breached"]).is_equal(breached)
					killed = 0
					breached = 0


func test_events_keep_their_order_and_phases() -> void:
	const PREPARE := [
		"season_started",
		"command_applied",
		"command_rejected",
		"herd_arrived",
		"route_options",
		"route_chosen",
	]
	for run_seed: int in range(1, 11):
		var events := _run([_cases[5][0], _cases[5][1]], run_seed)
		for index: int in events.size():
			var event := events[index]
			if event["type"] in PREPARE:
				assert_int(event["tick"]).is_equal(0)
			else:
				assert_int(event["tick"]).is_greater_equal(1)
			if index > 0:
				var before_key := _key(events[index - 1])
				assert_bool(before_key < _key(event)).is_true()


func test_builds_in_a_later_season_are_applied_on_every_seed() -> void:
	for run_seed: int in range(1, SEEDS + 1):
		var applied := _run(_later_builds, run_seed).filter(
			func(e: Dictionary) -> bool: return e["type"] == "command_applied" and e["season"] == 3
		)
		assert_int(applied.size()).is_equal(2)


func test_a_build_on_closed_ground_is_rejected_on_every_seed() -> void:
	for run_seed: int in range(1, SEEDS + 1):
		var rejected := _run(_cases[6], run_seed).filter(
			func(e: Dictionary) -> bool: return e["type"] == "command_rejected"
		)
		assert_str(rejected[0]["reason"]).is_equal("segment_closed")


func _run(case: Array, run_seed: int) -> Array[Dictionary]:
	return SeasonRun.new(case[0], RandomStreams.new(run_seed)).run(SEASONS, case[1])


func _key(event: Dictionary) -> Array:
	return [event["season"], event["tick"], event["seq"]]


func _build(defence: String, segment: String) -> Dictionary:
	return {"command": "build", "defence": defence, "segment": segment}
