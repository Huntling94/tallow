extends GdUnitTestSuite
## The screen, its playback and run controls, and the dusk valley's button
## (specs 0043 and 0051).

const SCENE := "res://scenes/season_viewer.tscn"
const VALLEY_SCENE := "res://scenes/valley.tscn"
const FORD := "ford_crossing"


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
	return GameData.load_setup("braided", "steady")


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


func _season_end(viewer: SeasonViewer, number: int) -> Dictionary:
	for event: Dictionary in viewer.events():
		if event["type"] == "season_ended" and event["season"] == number:
			return event
	return {}


func _text(viewer: SeasonViewer, node: String) -> String:
	return (viewer.get_node(node) as Label).text


func _visible(viewer: SeasonViewer, node: String) -> bool:
	return (viewer.get_node(node) as Control).visible


func test_season_5_ends_the_run() -> void:
	var viewer := _viewer()
	for number: int in range(1, SeasonViewer.SEASONS + 1):
		viewer.show_season(number)
		viewer.release()
	viewer.seek(9999.0)
	assert_str(_text(viewer, "%ResultText")).contains(
		"final money %d" % viewer.events()[-1]["money"]
	)
	assert_bool(_visible(viewer, "%NextSeason")).is_false()
	assert_bool(_visible(viewer, "%NewRun")).is_true()
	viewer.show_season(6)
	assert_int(viewer.season).is_equal(5)
	assert_bool(viewer.is_preparing()).is_false()


func test_an_earlier_season_rewatched_after_the_run_shows_its_own_money() -> void:
	var viewer := _viewer()
	for number: int in range(1, SeasonViewer.SEASONS + 1):
		viewer.show_season(number)
		viewer.release()
	var first_end: int = _season_end(viewer, 1)["money"]
	viewer.show_season(1)
	viewer.seek(9999.0)
	assert_str(_text(viewer, "%ResultText")).contains("Money %d." % first_end)


func test_a_season_not_yet_played_cannot_be_picked() -> void:
	var viewer := _viewer()
	var third := viewer.get_node("%Seasons").get_child(2) as Button
	assert_bool(third.disabled).is_true()
	viewer.show_season(3)
	assert_int(viewer.season).is_equal(1)


func test_the_odds_rows_count_the_bands_on_each_route_during_the_night() -> void:
	var viewer := _watching()
	var counts := {}
	for event: Dictionary in viewer.events():
		if event["type"] == "route_chosen":
			counts[event["route"]] = counts.get(event["route"], 0) + 1
	var rows := viewer.get_node("%Odds").get_children()
	var setup := _setup()
	for index: int in rows.size():
		var route_id := setup.graph.route_ids[index]
		var count: int = counts.get(route_id, 0)
		var word := "band" if count == 1 else "bands"
		var text := (rows[index].get_child(0) as Label).text
		assert_str(text).ends_with(" · %d %s" % [count, word])


func test_the_new_run_button_starts_again_on_the_same_seed() -> void:
	var viewer := _viewer()
	viewer.pick_defence("fence")
	viewer.press_segment(FORD)
	viewer.release()
	(viewer.get_node("%NewRun") as Button).pressed.emit()
	assert_int(viewer.run_seed).is_equal(42)
	assert_int(viewer.played).is_equal(0)
	assert_bool(viewer.is_preparing()).is_true()
	assert_array(viewer.events()).is_empty()
	assert_str(_text(viewer, "%Totals")).contains("Money  300")
	assert_dict(viewer.get_node("%Map")._frame["defences"]).is_empty()


func test_the_seed_box_starts_a_run_on_that_seed() -> void:
	var viewer := _watching()
	(viewer.get_node("%Seed") as SpinBox).value = 7.0
	assert_int(viewer.run_seed).is_equal(7)
	assert_int(viewer.season).is_equal(1)
	assert_bool(viewer.is_preparing()).is_true()
	viewer.release()
	assert_str(str(viewer.events())).is_equal(str(_direct_run(7, [[]])))
	assert_str(str(viewer.events())).is_not_equal(str(_direct_run(42, [[]])))


