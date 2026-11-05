extends GdUnitTestSuite
## Spec 0044, AC7: a sensible defence beats building nothing over the
## 5-season mini-run, on the test valley and the played one (spec 0054). A
## sanity check on placeholder numbers, not a balance target: bot sweeps are
## step 6.

const SEEDS := 200
const SEASONS := 5
const REQUIRED_WIN_SHARE := 0.95

var _setup: RunSetup
var _braided: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")
	_braided = GameData.load_setup("braided", "steady")


func test_the_demo_plan_beats_no_defences() -> void:
	_assert_beats_no_defences(_setup, "demo")


## The demo plan was laid out for grey_box, so the played valley is held to a
## plan chosen for it: the coverage plan measured for spec 0054.
func test_a_coverage_plan_beats_no_defences_on_the_played_valley() -> void:
	var builds := {1: [_build("pit", "ford_flats"), _build("pit", "ridge_drop")]}
	builds[1].append(_build("harpoon_tower", "cairn_west"))
	_assert_plan_beats_no_defences(_braided, builds)


func test_the_chokepoints_plan_beats_no_defences() -> void:
	_assert_beats_no_defences(_setup, "chokepoints")


func test_every_build_in_both_plans_is_applied_on_every_seed() -> void:
	for case: Array in [[_setup, "demo"], [_setup, "chokepoints"], [_braided, "demo"]]:
		var plan := GameData.load_plan(case[1])
		for run_seed: int in range(1, SEEDS + 1):
			var events := SeasonRun.new(case[0], RandomStreams.new(run_seed)).run(SEASONS, plan)
			var rejected := events.filter(
				func(e: Dictionary) -> bool: return e["type"] == "command_rejected"
			)
			assert_int(rejected.size()).is_equal(0)


func _assert_beats_no_defences(setup: RunSetup, plan_id: String) -> void:
	_assert_plan_beats_no_defences(setup, GameData.load_plan(plan_id))


func _assert_plan_beats_no_defences(setup: RunSetup, plan: Dictionary) -> void:
	var wins := 0
	for run_seed: int in range(1, SEEDS + 1):
		if _final_money(setup, run_seed, plan) > _final_money(setup, run_seed, {}):
			wins += 1
	assert_float(float(wins) / SEEDS).is_greater_equal(REQUIRED_WIN_SHARE)


func _final_money(setup: RunSetup, run_seed: int, plan: Dictionary) -> int:
	var run := SeasonRun.new(setup, RandomStreams.new(run_seed))
	run.run(SEASONS, plan)
	return run.state.money


func _build(defence: String, segment: String) -> Dictionary:
	return {"command": "build", "defence": defence, "segment": segment}
