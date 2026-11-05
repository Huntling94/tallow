extends GdUnitTestSuite
## Spec 0044, AC7: a sensible defence beats building nothing over the
## 5-season mini-run. A sanity check on placeholder numbers, not a balance
## target: bot sweeps are step 6.

const SEEDS := 200
const SEASONS := 5
const REQUIRED_WIN_SHARE := 0.95

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_the_demo_plan_beats_no_defences() -> void:
	_assert_beats_no_defences("demo")


func test_the_chokepoints_plan_beats_no_defences() -> void:
	_assert_beats_no_defences("chokepoints")


func test_every_build_in_both_plans_is_applied_on_every_seed() -> void:
	for plan_id: String in ["demo", "chokepoints"]:
		var plan := GameData.load_plan(plan_id)
		for run_seed: int in range(1, SEEDS + 1):
			var events := SeasonRun.new(_setup, RandomStreams.new(run_seed)).run(SEASONS, plan)
			var rejected := events.filter(
				func(e: Dictionary) -> bool: return e["type"] == "command_rejected"
			)
			assert_int(rejected.size()).is_equal(0)


func _assert_beats_no_defences(plan_id: String) -> void:
	var plan := GameData.load_plan(plan_id)
	var wins := 0
	for run_seed: int in range(1, SEEDS + 1):
		if _final_money(run_seed, plan) > _final_money(run_seed, {}):
			wins += 1
	assert_float(float(wins) / SEEDS).is_greater_equal(REQUIRED_WIN_SHARE)


func _final_money(run_seed: int, plan: Dictionary) -> int:
	var run := SeasonRun.new(_setup, RandomStreams.new(run_seed))
	run.run(SEASONS, plan)
	return run.state.money
