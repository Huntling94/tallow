extends GdUnitTestSuite
## The replay shows the money a season made and lost (spec 0051, AC7 and AC12).


func _setup() -> RunSetup:
	return GameData.load_setup("grey_box", "steady")


func _event(type: String, tick: int, fields: Dictionary = {}) -> Dictionary:
	var event := {"type": type, "season": 1, "tick": tick, "seq": 0}
	event.merge(fields)
	return event


## One band on Low Ford, with the events a season opens on.
func _opening(beasts: int) -> Array[Dictionary]:
	var opening: Array[Dictionary] = []
	opening.append(_event("season_started", 0, {"levy": 0, "money": 400}))
	opening.append(_event("herd_arrived", 0, {"herd_size": beasts, "bands": 1}))
	opening.append(_event("route_chosen", 0, {"band": 1, "beasts": beasts, "route": "low_ford"}))
	return opening


func _demo_events() -> Array[Dictionary]:
	var run := SeasonRun.new(_setup(), RandomStreams.new(42))
	return run.run(5, GameData.load_plan("demo"))


func test_a_harvest_shows_what_was_sold_at_its_tick() -> void:
	var fields := {"beasts": 2, "goods": 8, "price": 5, "income": 40, "money": 440}
	var events := _opening(3)
	events.append(_event("harvest", 9, fields))
	var replay := SeasonReplay.new(_setup(), events, 1)
	assert_array(Array(replay.frame(8.0)["log"])).not_contains(["Sold 8 goods for 40"])
	assert_int(replay.frame(8.0)["income"]).is_equal(0)
	assert_array(Array(replay.frame(9.0)["log"])).contains(["Sold 8 goods for 40"])
	assert_int(replay.frame(9.0)["income"]).is_equal(40)
	assert_int(replay.frame(9.0)["money"]).is_equal(440)


func test_breach_costs_add_up_as_they_happen() -> void:
	var events := _opening(3)
	var breach := {"band": 1, "beasts": 2, "cost": 20, "money": 380}
	events.append(_event("breach", 6, breach))
	var replay := SeasonReplay.new(_setup(), events, 1)
	assert_int(replay.frame(5.0)["breach_costs"]).is_equal(0)
	assert_int(replay.frame(6.0)["breach_costs"]).is_equal(20)


func test_the_income_and_costs_of_a_real_season_explain_its_money() -> void:
	var events := _demo_events()
	var replay := SeasonReplay.new(_setup(), events, 3)
	var last := replay.frame(replay.last_tick)
	var opening := replay.frame(0.0)
	var change: int = last["income"] - last["breach_costs"]
	assert_int(last["money"]).is_equal(opening["money"] + change)
