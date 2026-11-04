extends GdUnitTestSuite
## Spec 0040, AC2: build commands are checked against the defence, the
## segment, what is already there and the money.

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_a_build_takes_the_cost_and_places_the_defence() -> void:
	var state := RunState.new(400)
	assert_str(state.build(_setup, "pit", "ford_bank")).is_empty()
	assert_int(state.money).is_equal(400 - 80)
	assert_str(state.defences["ford_bank"]).is_equal("pit")


func test_unknown_defence_is_rejected() -> void:
	_assert_rejected(RunState.new(400), "catapult", "ford_bank", "unknown_defence")


func test_unknown_segment_is_rejected() -> void:
	_assert_rejected(RunState.new(400), "pit", "the_moon", "unknown_segment")


func test_a_taken_segment_is_rejected() -> void:
	var state := RunState.new(400)
	state.build(_setup, "fence", "ford_bank")
	_assert_rejected(state, "pit", "ford_bank", "segment_taken")


func test_too_little_money_is_rejected() -> void:
	_assert_rejected(RunState.new(79), "pit", "ford_bank", "not_enough_money")


func test_defences_carry_over_to_later_seasons() -> void:
	var plan := {1: [_build("fence", "ford_crossing")]}
	var run := SeasonRun.new(_setup, RandomStreams.new(42))
	var events := run.run(3, plan)
	assert_str(run.state.defences["ford_crossing"]).is_equal("fence")
	for event: Dictionary in events:
		if event["type"] == "route_options":
			var ford: Dictionary = event["routes"][2]
			assert_int(ford["threat"]).is_equal(2)


func test_commands_are_reported_in_telemetry() -> void:
	var plan := {1: [_build("pit", "ford_bank"), _build("pit", "ford_bank")]}
	var events := SeasonRun.new(_setup, RandomStreams.new(42)).run(1, plan)
	var applied := events.filter(func(e: Dictionary) -> bool: return e["type"] == "command_applied")
	var rejected := events.filter(
		func(e: Dictionary) -> bool: return e["type"] == "command_rejected"
	)
	assert_int(applied.size()).is_equal(1)
	assert_int(applied[0]["cost"]).is_equal(80)
	assert_int(applied[0]["money"]).is_equal(300 + 100 - 80)
	assert_int(rejected.size()).is_equal(1)
	assert_str(rejected[0]["reason"]).is_equal("segment_taken")


func _assert_rejected(state: RunState, defence: String, segment: String, reason: String) -> void:
	var money_before := state.money
	var defences_before := state.defences.duplicate()
	assert_str(state.build(_setup, defence, segment)).is_equal(reason)
	assert_int(state.money).is_equal(money_before)
	assert_dict(state.defences).is_equal(defences_before)


func _build(defence: String, segment: String) -> Dictionary:
	return {"command": "build", "defence": defence, "segment": segment}
