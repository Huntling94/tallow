class_name SeasonViewer
extends Control
## The playable run (specs 0043 and 0051). Each season the player places
## defences on a DefenceDraft, then release sends them to the simulation as
## ordinary commands and the night replays. The playhead here is the only
## clock, it counts decimal ticks for the picture, and it never reaches the
## simulation.

const VALLEY_SCENE := "res://scenes/valley.tscn"
const VALLEY_ID := "braided"
const HERD_ID := "steady"
const SEASONS := 5
const DEFAULT_SEED := 42
const MAX_SEED := 2147483647
const TICKS_PER_SECOND := 2.0
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const BAR_HEIGHT := 12.0
const ODDS_LABEL_WIDTH := 190.0
const DEFENCE_TEXT_SIZE := 13
const HINT_START := "Rings mark open segments. Click this season's defence to take it back."
const HINT_PICK_FIRST := "Pick a defence first."
const HINT_STANDING := "That defence stood through a night, so it stays."
const HINT_CLOSED := "This ground cannot be built on."
const REASONS := {
	"segment_closed": HINT_CLOSED,
	"segment_taken": "That segment already has a defence.",
	"not_enough_money": "Not enough money for that defence.",
}

## The valley to play. Only tests change it.
@export var valley_id := VALLEY_ID

var season := 1
var run_seed := DEFAULT_SEED
var playhead := 0.0
var playing := false
## How many seasons the simulation has played in this run.
var played := 0

var _speed := SPEEDS[0]
var _setup: RunSetup
var _layout: ValleyLayout
var _run: SeasonRun
var _events: Array[Dictionary] = []
var _replay: SeasonReplay  # null while preparing
var _draft: DefenceDraft  # kept while a past season is watched
var _picked := ""  # defence id
var _season_buttons: Array[Button] = []
var _defence_buttons := {}  # defence id -> Button
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
@onready var _hint: Label = %Hint
@onready var _result_text: Label = %ResultText
@onready var _next: Button = %NextSeason


func _ready() -> void:
	# First, so there is a way out even if the data cannot be loaded.
	(%Back as Button).pressed.connect(_back_to_valley)
	_setup = GameData.load_setup(valley_id, HERD_ID)
	if _setup == null:
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
	# The browser window can change size while paused.
	(%LogBox as Control).resized.connect(_refresh)


func _process(delta: float) -> void:
	if _replay == null or not playing:
		return
	playhead = minf(playhead + delta * TICKS_PER_SECOND * _speed, _replay.last_tick)
	if playhead >= _replay.last_tick:
		playing = false
	_refresh()


## True while the coming season is on screen, waiting for the player.
func is_preparing() -> bool:
	return _replay == null


## Starts a run from season 1 on this seed.
func load_seed(new_seed: int) -> void:
	run_seed = new_seed
	_run = SeasonRun.new(_setup, RandomStreams.new(run_seed))
	_events = []
	_draft = null
	played = 0
	show_season(1)


## Shows a played season, or prepares the next one. Later seasons do nothing.
func show_season(number: int) -> void:
	if number > mini(played + 1, SEASONS):
		return
	season = number
	if number <= played:
		_watch()
	else:
		_prepare()


func pick_defence(defence_id: String) -> void:
	_picked = "" if _picked == defence_id else defence_id
	for id: String in _defence_buttons:
		(_defence_buttons[id] as Button).set_pressed_no_signal(id == _picked)


## A click on a segment while preparing: takes back this season's defence, or
## places the picked one.
func press_segment(segment_id: String) -> void:
	if not is_preparing():
		return
	if _draft.remove(segment_id):
		_hint.text = "Taken back."
	elif _picked == "":
		_hint.text = _unpicked_hint(segment_id)
	else:
		var reason := _draft.place(_picked, segment_id)
		_hint.text = REASONS.get(reason, reason)
	_refresh()


func _unpicked_hint(segment_id: String) -> String:
	if _setup.graph.is_closed(segment_id):
		return HINT_CLOSED
	return HINT_STANDING if _draft.defences().has(segment_id) else HINT_PICK_FIRST


## Commits the choices. The season is played here, and only shown after this.
func release() -> void:
	if not is_preparing():
		return
	_events.append_array(_run.play_season(_draft.commands()))
	played += 1
	_draft = null
	show_season(played)


func restart() -> void:
	if is_preparing():
		return
	playhead = 0.0
	playing = true
	_refresh()


func toggle_play() -> void:
	if is_preparing():
		return
	if playhead >= _replay.last_tick:
		restart()
		return
	playing = not playing
	_refresh()


func set_speed(index: int) -> void:
	_speed = SPEEDS[index]


func seek(time: float) -> void:
	if is_preparing():
		return
	playhead = clampf(time, 0.0, _replay.last_tick)
	_refresh()


## The events played so far, for the test that they match a direct run.
func events() -> Array[Dictionary]:
	return _events


func _prepare() -> void:
	_replay = null
	playing = false
	if _draft == null:
		_draft = DefenceDraft.new(_setup, _run.state)
		_hint.text = HINT_START
	_map.set_picking(true)
	_refresh()


func _watch() -> void:
	_replay = SeasonReplay.new(_setup, _events, season)
	_slider.max_value = _replay.last_tick
	_map.set_picking(false)
	restart()


func _refresh() -> void:
	_show_phase()
	for index: int in _season_buttons.size():
		var button := _season_buttons[index]
		button.set_pressed_no_signal(index + 1 == season)
		button.disabled = index + 1 > played + 1
	if is_preparing():
		_refresh_prepare()
	else:
		_refresh_night()


