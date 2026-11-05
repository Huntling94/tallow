extends GdUnitTestSuite
## Preparing and playing a run through its real controls and mouse clicks
## (spec 0051, AC1 to AC11).

const SCENE := "res://scenes/season_viewer.tscn"
const FORD := "ford_crossing"
const CAIRN := "cairn_west"


func _viewer() -> SeasonViewer:
	var viewer: SeasonViewer = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(viewer)
	return viewer


## A viewer past its first release, watching season 1.
func _watching() -> SeasonViewer:
	var viewer := _viewer()
	viewer.release()
	return viewer


func _setup() -> RunSetup:
	return GameData.load_setup("grey_box", "steady")


## The same choices, played straight on the simulation. `seasons` holds one
## list of [defence, segment] pairs for each season.
func _direct_run(run_seed: int, seasons: Array) -> Array[Dictionary]:
	var run := SeasonRun.new(_setup(), RandomStreams.new(run_seed))
	var events: Array[Dictionary] = []
	for builds: Array in seasons:
		var commands: Array[Dictionary] = []
		for build: Array in builds:
			commands.append({"command": "build", "defence": build[0], "segment": build[1]})
		events.append_array(run.play_season(commands))
	return events


func _text(viewer: SeasonViewer, node: String) -> String:
	return (viewer.get_node(node) as Label).text


func _visible(viewer: SeasonViewer, node: String) -> bool:
	return (viewer.get_node(node) as Control).visible


func _defence_button(viewer: SeasonViewer, index: int) -> Button:
	return viewer.get_node("%Defences").get_child(index) as Button


## A real mouse click on the middle of a segment, in a map of this size.
func _click(viewer: SeasonViewer, segment_id: String, map_size := Vector2(600, 440)) -> void:
	var map := viewer.get_node("%Map") as RouteMap
	map.size = map_size
	var fit := minf(map_size.x / ValleyLayout.SHEET.x, map_size.y / ValleyLayout.SHEET.y)
	var layout := ValleyLayout.new(_setup().graph)
	var offset := (map_size - ValleyLayout.SHEET * fit) / 2.0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = offset + layout.point_at(segment_id, 0.5) * fit
	map._gui_input(click)


func _frame(viewer: SeasonViewer) -> Dictionary:
	return (viewer.get_node("%Map") as RouteMap)._frame


## The odds each route should show, as the panel writes them.
func _expected_odds(viewer: SeasonViewer, draft: DefenceDraft) -> void:
	var setup := _setup()
	var text := _odds_text(viewer)
	for option: Dictionary in draft.odds():
		var percent: float = option["p_ppm"] / 10000.0
		assert_str(text).contains("%s  %.0f%%" % [setup.graph.route_name(option["route"]), percent])


func _odds_text(viewer: SeasonViewer) -> String:
	var parts: PackedStringArray = []
	for child: Node in viewer.get_node("%Odds").get_children():
		if child is Label:
			parts.append((child as Label).text)
	return " ".join(parts)


func test_it_opens_on_the_prepare_phase_of_season_1() -> void:
	var viewer := _viewer()
	assert_int(viewer.run_seed).is_equal(42)
	assert_int(viewer.season).is_equal(1)
	assert_bool(viewer.is_preparing()).is_true()
	assert_bool(_visible(viewer, "%Prepare")).is_true()
	assert_bool(_visible(viewer, "%Controls")).is_false()
	assert_array(viewer.events()).is_empty()
	var setup := _setup()
	assert_str(_text(viewer, "%Totals")).contains("Money  %d" % setup.rules.start_money)
	assert_str(_text(viewer, "%Totals")).contains("18 to 30")
	_expected_odds(viewer, DefenceDraft.new(setup, RunState.new(setup.rules.start_money)))
	assert_array(_frame(viewer)["bands"]).is_empty()


