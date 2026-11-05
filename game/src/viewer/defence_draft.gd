class_name DefenceDraft
extends RefCounted
## The player's choices for the coming season, before the herd is released
## (spec 0051). It builds on a private copy of the run's state with the
## simulation's own RunState and RouteChoice, so a preview cannot disagree
## with the season that follows and no rules live here. The live state is
## read once and never written.

const BUILD := "build"

var _setup: RunSetup
var _start_money: int
var _standing := {}  # segment id -> defence id, from earlier seasons
var _copy: RunState
var _commands: Array[Dictionary] = []


## The levy is paid before commands, so it is spendable this season.
func _init(setup: RunSetup, state: RunState) -> void:
	_setup = setup
	_start_money = state.money + setup.rules.season_levy
	_standing = state.defences.duplicate()
	_rebuild()


func money() -> int:
	return _copy.money


## Segment id -> defence id, standing and placed this season.
func defences() -> Dictionary:
	return _copy.defences


## True when the defence on this segment can still be taken back.
func is_new(segment_id: String) -> bool:
	return _copy.defences.has(segment_id) and not _standing.has(segment_id)


## Places a defence. Returns "" on success, or the simulation's reason for
## turning it down. A refused placement changes nothing.
func place(defence_id: String, segment_id: String) -> String:
	var reason := _copy.build(_setup, defence_id, segment_id)
	if reason == "":
		_commands.append({"command": BUILD, "defence": defence_id, "segment": segment_id})
	return reason


## Takes back a defence placed this season. Returns false if there is none.
func remove(segment_id: String) -> bool:
	if not is_new(segment_id):
		return false
	var kept: Array[Dictionary] = []
	for command: Dictionary in _commands:
		if command["segment"] != segment_id:
			kept.append(command)
	_commands = kept
	_rebuild()
	return true


## The commands to send to SeasonRun.play_season, in the order they were placed.
func commands() -> Array[Dictionary]:
	return _commands.duplicate()


## The odds with these defences, shaped like the entries of `route_options`.
func odds() -> Array[Dictionary]:
	var threat := _copy.threat_by_segment(_setup)
	var utilities := RouteChoice.utilities(_setup.graph, _setup.herd, threat)
	var shares := RouteChoice.probabilities_ppm(utilities)
	var options: Array[Dictionary] = []
	for index: int in _setup.graph.route_ids.size():
		var route_id := _setup.graph.route_ids[index]
		var features := _setup.graph.features(route_id, threat)
		options.append(
			{"route": route_id, "length_m": features["length_m"], "p_ppm": shares[index]}
		)
	return options


## What the map shows while preparing: the same shape as a replay frame, with
## no beasts on it, plus which defences are this season's.
func frame() -> Dictionary:
	var fresh := {}
	for command: Dictionary in _commands:
		fresh[command["segment"]] = true
	return {
		"bands": [],
		"breach_note": {},
		"defences": defences(),
		"marks": [],
		"new_defences": fresh,
		"routes": odds(),
	}


func _rebuild() -> void:
	_copy = RunState.new(_start_money)
	_copy.defences = _standing.duplicate()
	for command: Dictionary in _commands:
		_copy.build(_setup, command["defence"], command["segment"])
