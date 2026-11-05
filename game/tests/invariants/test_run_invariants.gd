extends GdUnitTestSuite
## Spec 0040, AC5 and AC7, and spec 0044, AC4: over many seeds and plans,
## beasts and money always add up, and events keep their order.

const SEEDS := 60
const SEASONS := 5

var _setup: RunSetup
var _plans: Array[Dictionary] = []


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")
	_plans = [
		{},
		GameData.load_plan("demo"),
		GameData.load_plan("chokepoints"),
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


func test_every_band_is_either_killed_or_breaches() -> void:
	for plan: Dictionary in _plans:
		for run_seed: int in range(1, SEEDS + 1):
			var killed := {}
			var breached := {}
			var sizes := {}
			for event: Dictionary in _run(run_seed, plan):
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
	for plan: Dictionary in _plans:
		for run_seed: int in range(1, SEEDS + 1):
			var money := _setup.rules.start_money
			for event: Dictionary in _run(run_seed, plan):
				match event["type"]:
					"season_started":
						money += _setup.rules.season_levy
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
		for event: Dictionary in _run(run_seed, _plans[3]):
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
		var events := _run(run_seed, _plans[1])
		for index: int in events.size():
			var event := events[index]
			if event["type"] in PREPARE:
				assert_int(event["tick"]).is_equal(0)
			else:
				assert_int(event["tick"]).is_greater_equal(1)
			if index > 0:
				var before_key := _key(events[index - 1])
				assert_bool(before_key < _key(event)).is_true()


func _run(run_seed: int, plan: Dictionary) -> Array[Dictionary]:
	return SeasonRun.new(_setup, RandomStreams.new(run_seed)).run(SEASONS, plan)


func _key(event: Dictionary) -> Array:
	return [event["season"], event["tick"], event["seq"]]


func _build(defence: String, segment: String) -> Dictionary:
	return {"command": "build", "defence": defence, "segment": segment}