func test_each_defence_button_gives_its_numbers() -> void:
	var viewer := _viewer()
	assert_str(_defence_button(viewer, 0).text).contains("Drive fence").contains("40")
	assert_str(_defence_button(viewer, 0).text).contains("threat 2").contains("no kills")
	assert_str(_defence_button(viewer, 1).text).contains("Pit trap").contains("80")
	assert_str(_defence_button(viewer, 1).text).contains("40%").contains("3 a night")
	assert_str(_defence_button(viewer, 2).text).contains("Harpoon tower").contains("120")
	assert_str(_defence_button(viewer, 2).text).contains("25%").contains("6 a night")


func test_clicking_a_route_places_the_picked_defence() -> void:
	var viewer := _viewer()
	var odds := _odds_text(viewer)
	var map_odds := str(_frame(viewer)["routes"])
	_defence_button(viewer, 0).pressed.emit()
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Totals")).contains("Money  560")
	assert_str(_odds_text(viewer)).is_not_equal(odds)
	assert_str(_frame(viewer)["defences"].get(FORD, "")).is_equal("fence")
	assert_str(str(_frame(viewer)["routes"])).is_not_equal(map_odds)


func test_a_click_lands_on_the_right_segment_at_any_window_size() -> void:
	for map_size: Vector2 in [Vector2(600, 440), Vector2(1200, 300), Vector2(320, 900)]:
		var viewer := _viewer()
		viewer.pick_defence("fence")
		_click(viewer, CAIRN, map_size)
		assert_array(_frame(viewer)["defences"].keys()).contains_exactly([CAIRN])
		_click(viewer, FORD, map_size)
		assert_array(_frame(viewer)["defences"].keys()).contains_exactly([CAIRN, FORD])


func test_each_defence_button_has_room_for_all_of_its_text() -> void:
	var viewer := _viewer()
	var room := (viewer.get_node("%Panel") as Control).custom_minimum_size.x
	for index: int in 3:
		var button := _defence_button(viewer, index)
		var size := button.get_theme_font_size("font_size")
		var font := button.get_theme_font("font")
		var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var edges := button.get_theme_stylebox("normal").get_minimum_size().x
		assert_float(width + edges).is_less_equal(room)


func test_the_hover_mark_goes_when_the_mouse_leaves_the_map() -> void:
	var viewer := _viewer()
	var map := viewer.get_node("%Map") as RouteMap
	map.size = Vector2(600, 440)
	var motion := InputEventMouseMotion.new()
	motion.position = ValleyLayout.new(_setup().graph).point_at(FORD, 0.5)
	map._gui_input(motion)
	assert_str(map._hover).is_equal(FORD)
	map.notification(Control.NOTIFICATION_MOUSE_EXIT)
	assert_str(map._hover).is_empty()


func test_a_click_away_from_every_route_does_nothing() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	var map := viewer.get_node("%Map") as RouteMap
	map.size = Vector2(600, 440)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(560, 40)
	map._gui_input(click)
	assert_str(_text(viewer, "%Totals")).contains("Money  600")


func test_a_click_with_no_defence_picked_says_so() -> void:
	var viewer := _viewer()
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Hint")).is_equal(SeasonViewer.HINT_PICK_FIRST)
	assert_str(_text(viewer, "%Totals")).contains("Money  600")


func test_clicking_a_defence_placed_this_season_takes_it_back() -> void:
	var viewer := _viewer()
	viewer.pick_defence("pit")
	_click(viewer, FORD)
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Totals")).contains("Money  600")


func test_a_defence_from_an_earlier_night_stays_and_the_panel_says_why() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	viewer.release()
	viewer.show_season(2)
	var money := _text(viewer, "%Totals")
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Totals")).is_equal(money)
	assert_str(_text(viewer, "%Hint")).contains("already")


func test_a_defence_it_cannot_afford_is_refused_and_the_panel_says_why() -> void:
	var viewer := _viewer()
	viewer.pick_defence("harpoon_tower")
	for segment_id: String in [
		"neck_pass", "cairn_west", "cairn_south", "ridge_climb", "ridge_drop"
	]:
		_click(viewer, segment_id)
	assert_str(_text(viewer, "%Totals")).contains("Money  0")
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Hint")).contains("Not enough money")
	assert_str(_text(viewer, "%Totals")).contains("Money  0")


