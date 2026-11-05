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


func test_the_panel_fits_the_default_window_with_the_log_full() -> void:
	var viewer := _viewer()
	viewer.seek(9999.0)
	await get_tree().process_frame
	var panel := viewer.get_node("Margin/Columns/Panel") as Control
	var window_height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_float(panel.get_combined_minimum_size().y).is_less(window_height)


func test_the_dusk_valley_has_a_button_that_opens_the_viewer() -> void:
	var valley: Valley = auto_free((load(VALLEY_SCENE) as PackedScene).instantiate())
	add_child(valley)
	var button := valley.get_node("ViewerButton") as Button
	assert_bool(button.pressed.is_connected(valley.open_viewer)).is_true()
	assert_bool(ResourceLoader.exists(Valley.VIEWER_SCENE)).is_true()
