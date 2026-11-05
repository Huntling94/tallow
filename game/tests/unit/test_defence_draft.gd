extends GdUnitTestSuite
## The draft previews a season with the simulation's own rules, so what the
## player sees before release is what the season does (spec 0051, AC3 to AC5).

const SEED := 42


func _setup() -> RunSetup:
	return GameData.load_setup("grey_box", "steady")


func _run(setup: RunSetup) -> SeasonRun:
	return SeasonRun.new(setup, RandomStreams.new(SEED))


func _shares(options: Array) -> Array[int]:
	var shares: Array[int] = []
	for option: Dictionary in options:
		shares.append(option["p_ppm"])
	return shares


func _event(events: Array[Dictionary], type: String) -> Dictionary:
	for event: Dictionary in events:
		if event["type"] == type:
			return event
	return {}


func _segments(setup: RunSetup) -> PackedStringArray:
	var found: PackedStringArray = []
	for route_id: String in setup.graph.route_ids:
		for segment_id: String in setup.graph.route_segments(route_id):
			if not found.has(segment_id):
				found.append(segment_id)
	return found


## AC5 for one draft: the season played from it matches what was on show.
func _assert_matches_the_season(draft: DefenceDraft, run: SeasonRun) -> void:
	var shown_odds := _shares(draft.odds())
	var shown_money := draft.money()
	var events := run.play_season(draft.commands())
	assert_array(_shares(_event(events, "route_options")["routes"])).is_equal(shown_odds)
	var applied: Array[Dictionary] = events.filter(
		func(event: Dictionary) -> bool: return event["type"] == "command_applied"
	)
	assert_int(_event(events, "command_rejected").size()).is_equal(0)
	if not applied.is_empty():
		assert_int(applied[-1]["money"]).is_equal(shown_money)


func test_every_defence_on_every_segment_matches_the_season_it_makes() -> void:
	var setup := _setup()
	for defence_id: String in setup.defences:
		for segment_id: String in _segments(setup):
			var run := _run(setup)
			var draft := DefenceDraft.new(setup, run.state)
			assert_str(draft.place(defence_id, segment_id)).is_empty()
			_assert_matches_the_season(draft, run)


func test_several_defences_over_two_seasons_match_the_seasons_they_make() -> void:
	var setup := _setup()
	var run := _run(setup)
	var first := DefenceDraft.new(setup, run.state)
	first.place("fence", "ford_crossing")
	first.place("harpoon_tower", "cairn_west")
	_assert_matches_the_season(first, run)
	var second := DefenceDraft.new(setup, run.state)
	second.place("pit", "ridge_climb")
	_assert_matches_the_season(second, run)


func test_no_defences_shows_the_odds_of_an_empty_season() -> void:
	var setup := _setup()
	var run := _run(setup)
	_assert_matches_the_season(DefenceDraft.new(setup, run.state), run)


func test_money_a_levy_pays_can_be_spent_this_season() -> void:
	var setup := _setup()
	setup.rules.season_levy = 50
	var run := _run(setup)
	var draft := DefenceDraft.new(setup, run.state)
	assert_int(draft.money()).is_equal(setup.rules.start_money + 50)
	draft.place("fence", "ford_crossing")
	_assert_matches_the_season(draft, run)


func test_taking_a_defence_back_returns_its_cost_and_its_odds() -> void:
	var setup := _setup()
	var draft := DefenceDraft.new(setup, _run(setup).state)
	var money := draft.money()
	var odds := _shares(draft.odds())
	draft.place("harpoon_tower", "cairn_west")
	assert_int(draft.money()).is_less(money)
	assert_array(_shares(draft.odds())).is_not_equal(odds)
	assert_bool(draft.remove("cairn_west")).is_true()
	assert_int(draft.money()).is_equal(money)
	assert_array(_shares(draft.odds())).is_equal(odds)
	assert_array(draft.commands()).is_empty()


func test_taking_one_back_keeps_the_others() -> void:
	var setup := _setup()
	var draft := DefenceDraft.new(setup, _run(setup).state)
	draft.place("fence", "ford_crossing")
	draft.place("pit", "cairn_west")
	draft.remove("ford_crossing")
	assert_int(draft.commands().size()).is_equal(1)
	assert_str(draft.commands()[0]["segment"]).is_equal("cairn_west")


func test_a_defence_from_an_earlier_night_cannot_be_taken_back() -> void:
	var setup := _setup()
	var run := _run(setup)
	var first := DefenceDraft.new(setup, run.state)
	first.place("fence", "ford_crossing")
	run.play_season(first.commands())
	var second := DefenceDraft.new(setup, run.state)
	var money := second.money()
	assert_bool(second.is_new("ford_crossing")).is_false()
	assert_bool(second.remove("ford_crossing")).is_false()
	assert_int(second.money()).is_equal(money)
	assert_bool(second.defences().has("ford_crossing")).is_true()


func test_a_segment_with_nothing_on_it_cannot_be_taken_back() -> void:
	var setup := _setup()
	assert_bool(DefenceDraft.new(setup, _run(setup).state).remove("cairn_west")).is_false()


func test_a_taken_segment_is_refused_and_changes_nothing() -> void:
	var setup := _setup()
	var draft := DefenceDraft.new(setup, _run(setup).state)
	draft.place("fence", "ford_crossing")
	var money := draft.money()
	var odds := _shares(draft.odds())
	assert_str(draft.place("pit", "ford_crossing")).is_equal("segment_taken")
	assert_int(draft.money()).is_equal(money)
	assert_array(_shares(draft.odds())).is_equal(odds)
	assert_int(draft.commands().size()).is_equal(1)


func test_a_defence_too_dear_is_refused_and_changes_nothing() -> void:
	var setup := _setup()
	var run := _run(setup)
	run.state.money = 39
	var draft := DefenceDraft.new(setup, run.state)
	var odds := _shares(draft.odds())
	assert_str(draft.place("fence", "ford_crossing")).is_equal("not_enough_money")
	assert_int(draft.money()).is_equal(39)
	assert_array(_shares(draft.odds())).is_equal(odds)
	assert_array(draft.commands()).is_empty()


func test_the_live_state_is_never_written() -> void:
	var setup := _setup()
	var run := _run(setup)
	var draft := DefenceDraft.new(setup, run.state)
	draft.place("fence", "ford_crossing")
	draft.remove("ford_crossing")
	draft.place("pit", "cairn_west")
	assert_int(run.state.money).is_equal(setup.rules.start_money)
	assert_dict(run.state.defences).is_empty()


func test_the_frame_marks_only_this_seasons_defences_as_new() -> void:
	var setup := _setup()
	var run := _run(setup)
	var first := DefenceDraft.new(setup, run.state)
	first.place("fence", "ford_crossing")
	run.play_season(first.commands())
	var second := DefenceDraft.new(setup, run.state)
	second.place("pit", "cairn_west")
	var frame := second.frame()
	assert_dict(frame["defences"]).contains_keys(["ford_crossing", "cairn_west"])
	assert_dict(frame["new_defences"]).contains_keys(["cairn_west"])
	assert_dict(frame["new_defences"]).not_contains_keys(["ford_crossing"])
	assert_array(frame["bands"]).is_empty()
