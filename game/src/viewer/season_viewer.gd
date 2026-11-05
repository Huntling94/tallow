class_name SeasonViewer
extends Control
## The season viewer screen (spec 0043). Runs the simulation once for a seed,
## then replays one season at a time. The playhead here is the only clock, it
## counts decimal ticks for the picture, and it never reaches the simulation.

const VALLEY_SCENE := "res://scenes/valley.tscn"
const VALLEY_ID := "grey_box"
const HERD_ID := "steady"
const PLAN_ID := "demo"
const SEASONS := 5
const DEFAULT_SEED := 42
const MAX_SEED := 2147483647
const TICKS_PER_SECOND := 2.0
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const PANEL_WIDTH := 340.0
const HEADING_SIZE := 22
const BAR_HEIGHT := 12.0

## The valley to replay. Only tests change it.
@export var valley_id := VALLEY_ID

var season := 1
var run_seed := DEFAULT_SEED
var playhead := 0.0
var playing := true

var _speed := SPEEDS[0]
var _setup: RunSetup
var _plan := {}
var _layout: ValleyLayout
var _events: Array[Dictionary] = []
var _replay: SeasonReplay
var _season_buttons: Array[Button] = []
var _odds_bars := {}  # route id -> ProgressBar
var _odds_labels := {}  # route id -> Label
var _updating_slider := false

@onready var _map: RouteMap = %Map
@onready var _title: Label = %Title
@onready var _totals: Label = %Totals
@onready var _log: Label = %Log
@onready var _problem: Label = %Problem
@onready var _play: Button = %Play
@onready var _slider: HSlider = %Slider
@onready var _seed_box: SpinBox = %Seed


func _ready() -> void:
	# First, so there is a way out even if the data cannot be loaded.
	(%Back as Button).pressed.connect(_back_to_valley)
	_setup = GameData.load_setup(valley_id, HERD_ID)
	_plan = GameData.load_plan(PLAN_ID)
	if _setup == null or _plan.is_empty():
		_show_problem("The game data could not be loaded.")
		return
	_layout = ValleyLayout.new(_setup.graph)
	var missing := _layout.missing_segments()
	if not missing.is_empty():
		_show_problem("No map for: %s" % ", ".join(missing))
		return
	_map.set_run(_setup, _layout)
	_build_controls()
	load_seed(DEFAULT_SEED)


func _process(delta: float) -> void:
	if _replay == null or not playing:
		return
	playhead = minf(playhead + delta * TICKS_PER_SECOND * _speed, _replay.last_tick)
	if playhead >= _replay.last_tick:
		playing = false
	_refresh()


## Plays the whole run for a seed and shows its first season.
func load_seed(new_seed: int) -> void:
	run_seed = new_seed
	var run := SeasonRun.new(_setup, RandomStreams.new(run_seed))
	_events = run.run(SEASONS, _plan)
	show_season(1)


func show_season(number: int) -> void:
	season = number
	_replay = SeasonReplay.new(_setup, _events, season)
	_slider.max_value = _replay.last_tick
	for index: int in _season_buttons.size():
		_season_buttons[index].set_pressed_no_signal(index + 1 == season)
	restart()


func restart() -> void:
	playhead = 0.0
	playing = true
	_refresh()


func toggle_play() -> void:
	if playhead >= _replay.last_tick:
		restart()
		return
	playing = not playing
	_refresh()


func set_speed(index: int) -> void:
	_speed = SPEEDS[index]


func seek(time: float) -> void:
	playhead = clampf(time, 0.0, _replay.last_tick)
	_refresh()


## The events being replayed, for the test that they match a direct run.
func events() -> Array[Dictionary]:
	return _events


func _refresh() -> void:
	var frame := _replay.frame(playhead)
	_map.show_frame(_replay, frame)
	_title.text = (
		"Season %d of %d · tick %d of %d" % [season, SEASONS, int(playhead), _replay.last_tick]
	)
	_play.text = "Pause" if playing else "Play"
	_updating_slider = true
	_slider.value = playhead
	_updating_slider = false
	_show_odds()
	_totals.text = _totals_text(frame)
	var lines: PackedStringArray = frame["log"]
	_log.text = "\n".join(lines.slice(maxi(lines.size() - _log_room(), 0)))


## How many log lines fit, so the newest stay in view at any window size.
func _log_room() -> int:
	var line := _log.get_line_height() + _log.get_theme_constant("line_spacing")
	return maxi(int((_log.get_parent() as Control).size.y / line), 1)


func _totals_text(frame: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Money  %d" % frame["money"])
	lines.append("Herd  %d" % _replay.herd_size)
	lines.append("Killed  %d" % frame["killed"])
	lines.append("Breached  %d" % frame["breached"])
	var bands: PackedStringArray = []
	for option: Dictionary in _replay.routes:
		var route_id: String = option["route"]
		var short_name := _setup.graph.route_name(route_id).get_slice(" ", 0)
		bands.append("%s %d" % [short_name, _replay.bands_on_route(route_id)])
	lines.append("Bands  %s" % " · ".join(bands))
	return "\n".join(lines)


func _show_odds() -> void:
	for option: Dictionary in _replay.routes:
		var route_id: String = option["route"]
		var percent: float = option["p_ppm"] / 10000.0
		(_odds_bars[route_id] as ProgressBar).value = percent
		(_odds_labels[route_id] as Label).text = (
			"%s  %.0f%%" % [_setup.graph.route_name(route_id), percent]
		)


func _show_problem(text: String) -> void:
	_problem.text = text
	_problem.show()
	set_process(false)


func _build_controls() -> void:
	_play.pressed.connect(toggle_play)
	(%Restart as Button).pressed.connect(restart)
	_slider.value_changed.connect(_on_slider_moved)
	_seed_box.max_value = MAX_SEED
	_seed_box.value = DEFAULT_SEED
	_seed_box.value_changed.connect(func(value: float) -> void: load_seed(int(value)))
	var speed_picker := %Speed as OptionButton
	for speed: float in SPEEDS:
		speed_picker.add_item("%d×" % speed)
	speed_picker.item_selected.connect(set_speed)
	var picker := %Seasons as HBoxContainer
	var group := ButtonGroup.new()
	for number: int in range(1, SEASONS + 1):
		var button := Button.new()
		button.text = str(number)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(show_season.bind(number))
		picker.add_child(button)
		_season_buttons.append(button)
	var odds := %Odds as VBoxContainer
	for route_id: String in _setup.graph.route_ids:
		_add_odds_row(odds, route_id)


func _add_odds_row(odds: VBoxContainer, route_id: String) -> void:
	var label := Label.new()
	odds.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	var fill := StyleBoxFlat.new()
	fill.bg_color = _layout.route_color(route_id)
	var track := StyleBoxFlat.new()
	track.bg_color = ValleyLayout.TERRAIN_COLOR
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)
	odds.add_child(bar)
	_odds_bars[route_id] = bar
	_odds_labels[route_id] = label


func _on_slider_moved(value: float) -> void:
	if _updating_slider:
		return
	playing = false
	seek(value)


func _back_to_valley() -> void:
	get_tree().change_scene_to_file(VALLEY_SCENE)
