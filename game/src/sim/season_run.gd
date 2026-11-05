class_name SeasonRun
extends RefCounted
## A run of seasons (specs 0037, 0040 and 0044). Each season: the levy is paid,
## the season's commands are applied, a herd arrives and splits into bands,
## each band chooses a route by multinomial logit, the night is resolved, then
## the kills are harvested and sold. Money and defences carry over in `state`.

var state: RunState

var _setup: RunSetup
var _herd_stream: RandomNumberGenerator
var _route_stream: RandomNumberGenerator
var _defence_stream: RandomNumberGenerator
var _season := 0


## The caller creates the streams from the run seed; the run never makes its own.
func _init(setup: RunSetup, streams: RandomStreams) -> void:
	_setup = setup
	state = RunState.new(setup.rules.start_money)
	_herd_stream = streams.for_system("herd")
	_route_stream = streams.for_system("routes")
	_defence_stream = streams.for_system("defences")


## Plays `seasons` seasons. `plan` maps a season number to its commands.
## Returns every event in order.
func run(seasons: int, plan: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _index: int in seasons:
		events.append_array(play_season(plan.get(_season + 1, [])))
	return events


## Plays the next season with these commands. Each event has `type`,
## `season`, `tick` and `seq` plus its own fields.
func play_season(commands: Array) -> Array[Dictionary]:
	_season += 1
	var herd := _setup.herd
	var graph := _setup.graph
	var tick_zero: Array[Dictionary] = []

	state.money += _setup.rules.season_levy
	tick_zero.append(
		{"type": "season_started", "levy": _setup.rules.season_levy, "money": state.money}
	)
	for command: Dictionary in commands:
		tick_zero.append(_apply(command))

	var herd_size := _herd_stream.randi_range(herd.herd_min, herd.herd_max)
	var band_sizes := _band_sizes(herd_size)
	tick_zero.append({"type": "herd_arrived", "herd_size": herd_size, "bands": band_sizes.size()})
	var threat := state.threat_by_segment(_setup)
	var utilities := RouteChoice.utilities(graph, herd, threat)
	var shares := RouteChoice.probabilities_ppm(utilities)
	tick_zero.append({"type": "route_options", "routes": _options(utilities, shares, threat)})
	var bands: Array[Dictionary] = []
	for index: int in band_sizes.size():
		var choice := RouteChoice.choose(shares, _route_stream.randi_range(0, RouteChoice.PPM - 1))
		var band := {
			"band": index + 1, "beasts": band_sizes[index], "route": graph.route_ids[choice]
		}
		bands.append(band)
		var chosen := {"type": "route_chosen"}
		chosen.merge(band)
		tick_zero.append(chosen)
	for event: Dictionary in tick_zero:
		event["tick"] = 0

	var night := Night.resolve(_setup, state, bands, _defence_stream)
	var killed := 0
	var breached := 0
	var last_tick := 1
	for event: Dictionary in night:
		last_tick = maxi(last_tick, event["tick"])
		if event["type"] == "beast_killed":
			killed += 1
		elif event["type"] == "breach":
			breached += event["beasts"]
	var harvest := Harvest.resolve(_setup.rules, state, killed, last_tick)
	var ended := {
		"type": "season_ended",
		"tick": last_tick,
		"money": state.money,
		"killed": killed,
		"breached": breached,
	}

	var events: Array[Dictionary] = []
	events.append_array(tick_zero)
	events.append_array(night)
	events.append(harvest)
	events.append(ended)
	return _number(events)


func _apply(command: Dictionary) -> Dictionary:
	var defence: String = str(command.get("defence", ""))
	var segment: String = str(command.get("segment", ""))
	var kind: String = str(command.get("command", ""))
	var reason := "unknown_command"
	if kind == "build":
		reason = state.build(_setup, defence, segment)
	if reason != "":
		return {
			"type": "command_rejected",
			"command": kind,
			"defence": defence,
			"segment": segment,
			"reason": reason,
		}
	var cost: int = _setup.defences[defence].cost
	return {
		"type": "command_applied",
		"command": kind,
		"defence": defence,
		"segment": segment,
		"cost": cost,
		"money": state.money,
	}


## Splits the herd into bands of band_min to band_max beasts. A remainder too
## small to be a band joins the last band, so a band can reach
## band_max + band_min - 1.
func _band_sizes(herd_size: int) -> Array[int]:
	var herd := _setup.herd
	var sizes: Array[int] = []
	var left := herd_size
	while left > 0:
		var size := mini(left, _herd_stream.randi_range(herd.band_min, herd.band_max))
		if left - size < herd.band_min:
			size = left
		sizes.append(size)
		left -= size
	return sizes


func _options(
	utilities: PackedFloat64Array, shares: PackedInt64Array, threat: Dictionary
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var graph := _setup.graph
	for index: int in graph.route_ids.size():
		var route_id := graph.route_ids[index]
		var features := graph.features(route_id, threat)
		(
			options
			. append(
				{
					"route": route_id,
					"length_m": features["length_m"],
					"rough_m": features["rough_m"],
					"threat": features["threat"],
					"utility": snappedf(utilities[index], 0.000001),
					"p_ppm": shares[index],
				}
			)
		)
	return options


## Adds `season` and `seq` to events already in tick order. `seq` counts from
## 0 within each tick.
func _number(events: Array[Dictionary]) -> Array[Dictionary]:
	var tick := -1
	var seq := 0
	for event: Dictionary in events:
		if event["tick"] != tick:
			tick = event["tick"]
			seq = 0
		event["season"] = _season
		event["seq"] = seq
		seq += 1
	return events