func test_releasing_plays_the_same_season_as_a_direct_run() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	viewer.pick_defence("harpoon_tower")
	_click(viewer, CAIRN)
	(viewer.get_node("%Release") as Button).pressed.emit()
	var builds := [[["fence", FORD], ["harpoon_tower", CAIRN]]]
	assert_str(str(viewer.events())).is_equal(str(_direct_run(42, builds)))


func test_a_whole_run_of_choices_matches_a_direct_run() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	viewer.release()
	viewer.show_season(2)
	viewer.pick_defence("pit")
	_click(viewer, CAIRN)
	viewer.release()
	viewer.show_season(3)
	viewer.release()
	var builds := [[["fence", FORD]], [["pit", CAIRN]], []]
	assert_str(str(viewer.events())).is_equal(str(_direct_run(42, builds)))


func test_the_night_plays_and_placing_cannot_change_it() -> void:
	var viewer := _watching()
	assert_bool(viewer.is_preparing()).is_false()
	assert_bool(viewer.playing).is_true()
	assert_bool(_visible(viewer, "%Prepare")).is_false()
	assert_bool(_visible(viewer, "%Controls")).is_true()
	var events := str(viewer.events())
	viewer.pick_defence("fence")
	viewer.press_segment(FORD)
	viewer.release()
	assert_str(str(viewer.events())).is_equal(events)
	assert_int(viewer.played).is_equal(1)
	for frame: int in 5:
		await get_tree().process_frame
	assert_float(viewer.playhead).is_greater(0.0)


func test_the_end_of_a_night_shows_the_result_and_leads_on() -> void:
	var viewer := _watching()
	assert_bool(_visible(viewer, "%Result")).is_false()
	viewer.seek(9999.0)
	assert_bool(_visible(viewer, "%Result")).is_true()
	var ended: Dictionary = viewer.events()[-1]
	var result := _text(viewer, "%ResultText")
	assert_str(result).contains("%d killed" % ended["killed"])
	assert_str(result).contains("%d breached" % ended["breached"])
	var costs := 0
	var income := 0
	for event: Dictionary in viewer.events():
		if event["type"] == "breach":
			costs += event["cost"]
		elif event["type"] == "harvest":
			income = event["income"]
	assert_str(result).contains("Income %d" % income).contains("breach costs %d" % costs)
	assert_str(result).contains("Money %d" % ended["money"])
	var next := viewer.get_node("%NextSeason") as Button
	assert_str(next.text).is_equal("Prepare season 2")
	next.pressed.emit()
	assert_bool(viewer.is_preparing()).is_true()
	assert_int(viewer.season).is_equal(2)


func test_a_new_prepare_phase_carries_over_money_and_defences() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	viewer.release()
	var ended: Dictionary = viewer.events()[-1]
	viewer.show_season(2)
	assert_str(_text(viewer, "%Totals")).contains("Money  %d" % ended["money"])
	var setup := _setup()
	var run := SeasonRun.new(setup, RandomStreams.new(42))
	var command := {"command": "build", "defence": "fence", "segment": FORD}
	run.play_season([command])
	_expected_odds(viewer, DefenceDraft.new(setup, run.state))
	assert_bool(_frame(viewer)["defences"].has(FORD)).is_true()


func test_a_standing_defence_clicked_with_nothing_picked_says_it_is_taken() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	viewer.release()
	viewer.show_season(2)
	viewer.pick_defence("fence")
	_click(viewer, FORD)
	assert_str(_text(viewer, "%Hint")).contains("already")


func test_a_played_season_can_be_watched_again_and_keeps_the_placements() -> void:
	var viewer := _watching()
	viewer.show_season(2)
	viewer.pick_defence("pit")
	_click(viewer, CAIRN)
	var money := _text(viewer, "%Totals")
	var first := viewer.get_node("%Seasons").get_child(0) as Button
	first.pressed.emit()
	assert_bool(viewer.is_preparing()).is_false()
	assert_int(viewer.season).is_equal(1)
	assert_bool(first.button_pressed).is_true()
	(viewer.get_node("%Seasons").get_child(1) as Button).pressed.emit()
	assert_bool(viewer.is_preparing()).is_true()
	assert_str(_text(viewer, "%Totals")).is_equal(money)
