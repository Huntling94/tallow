extends GdUnitTestSuite
## The replay turns a season's events into what is on screen at any moment,
## and decides nothing itself (spec 0043, AC2 to AC7).

const LOW_FORD := "low_ford"


func _setup() -> RunSetup:
	return GameData.load_setup("grey_box", "steady")


func _event(type: String, tick: int, fields: Dictionary = {}, season: int = 1) -> Dictionary:
	var event := {"type": type, "season": season, "tick": tick, "seq": 0}
	event.merge(fields)
	return event


## One band of `beasts` on Low Ford, with the events a season opens on.
func _opening(beasts: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = [
		{"route": "cairn_pass", "length_m": 5000, "rough_m": 900, "threat": 0, "p_ppm": 250000},
		{"route": "split_ridge", "length_m": 4400, "rough_m": 1100, "threat": 0, "p_ppm": 350000},
		{"route": LOW_FORD, "length_m": 4000, "rough_m": 1200, "threat": 0, "p_ppm": 400000},
	]
	var opening: Array[Dictionary] = []
	opening.append(_event("season_started", 0, {"levy": 100, "money": 400}))
	opening.append(_event("herd_arrived", 0, {"herd_size": beasts, "bands": 1}))
	opening.append(_event("route_options", 0, {"routes": options}))
	opening.append(_event("route_chosen", 0, {"band": 1, "beasts": beasts, "route": LOW_FORD}))
	return opening


## Seed 42 with the demo plan, the same way the headless runner plays it.
func _demo_events(run_seed: int = 42) -> Array[Dictionary]:
	var run := SeasonRun.new(_setup(), RandomStreams.new(run_seed))
	return run.run(5, GameData.load_plan("demo"))


func _band(frame: Dictionary, number: int) -> Dictionary:
	for band: Dictionary in frame["bands"]:
		if band["band"] == number:
			return band
	return {}


func _arrival_ticks(setup: RunSetup, route: String) -> Array[int]:
	var bands: Array[Dictionary] = [{"band": 1, "beasts": 3, "route": route}]
	var ticks: Array[int] = []
	for arrival: Array in Night.arrivals(setup, bands):
		ticks.append(arrival[0])
	return ticks


func test_a_band_is_at_the_start_of_a_segment_at_the_tick_it_enters() -> void:
	var setup := _setup()
	var replay := SeasonReplay.new(setup, _opening(3), 1)
	var ticks := _arrival_ticks(setup, LOW_FORD)
	for position: int in setup.graph.route_segments(LOW_FORD).size():
		var band := _band(replay.frame(ticks[position]), 1)
		assert_str(band["state"]).is_equal(SeasonReplay.WALKING)
		assert_float(band["progress"]).is_equal_approx(float(position), 0.0001)


func test_a_band_is_halfway_along_a_segment_halfway_between_arrivals() -> void:
	var setup := _setup()
	var replay := SeasonReplay.new(setup, _opening(3), 1)
	var ticks := _arrival_ticks(setup, LOW_FORD)
	var halfway := (ticks[1] + ticks[2]) / 2.0
	var band := _band(replay.frame(halfway), 1)
	assert_float(band["progress"]).is_equal_approx(1.5, 0.0001)


func test_a_band_waits_at_the_entry_until_it_sets_off() -> void:
	var setup := _setup()
	var replay := SeasonReplay.new(setup, _opening(3), 1)
	var band := _band(replay.frame(0.5), 1)
	assert_str(band["state"]).is_equal(SeasonReplay.WAITING)
	assert_float(band["progress"]).is_equal(0.0)


func test_a_later_band_sets_off_when_the_arrivals_say_it_does() -> void:
	var setup := _setup()
	var events := _opening(3)
	events.append(_event("route_chosen", 0, {"band": 2, "beasts": 3, "route": LOW_FORD}))
	var replay := SeasonReplay.new(setup, events, 1)
	var bands: Array[Dictionary] = [
		{"band": 1, "beasts": 3, "route": LOW_FORD}, {"band": 2, "beasts": 3, "route": LOW_FORD}
	]
	var second_start := -1
	for arrival: Array in Night.arrivals(setup, bands):
		if arrival[1] == 2 and arrival[2] == 0:
			second_start = arrival[0]
	assert_str(_band(replay.frame(second_start - 0.5), 2)["state"]).is_equal(SeasonReplay.WAITING)
	assert_str(_band(replay.frame(second_start), 2)["state"]).is_equal(SeasonReplay.WALKING)


func test_a_kill_takes_one_beast_at_its_tick_and_marks_the_map() -> void:
	var events := _opening(3)
	var kill := {"band": 1, "segment": "ford_bank", "defence": "pit"}
	events.append(_event("beast_killed", 3, kill))
	var replay := SeasonReplay.new(_setup(), events, 1)

	var before := replay.frame(2.9)
	assert_int(_band(before, 1)["beasts"]).is_equal(3)
	assert_array(before["marks"]).is_empty()

	var after := replay.frame(3.0)
	assert_int(_band(after, 1)["beasts"]).is_equal(2)
	var mark: Dictionary = after["marks"][0]
	assert_str(mark["kind"]).is_equal(SeasonReplay.KILL)
	assert_str(mark["segment"]).is_equal("ford_bank")
	assert_float(mark["age"]).is_equal(0.0)


func test_a_band_leaves_the_map_when_its_last_beast_dies() -> void:
	var events := _opening(1)
	var kill := {"band": 1, "segment": "ford_bank", "defence": "pit"}
	events.append(_event("beast_killed", 3, kill))
	var replay := SeasonReplay.new(_setup(), events, 1)
	assert_str(_band(replay.frame(2.0), 1)["state"]).is_equal(SeasonReplay.WALKING)
	assert_str(_band(replay.frame(3.0), 1)["state"]).is_equal(SeasonReplay.GONE)


func test_a_band_leaves_the_map_at_its_breach() -> void:
	var events := _opening(3)
	var breach := {"band": 1, "beasts": 3, "cost": 30, "money": 370}
	events.append(_event("breach", 10, breach))
	var replay := SeasonReplay.new(_setup(), events, 1)
	assert_str(_band(replay.frame(9.5), 1)["state"]).is_equal(SeasonReplay.WALKING)
	var after := replay.frame(10.0)
	assert_str(_band(after, 1)["state"]).is_equal(SeasonReplay.GONE)
	assert_str(after["marks"][0]["kind"]).is_equal(SeasonReplay.BREACH)
	assert_int(after["marks"][0]["beasts"]).is_equal(3)


func test_bands_breaching_on_the_same_tick_count_together_in_the_note() -> void:
	var events := _opening(2)
	events.append(_event("route_chosen", 0, {"band": 2, "beasts": 3, "route": LOW_FORD}))
	events.append(_event("route_chosen", 0, {"band": 3, "beasts": 4, "route": LOW_FORD}))
	events.append(_event("breach", 10, {"band": 1, "beasts": 2, "cost": 20, "money": 380}))
	events.append(_event("breach", 12, {"band": 2, "beasts": 3, "cost": 30, "money": 350}))
	events.append(_event("breach", 12, {"band": 3, "beasts": 4, "cost": 40, "money": 310}))
	var replay := SeasonReplay.new(_setup(), events, 1)

	assert_dict(replay.frame(9.0)["breach_note"]).is_empty()
	assert_int(replay.frame(11.0)["breach_note"]["beasts"]).is_equal(2)
	assert_int(replay.frame(12.0)["breach_note"]["beasts"]).is_equal(7)
	assert_float(replay.frame(12.5)["breach_note"]["age"]).is_equal(0.5)
	assert_int(replay.frame(12.0)["breached"]).is_equal(9)


func test_money_and_totals_change_only_when_their_event_is_reached() -> void:
	var events := _opening(4)
	var built := {"command": "build", "defence": "pit", "segment": "ford_bank"}
	built.merge({"cost": 80, "money": 320})
	events.insert(1, _event("command_applied", 0, built))
	events.append(_event("beast_killed", 3, {"band": 1, "segment": "ford_bank", "defence": "pit"}))
	events.append(_event("breach", 10, {"band": 1, "beasts": 3, "cost": 30, "money": 290}))
	var ended := {"money": 290, "killed": 1, "breached": 3}
	events.append(_event("season_ended", 10, ended))
	var replay := SeasonReplay.new(_setup(), events, 1)

	assert_int(replay.frame(0.0)["money"]).is_equal(320)
	assert_int(replay.frame(5.0)["killed"]).is_equal(1)
	assert_int(replay.frame(5.0)["breached"]).is_equal(0)
	assert_int(replay.frame(5.0)["money"]).is_equal(320)
	var last := replay.frame(10.0)
	assert_int(last["money"]).is_equal(290)
	assert_int(last["killed"]).is_equal(1)
	assert_int(last["breached"]).is_equal(3)
	assert_int(replay.last_tick).is_equal(10)


func test_the_odds_are_the_seasons_route_options() -> void:
	var replay := SeasonReplay.new(_setup(), _opening(3), 1)
	(
		assert_array(replay.routes.map(func(route: Dictionary) -> int: return route["p_ppm"]))
		. is_equal([250000, 350000, 400000])
	)
	assert_int(replay.bands_on_route(LOW_FORD)).is_equal(1)
	assert_int(replay.bands_on_route("cairn_pass")).is_equal(0)


func test_defences_carry_over_from_earlier_seasons_and_rejections_draw_nothing() -> void:
	var fence := {"command": "build", "defence": "fence", "segment": "ford_crossing"}
	fence.merge({"cost": 40, "money": 360})
	var pit := {"command": "build", "defence": "pit", "segment": "neck_pass"}
	pit.merge({"cost": 80, "money": 300})
	var refused := {"command": "build", "defence": "pit", "segment": "ford_bank"}
	refused.merge({"reason": "not_enough_money"})
	var tower := {"command": "build", "defence": "harpoon_tower", "segment": "cairn_west"}
	tower.merge({"cost": 120, "money": 300})
	var events: Array[Dictionary] = [
		_event("command_applied", 0, fence, 1),
		_event("command_rejected", 0, refused, 1),
		_event("command_applied", 0, pit, 2),
		_event("command_applied", 0, tower, 3),
	]
	var replay := SeasonReplay.new(_setup(), events, 2)
	assert_dict(replay.frame(0.0)["defences"]).is_equal(
		{"ford_crossing": "fence", "neck_pass": "pit"}
	)


func test_the_demo_plan_shows_all_three_defences_in_season_three() -> void:
	var replay := SeasonReplay.new(_setup(), _demo_events(), 3)
	assert_dict(replay.frame(0.0)["defences"]).is_equal(
		{"ford_crossing": "fence", "cairn_west": "harpoon_tower", "ridge_drop": "pit"}
	)


func test_an_unknown_event_changes_nothing() -> void:
	var setup := _setup()
	var plain := _opening(3)
	var noisy := _opening(3)
	# Fields a future event might share with known ones must not be read.
	var unknown := {"money": 999999, "killed": 7, "band": 1, "beasts": 2, "segment": "ford_bank"}
	noisy.insert(2, _event("goods_sold", 0, unknown))
	noisy.append(_event("price_changed", 4, unknown))
	var expected := SeasonReplay.new(setup, plain, 1)
	var actual := SeasonReplay.new(setup, noisy, 1)
	for time: float in [0.0, 2.5, 4.0, 9.0]:
		assert_str(str(actual.frame(time))).is_equal(str(expected.frame(time)))


func test_events_from_other_seasons_stay_out_of_this_season() -> void:
	var events := _opening(3)
	events.append(_event("beast_killed", 3, {"band": 1, "segment": "x", "defence": "pit"}, 2))
	events.append(_event("season_started", 0, {"levy": 100, "money": 1}, 2))
	var replay := SeasonReplay.new(_setup(), events, 1)
	var frame := replay.frame(5.0)
	assert_int(frame["killed"]).is_equal(0)
	assert_int(frame["money"]).is_equal(400)


func test_every_season_of_the_demo_ends_on_what_season_ended_says() -> void:
	var setup := _setup()
	var events := _demo_events()
	for season: int in range(1, 6):
		var replay := SeasonReplay.new(setup, events, season)
		var ended := {}
		var chosen := 0
		for event: Dictionary in events:
			if event["season"] == season and event["type"] == "season_ended":
				ended = event
			if event["season"] == season and event["type"] == "route_chosen":
				chosen += event["beasts"]
		var last := replay.frame(replay.last_tick)
		assert_int(replay.last_tick).is_equal(ended["tick"])
		assert_int(last["money"]).is_equal(ended["money"])
		assert_int(last["killed"]).is_equal(ended["killed"])
		assert_int(last["breached"]).is_equal(ended["breached"])
		assert_int(last["killed"] + last["breached"]).is_equal(chosen)
		for band: Dictionary in last["bands"]:
			assert_str(band["state"]).is_equal(SeasonReplay.GONE)


func test_a_moment_looks_the_same_however_it_is_reached() -> void:
	var replay := SeasonReplay.new(_setup(), _demo_events(), 2)
	var times := [0.0, 1.0, 2.25, 3.5, 7.75, 11.0, float(replay.last_tick)]
	var forwards := {}
	for time: float in times:
		forwards[time] = str(replay.frame(time))
	times.reverse()
	for time: float in times:
		assert_str(str(replay.frame(time))).is_equal(forwards[time])
	var fresh := SeasonReplay.new(_setup(), _demo_events(), 2)
	assert_str(str(fresh.frame(3.5))).is_equal(forwards[3.5])


func test_building_a_replay_leaves_the_events_as_they_were() -> void:
	var events := _demo_events()
	var before := str(events)
	var replay := SeasonReplay.new(_setup(), events, 1)
	replay.frame(5.0)
	assert_str(str(events)).is_equal(before)


func test_a_season_with_no_levy_logs_none() -> void:
	var events: Array[Dictionary] = [_event("season_started", 0, {"levy": 0, "money": 400})]
	var replay := SeasonReplay.new(_setup(), events, 1)
	assert_array(Array(replay.frame(0.0)["log"])).is_empty()
	assert_int(replay.frame(0.0)["money"]).is_equal(400)


func test_the_log_grows_with_the_season_and_names_things_for_people() -> void:
	var events := _opening(3)
	var kill := {"band": 1, "segment": "ford_bank", "defence": "pit"}
	events.append(_event("beast_killed", 3, kill))
	events.append(_event("goods_sold", 3, {"money": 1}))
	var replay := SeasonReplay.new(_setup(), events, 1)
	var early: PackedStringArray = replay.frame(1.0)["log"]
	var late: PackedStringArray = replay.frame(3.0)["log"]
	assert_int(late.size()).is_equal(early.size() + 1)
	assert_str(late[-1]).contains("Band 1").contains("Pit")
	assert_bool("Low Ford" in early[-1]).is_true()
