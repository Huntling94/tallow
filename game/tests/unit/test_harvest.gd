extends GdUnitTestSuite
## Spec 0044, AC1, AC2, AC3, AC5 and AC8: after the night, kills become goods
## and goods sell at one price. The harvest touches money and nothing else.

const VALID_RULES := {
	"start_money": 600,
	"season_levy": 0,
	"breach_cost_per_beast": 10,
	"beast_speed_m_per_tick": 400,
	"band_spacing_ticks": 1,
	"goods_per_beast": 4,
	"price_per_good": 5,
}

var _setup: RunSetup


func before() -> void:
	_setup = GameData.load_setup("grey_box", "steady")


func test_kills_become_goods_and_goods_become_money() -> void:
	var state := RunState.new(100)
	var event := Harvest.resolve(_rules(3, 7), state, 5, 9)
	assert_str(event["type"]).is_equal("harvest")
	assert_int(event["tick"]).is_equal(9)
	assert_int(event["beasts"]).is_equal(5)
	assert_int(event["goods"]).is_equal(15)
	assert_int(event["price"]).is_equal(7)
	assert_int(event["income"]).is_equal(105)
	assert_int(event["money"]).is_equal(205)
	assert_int(state.money).is_equal(205)


func test_no_kills_earn_nothing_and_leave_the_money_alone() -> void:
	var state := RunState.new(100)
	var event := Harvest.resolve(_rules(3, 7), state, 0, 1)
	assert_int(event["beasts"]).is_equal(0)
	assert_int(event["goods"]).is_equal(0)
	assert_int(event["income"]).is_equal(0)
	assert_int(event["money"]).is_equal(100)
	assert_int(state.money).is_equal(100)


func test_every_season_has_one_harvest_even_with_no_kills() -> void:
	var events := SeasonRun.new(_setup, RandomStreams.new(42)).run(3, {})
	var harvests := events.filter(_of_type("harvest"))
	assert_int(harvests.size()).is_equal(3)
	for harvest: Dictionary in harvests:
		assert_int(harvest["beasts"]).is_equal(0)
		assert_int(harvest["income"]).is_equal(0)


func test_the_harvest_comes_after_the_night_and_just_before_the_season_ends() -> void:
	var plan := GameData.load_plan("chokepoints")
	for run_seed: int in range(1, 21):
		var events := SeasonRun.new(_setup, RandomStreams.new(run_seed)).run(5, plan)
		for index: int in events.size():
			if events[index]["type"] != "harvest":
				continue
			var harvest := events[index]
			var ended := events[index + 1]
			assert_str(ended["type"]).is_equal("season_ended")
			assert_int(ended["tick"]).is_equal(harvest["tick"])
			assert_int(ended["money"]).is_equal(harvest["money"])
			assert_str(events[index - 1]["type"]).is_not_equal("route_chosen")


func test_the_price_changes_money_and_nothing_else() -> void:
	var plan := GameData.load_plan("chokepoints")
	for run_seed: int in range(1, 21):
		var free := _with_price(0)
		var paid := _with_price(9)
		var first := SeasonRun.new(free, RandomStreams.new(run_seed)).run(5, plan)
		var second := SeasonRun.new(paid, RandomStreams.new(run_seed)).run(5, plan)
		assert_array(_without_money(second)).is_equal(_without_money(first))


func test_good_run_rules_have_no_problems() -> void:
	assert_array(Array(GameData.check_run_rules(VALID_RULES))).is_empty()


func test_a_missing_harvest_rule_is_named() -> void:
	for field: String in ["goods_per_beast", "price_per_good"]:
		var rules := VALID_RULES.duplicate()
		rules.erase(field)
		_assert_problem(rules, "missing " + field)


func test_a_mistyped_harvest_rule_is_named() -> void:
	for field: String in ["goods_per_beast", "price_per_good"]:
		var text := VALID_RULES.duplicate()
		text[field] = "lots"
		_assert_problem(text, field + " must be a number")
		var fraction := VALID_RULES.duplicate()
		fraction[field] = 1.5
		_assert_problem(fraction, field + " must be a whole number")


func test_a_negative_harvest_rule_is_named() -> void:
	for field: String in ["goods_per_beast", "price_per_good"]:
		var rules := VALID_RULES.duplicate()
		rules[field] = -1
		_assert_problem(rules, field + " must not be negative")


func _assert_problem(rules: Dictionary, expected: String) -> void:
	assert_str("; ".join(GameData.check_run_rules(rules))).contains(expected)


func _rules(goods: int, price: int) -> RunRules:
	var base := _setup.rules
	return RunRules.new(
		base.start_money,
		base.season_levy,
		base.breach_cost_per_beast,
		base.speed_m_per_tick,
		base.band_spacing_ticks,
		goods,
		price
	)


func _with_price(price: int) -> RunSetup:
	return RunSetup.new(
		_setup.graph, _setup.herd, _setup.defences, _rules(_setup.rules.goods_per_beast, price)
	)


func _without_money(events: Array[Dictionary]) -> Array:
	var stripped := []
	for event: Dictionary in events:
		var copy := event.duplicate()
		for field: String in ["money", "price", "income"]:
			copy.erase(field)
		stripped.append(copy)
	return stripped


func _of_type(type: String) -> Callable:
	return func(e: Dictionary) -> bool: return e["type"] == type