func _show_phase() -> void:
	var preparing := is_preparing()
	var finished := not preparing and playhead >= _replay.last_tick
	(%Prepare as Control).visible = preparing
	(%Controls as Control).visible = not preparing
	_slider.visible = not preparing
	(%Result as Control).visible = finished
	# The result carries the money and totals, and the panel has no room for both.
	_totals.visible = not finished
	(%LogHeading as Control).visible = not preparing
	(%LogBox as Control).visible = not preparing


func _refresh_prepare() -> void:
	var frame := _draft.frame()
	_map.show_frame(frame)
	_title.text = "Season %d of %d · prepare" % [season, SEASONS]
	_show_odds(frame["routes"])
	_totals.text = (
		"Money  %d\nHerd  %d to %d beasts"
		% [_draft.money(), _setup.herd.herd_min, _setup.herd.herd_max]
	)


func _refresh_night() -> void:
	var frame := _replay.frame(playhead)
	_map.show_frame(frame)
	_title.text = (
		"Season %d of %d · tick %d of %d" % [season, SEASONS, int(playhead), _replay.last_tick]
	)
	_play.text = "Pause" if playing else "Play"
	_updating_slider = true
	_slider.value = playhead
	_updating_slider = false
	_show_odds(frame["routes"])
	_totals.text = _totals_text(frame)
	var lines: PackedStringArray = frame["log"]
	_log.text = "\n".join(lines.slice(maxi(lines.size() - _log_room(), 0)))
	_show_result(frame)


func _show_result(frame: Dictionary) -> void:
	var lines: PackedStringArray = []
	lines.append(
		(
			"Season %d: %d killed, %d breached. Income %d, breach costs %d."
			% [season, frame["killed"], frame["breached"], frame["income"], frame["breach_costs"]]
		)
	)
	var closing := "Money %d." % frame["money"]
	if played >= SEASONS:
		closing += " Run over, final money %d." % _run.state.money
	lines.append(closing)
	_result_text.text = "\n".join(lines)
	_next.visible = played < SEASONS
	_next.text = "Prepare season %d" % (played + 1)


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
	return "\n".join(lines)


func _show_odds(routes: Array) -> void:
	for option: Dictionary in routes:
		var route_id: String = option["route"]
		var percent: float = option["p_ppm"] / 10000.0
		(_odds_bars[route_id] as ProgressBar).value = percent
		var text := "%s  %.0f%%" % [_setup.graph.route_name(route_id), percent]
		if not is_preparing():
			var bands := _replay.bands_on_route(route_id)
			text += " · %d band%s" % [bands, "" if bands == 1 else "s"]
		(_odds_labels[route_id] as Label).text = text


func _show_problem(text: String) -> void:
	_problem.text = text
	_problem.show()
	set_process(false)


func _build_controls() -> void:
	_play.pressed.connect(toggle_play)
	(%Restart as Button).pressed.connect(restart)
	(%Release as Button).pressed.connect(release)
	(%NewRun as Button).pressed.connect(func() -> void: load_seed(run_seed))
	_next.pressed.connect(func() -> void: show_season(played + 1))
	_map.segment_pressed.connect(press_segment)
	_slider.value_changed.connect(_on_slider_moved)
	_seed_box.max_value = MAX_SEED
	_seed_box.value = DEFAULT_SEED
	_seed_box.value_changed.connect(func(value: float) -> void: load_seed(int(value)))
	var speed_picker := %Speed as OptionButton
	for speed: float in SPEEDS:
		speed_picker.add_item("%d×" % speed)
	speed_picker.item_selected.connect(set_speed)
	var picker := %Seasons as HBoxContainer
	for number: int in range(1, SEASONS + 1):
		var button := Button.new()
		button.text = str(number)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_season_button.bind(number))
		picker.add_child(button)
		_season_buttons.append(button)
	var odds := %Odds as VBoxContainer
	for route_id: String in _setup.graph.route_ids:
		_add_odds_row(odds, route_id)
	_add_defence_buttons()


func _add_defence_buttons() -> void:
	var ids: Array = _setup.defences.keys()
	ids.sort_custom(
		func(left: String, right: String) -> bool:
			return _setup.defences[left].cost < _setup.defences[right].cost
	)
	for defence_id: String in ids:
		var button := Button.new()
		button.text = _defence_text(_setup.defences[defence_id])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.add_theme_font_size_override("font_size", DEFENCE_TEXT_SIZE)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(pick_defence.bind(defence_id))
		(%Defences as VBoxContainer).add_child(button)
		_defence_buttons[defence_id] = button


static func _defence_text(defence: DefenceType) -> String:
	var kills := "no kills"
	if defence.kill_ppm > 0:
		kills = "%.0f%% kill, %d a night" % [defence.kill_ppm / 10000.0, defence.capacity]
	return "%s  %d · threat %d · %s" % [defence.display_name, defence.cost, defence.threat, kills]


func _add_odds_row(odds: VBoxContainer, route_id: String) -> void:
	var row := HBoxContainer.new()
	odds.add_child(row)
	var label := Label.new()
	label.custom_minimum_size.x = ODDS_LABEL_WIDTH
	label.add_theme_font_size_override("font_size", DEFENCE_TEXT_SIZE)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = _layout.route_color(route_id)
	var track := StyleBoxFlat.new()
	track.bg_color = ValleyLayout.TERRAIN_COLOR
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", track)
	row.add_child(bar)
	_odds_bars[route_id] = bar
	_odds_labels[route_id] = label


func _on_season_button(number: int) -> void:
	show_season(number)
	_refresh()


func _on_slider_moved(value: float) -> void:
	if _updating_slider:
		return
	playing = false
	seek(value)


func _back_to_valley() -> void:
	get_tree().change_scene_to_file(VALLEY_SCENE)
