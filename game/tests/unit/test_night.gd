extends GdUnitTestSuite
## Spec 0040, AC3, AC4 and AC7: during the night, pits and towers kill passing
## beasts up to their capacity, fences never kill, and survivors breach.

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_a_fence_never_kills() -> void:
	var state := RunState.new(1000)
	state.defences = {"neck_pass": "fence", "town_approach": "fence"}
	var events := Night.resolve(_setup, state, [_band(1, 40, "low_ford")], _rng(1))
	assert_int(_count(events, "beast_killed")).is_equal(0)
	assert_int(_breached(events)).is_equal(40)


func test_a_pit_kills_no_more_than_its_capacity_in_a_night() -> void:
	for run_seed: int in range(1, 51):
		var state := RunState.new(1000)
		state.defences = {"neck_pass": "pit"}
		var bands: Array[Dictionary] = [
			_band(1, 6, "cairn_pass"), _band(2, 6, "split_ridge"), _band(3, 6, "low_ford")
		]
		var events := Night.resolve(_setup, state, bands, _rng(run_seed))
		assert_int(_count(events, "beast_killed")).is_less_equal(3)


func test_kill_share_matches_the_kill_chance_when_capacity_is_not_reached() -> void:
	var tower: DefenceType = _setup.defences["harpoon_tower"]
	var roomy := DefenceType.new("roomy_tower", "Roomy tower", 0, 1, tower.kill_ppm, 100000)
	var setup := RunSetup.new(_setup.graph, _setup.herd, {"roomy_tower": roomy}, _setup.rules)
	var state := RunState.new(0)
	state.defences = {"cairn_west": "roomy_tower"}
	var events := Night.resolve(setup, state, [_band(1, 5000, "cairn_pass")], _rng(7))
	var share := _count(events, "beast_killed") / 5000.0
	assert_float(share).is_equal_approx(tower.kill_ppm / 1e6, 0.02)


func test_survivors_breach_and_cost_money() -> void:
	var state := RunState.new(500)
	var events := Night.resolve(_setup, state, [_band(1, 7, "split_ridge")], _rng(1))
	var breaches := events.filter(func(e: Dictionary) -> bool: return e["type"] == "breach")
	assert_int(breaches.size()).is_equal(1)
	assert_int(breaches[0]["beasts"]).is_equal(7)
	assert_int(breaches[0]["cost"]).is_equal(7 * _setup.rules.breach_cost_per_beast)
	assert_int(state.money).is_equal(500 - 70)
	assert_int(breaches[0]["money"]).is_equal(state.money)


func test_night_events_are_in_tick_order_after_tick_zero() -> void:
	var state := RunState.new(1000)
	state.defences = {"neck_pass": "pit", "cairn_west": "harpoon_tower"}
	var bands: Array[Dictionary] = []
	for band: int in range(1, 7):
		bands.append(_band(band, 5, ["cairn_pass", "split_ridge", "low_ford"][band % 3]))
	var events := Night.resolve(_setup, state, bands, _rng(3))
	var previous := 0
	for event: Dictionary in events:
		assert_int(event["tick"]).is_greater_equal(1)
		assert_int(event["tick"]).is_greater_equal(previous)
		previous = event["tick"]


func test_a_band_enters_each_segment_once_it_has_walked_that_far() -> void:
	# Cairn Pass: 600, 2200, 1800 and 400 metres at 400 metres a tick. Band 1
	# sets off at tick 1, so it enters after 0, 600, 2800 and 4600 metres,
	# rounded up to whole ticks, and reaches the gate after 5000 metres.
	var arrivals := Night.arrivals(_setup, [_band(1, 3, "cairn_pass")])
	var ticks := arrivals.map(func(a: Array) -> int: return a[0])
	assert_array(ticks).is_equal([1, 3, 8, 13, 14])


func test_a_tower_kills_no_more_than_its_capacity_in_a_night() -> void:
	for run_seed: int in range(1, 51):
		var state := RunState.new(1000)
		state.defences = {"neck_pass": "harpoon_tower"}
		var bands: Array[Dictionary] = []
		for band: int in range(1, 9):
			bands.append(_band(band, 6, "split_ridge"))
		var events := Night.resolve(_setup, state, bands, _rng(run_seed))
		assert_int(_count(events, "beast_killed")).is_less_equal(6)


func test_later_bands_set_off_later() -> void:
	var state := RunState.new(1000)
	var events := Night.resolve(
		_setup, state, [_band(1, 3, "low_ford"), _band(2, 3, "low_ford")], _rng(1)
	)
	assert_int(events[1]["tick"] - events[0]["tick"]).is_equal(_setup.rules.band_spacing_ticks)


func _band(number: int, beasts: int, route: String) -> Dictionary:
	return {"band": number, "beasts": beasts, "route": route}


func _rng(run_seed: int) -> RandomNumberGenerator:
	return RandomStreams.new(run_seed).for_system("defences")


func _count(events: Array[Dictionary], type: String) -> int:
	return events.filter(func(e: Dictionary) -> bool: return e["type"] == type).size()


func _breached(events: Array[Dictionary]) -> int:
	var total := 0
	for event: Dictionary in events:
		if event["type"] == "breach":
			total += event["beasts"]
	return total