func test_playing_stops_at_the_end_of_the_season_and_play_starts_it_again() -> void:
	var viewer := _watching()
	viewer.seek(9999.0)
	assert_float(viewer.playhead).is_greater(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(viewer.playing).is_false()
	viewer.toggle_play()
	assert_float(viewer.playhead).is_equal(0.0)
	assert_bool(viewer.playing).is_true()


func test_the_controls_leave_the_events_alone() -> void:
	var viewer := _watching()
	var events := str(viewer.events())
	viewer.seek(6.5)
	viewer.toggle_play()
	viewer.set_speed(2)
	viewer.restart()
	viewer.show_season(1)
	assert_str(str(viewer.events())).is_equal(events)


func test_the_screen_fits_the_default_window_in_each_phase() -> void:
	var viewer := _viewer()
	var screen := viewer.get_node("Margin") as Control
	var window_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	await get_tree().process_frame
	assert_float(screen.get_combined_minimum_size().y).is_less_equal(window_height)
	viewer.release()
	await get_tree().process_frame
	assert_float(screen.get_combined_minimum_size().y).is_less_equal(window_height)
	viewer.seek(9999.0)
	await get_tree().process_frame
	assert_float(screen.get_combined_minimum_size().y).is_less_equal(window_height)


func test_the_panel_keeps_its_width_so_the_map_does_not_jump_between_phases() -> void:
	var viewer := _viewer()
	var panel := viewer.get_node("%Panel") as Control
	var width := panel.custom_minimum_size.x
	await get_tree().process_frame
	assert_float(panel.get_combined_minimum_size().x).is_equal(width)
	viewer.release()
	await get_tree().process_frame
	assert_float(panel.get_combined_minimum_size().x).is_equal(width)
	viewer.seek(9999.0)
	await get_tree().process_frame
	assert_float(panel.get_combined_minimum_size().x).is_equal(width)


func test_a_resize_redraws_the_log_while_paused() -> void:
	var viewer := _watching()
	viewer.toggle_play()
	var log_label := viewer.get_node("%Log") as Label
	log_label.text = ""
	(log_label.get_parent() as Control).resized.emit()
	assert_str(log_label.text).is_not_empty()


func test_the_watch_again_button_goes_back_to_the_start_and_plays() -> void:
	var viewer := _watching()
	viewer.seek(6.0)
	viewer.toggle_play()
	(viewer.get_node("%Restart") as Button).pressed.emit()
	assert_float(viewer.playhead).is_equal(0.0)
	assert_bool(viewer.playing).is_true()


func test_the_play_button_pauses_and_resumes() -> void:
	var viewer := _watching()
	var play := viewer.get_node("%Play") as Button
	play.pressed.emit()
	assert_bool(viewer.playing).is_false()
	play.pressed.emit()
	assert_bool(viewer.playing).is_true()


func test_moving_the_slider_pauses_on_that_moment() -> void:
	var viewer := _watching()
	(viewer.get_node("%Slider") as HSlider).value = 5.0
	assert_float(viewer.playhead).is_equal_approx(5.0, 0.01)
	assert_bool(viewer.playing).is_false()


func test_the_speed_picker_plays_faster() -> void:
	var viewer := _watching()
	var picker := viewer.get_node("%Speed") as OptionButton
	assert_int(picker.item_count).is_equal(SeasonViewer.SPEEDS.size())
	viewer.toggle_play()
	picker.item_selected.emit(2)
	viewer.toggle_play()
	viewer._process(1.0)
	var expected := SeasonViewer.TICKS_PER_SECOND * SeasonViewer.SPEEDS[2]
	assert_float(viewer.playhead).is_equal_approx(expected, 0.5)


func test_bad_data_shows_a_problem_and_back_still_works() -> void:
	var viewer: SeasonViewer = auto_free((load(SCENE) as PackedScene).instantiate())
	viewer.valley_id = "no_such_valley"
	add_child(viewer)
	assert_bool((viewer.get_node("%Problem") as Label).visible).is_true()
	assert_bool((viewer.get_node("%Prepare") as Control).visible).is_false()
	var back := viewer.get_node("%Back") as Button
	assert_bool(back.pressed.is_connected(viewer._back_to_valley)).is_true()


func test_the_dusk_valley_has_a_button_that_opens_the_viewer() -> void:
	var valley: Valley = auto_free((load(VALLEY_SCENE) as PackedScene).instantiate())
	add_child(valley)
	var button := valley.get_node("ViewerButton") as Button
	assert_bool(button.pressed.is_connected(valley.open_viewer)).is_true()
	assert_bool(ResourceLoader.exists(Valley.VIEWER_SCENE)).is_true()
