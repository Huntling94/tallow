extends GdUnitTestSuite
## The viewer scene loads and replays, its controls change only what is on
## screen, and the dusk valley opens it (spec 0043, AC7, AC8 and AC9).

const SCENE := "res://scenes/season_viewer.tscn"
const VALLEY_SCENE := "res://scenes/valley.tscn"


func _viewer() -> SeasonViewer:
	var viewer: SeasonViewer = auto_free((load(SCENE) as PackedScene).instantiate())
	add_child(viewer)
	return viewer


func _direct_run(run_seed: int) -> Array[Dictionary]:
	var setup := GameData.load_setup("grey_box", "steady")
	var run := SeasonRun.new(setup, RandomStreams.new(run_seed))
	return run.run(SeasonViewer.SEASONS, GameData.load_plan("demo"))


func test_it_opens_on_seed_42_season_1_and_plays() -> void:
	var viewer := _viewer()
	assert_int(viewer.run_seed).is_equal(42)
	assert_int(viewer.season).is_equal(1)
	for frame: int in 5:
		await get_tree().process_frame
	assert_bool(viewer.playing).is_true()
	assert_float(viewer.playhead).is_greater(0.0)


func test_it_replays_the_same_events_as_a_direct_run() -> void:
	var viewer := _viewer()
	assert_str(str(viewer.events())).is_equal(str(_direct_run(42)))


func test_a_new_seed_changes_the_run_and_goes_back_to_season_1() -> void:
	var viewer := _viewer()
	viewer.show_season(3)
	viewer.load_seed(7)
	assert_int(viewer.season).is_equal(1)
	assert_str(str(viewer.events())).is_equal(str(_direct_run(7)))
	assert_str(str(viewer.events())).is_not_equal(str(_direct_run(42)))


func test_the_season_picker_restarts_on_that_season() -> void:
	var viewer := _viewer()
	viewer.seek(4.0)
	viewer.show_season(4)
	assert_int(viewer.season).is_equal(4)
	assert_float(viewer.playhead).is_equal(0.0)
	assert_bool(viewer.playing).is_true()


func test_playing_stops_at_the_end_of_the_season_and_play_starts_it_again() -> void:
	var viewer := _viewer()
	viewer.seek(9999.0)
	assert_float(viewer.playhead).is_greater(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(viewer.playing).is_false()
	viewer.toggle_play()
	assert_float(viewer.playhead).is_equal(0.0)
	assert_bool(viewer.playing).is_true()


func test_the_controls_leave_the_events_alone() -> void:
	var viewer := _viewer()
	var before := str(viewer.events())
	viewer.seek(6.5)
	viewer.toggle_play()
	viewer.set_speed(2)
	viewer.restart()
	viewer.show_season(5)
	assert_str(str(viewer.events())).is_equal(before)


func test_the_screen_fits_the_default_window() -> void:
	var viewer := _viewer()
	await get_tree().process_frame
	var screen := viewer.get_node("Margin") as Control
	var window_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_float(screen.get_combined_minimum_size().y).is_less_equal(window_height)


func test_a_resize_redraws_the_log_while_paused() -> void:
	var viewer := _viewer()
	viewer.toggle_play()
	var log_label := viewer.get_node("%Log") as Label
	log_label.text = ""
	(log_label.get_parent() as Control).resized.emit()
	assert_str(log_label.text).is_not_empty()


func test_the_restart_button_goes_back_to_the_start_and_plays() -> void:
	var viewer := _viewer()
	viewer.seek(6.0)
	viewer.toggle_play()
	(viewer.get_node("%Restart") as Button).pressed.emit()
	assert_float(viewer.playhead).is_equal(0.0)
	assert_bool(viewer.playing).is_true()


func test_the_play_button_pauses_and_resumes() -> void:
	var viewer := _viewer()
	var play := viewer.get_node("%Play") as Button
	play.pressed.emit()
	assert_bool(viewer.playing).is_false()
	play.pressed.emit()
	assert_bool(viewer.playing).is_true()


func test_a_season_button_shows_that_season() -> void:
	var viewer := _viewer()
	var third := viewer.get_node("%Seasons").get_child(2) as Button
	third.pressed.emit()
	assert_int(viewer.season).is_equal(3)
	assert_bool(third.button_pressed).is_true()


func test_the_seed_box_loads_that_seed() -> void:
	var viewer := _viewer()
	(viewer.get_node("%Seed") as SpinBox).value = 7.0
	assert_int(viewer.run_seed).is_equal(7)
	assert_str(str(viewer.events())).is_equal(str(_direct_run(7)))


func test_moving_the_slider_pauses_on_that_moment() -> void:
	var viewer := _viewer()
	(viewer.get_node("%Slider") as HSlider).value = 5.0
	assert_float(viewer.playhead).is_equal_approx(5.0, 0.01)
	assert_bool(viewer.playing).is_false()


func test_the_speed_picker_plays_faster() -> void:
	var viewer := _viewer()
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
	var back := viewer.get_node("%Back") as Button
	assert_bool(back.pressed.is_connected(viewer._back_to_valley)).is_true()


func test_the_dusk_valley_has_a_button_that_opens_the_viewer() -> void:
	var valley: Valley = auto_free((load(VALLEY_SCENE) as PackedScene).instantiate())
	add_child(valley)
	var button := valley.get_node("ViewerButton") as Button
	assert_bool(button.pressed.is_connected(valley.open_viewer)).is_true()
	assert_bool(ResourceLoader.exists(Valley.VIEWER_SCENE)).is_true()
