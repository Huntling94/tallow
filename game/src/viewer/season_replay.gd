class_name SeasonReplay
extends RefCounted
## One season of a run, as the viewer shows it (spec 0043). It folds the
## season's events into what is on screen at any moment, and decides nothing:
## `frame` is a plain question with no clock behind it, so any moment can be
## asked for in any order (ADR-0002, rule 7). Between events, bands are placed
## from Night.arrivals, so they can never disagree with the simulation.
##
## Only the event types below are read. Any other type is skipped, so the
## simulation can add events without the viewer breaking.

const WAITING := "waiting"
const WALKING := "walking"
const GONE := "gone"
const KILL := "kill"
const BREACH := "breach"

## The tick the season stops on.
var last_tick := 0
## The season's route_options entries, in the valley's route order.
var routes: Array[Dictionary] = []
var herd_size := 0

var _setup: RunSetup
var _defences := {}  # segment id -> defence id, standing this season
var _bands: Array[Dictionary] = []  # {band, beasts, route} from route_chosen
var _walks := {}  # band number -> ticks it enters each segment, then the gate
var _kills: Array[Dictionary] = []
var _breaches: Array[Dictionary] = []
var _money: Array[Dictionary] = []  # {tick, money}, in event order
var _log: Array[Dictionary] = []  # {tick, text}, in event order


## `events` is a whole run; only `season`, and earlier builds, are used.
func _init(setup: RunSetup, events: Array[Dictionary], season: int) -> void:
	_setup = setup
	for event: Dictionary in events:
		var from_season: int = event["season"]
		if event["type"] == "command_applied" and from_season <= season:
			_defences[event["segment"]] = event["defence"]
		if from_season == season:
			_read(event)
	for arrival: Array in Night.arrivals(setup, _bands):
		var band: int = arrival[1]
		var walk: Array[int] = []
		walk.assign(_walks.get(band, []))
		walk.append(arrival[0])
		_walks[band] = walk


## How many bands chose this route this season.
func bands_on_route(route_id: String) -> int:
	var count := 0
	for band: Dictionary in _bands:
		if band["route"] == route_id:
			count += 1
	return count


## What is on screen `time` ticks into the season. `time` may fall between
## ticks. Each entry in `bands` has `band`, `route`, `beasts`, `state` and
## `progress`, where 2.5 is halfway along the route's third segment.
func frame(time: float) -> Dictionary:
	var marks: Array[Dictionary] = []
	var lost := {}
	var killed := 0
	for kill: Dictionary in _kills:
		if kill["tick"] <= time:
			lost[kill["band"]] = lost.get(kill["band"], 0) + 1
			killed += 1
			marks.append(_mark(kill, KILL, time))
	var breached_bands := {}
	var breached := 0
	for breach: Dictionary in _breaches:
		if breach["tick"] <= time:
			breached_bands[breach["band"]] = true
			breached += breach["beasts"]
			marks.append(_mark(breach, BREACH, time))
	var bands: Array[Dictionary] = []
	for band: Dictionary in _bands:
		bands.append(_band_at(band, time, lost, breached_bands))
	var log_lines: PackedStringArray = []
	for line: Dictionary in _log:
		if line["tick"] <= time:
			log_lines.append(line["text"])
	return {
		"bands": bands,
		"breached": breached,
		"defences": _defences,
		"killed": killed,
		"log": log_lines,
		"marks": marks,
		"money": _money_at(time),
	}


func _read(event: Dictionary) -> void:
	var tick: int = event["tick"]
	var text := ""
	match event["type"]:
		"season_started":
			text = "Levy of %d paid" % event["levy"]
			_money.append({"tick": tick, "money": event["money"]})
		"command_applied":
			var defence := _defence_name(event["defence"])
			text = "%s built on %s for %d" % [defence, _pretty(event["segment"]), event["cost"]]
			_money.append({"tick": tick, "money": event["money"]})
		"herd_arrived":
			herd_size = event["herd_size"]
			text = "%d beasts arrive in %d bands" % [herd_size, event["bands"]]
		"route_options":
			routes.assign(event["routes"])
		"route_chosen":
			var band := {"band": event["band"], "beasts": event["beasts"], "route": event["route"]}
			_bands.append(band)
			var route := _setup.graph.route_name(event["route"])
			text = "Band %d (%d) takes %s" % [event["band"], event["beasts"], route]
		"beast_killed":
			_kills.append(event)
			var killer := _defence_name(event["defence"])
			text = "Band %d: beast killed by %s" % [event["band"], killer]
		"breach":
			_breaches.append(event)
			_money.append({"tick": tick, "money": event["money"]})
			text = "Band %d: %d breach, cost %d" % [event["band"], event["beasts"], event["cost"]]
		"season_ended":
			last_tick = tick
			_money.append({"tick": tick, "money": event["money"]})
			text = "Season over: %d killed, %d breached" % [event["killed"], event["breached"]]
	if text != "":
		_log.append({"tick": tick, "text": text})


func _band_at(band: Dictionary, time: float, lost: Dictionary, breached: Dictionary) -> Dictionary:
	var number: int = band["band"]
	var beasts: int = band["beasts"] - lost.get(number, 0)
	var ticks: Array[int] = _walks[number]
	var state := WALKING
	if beasts <= 0 or breached.has(number):
		state = GONE
	elif time < ticks[0]:
		state = WAITING
	return {
		"band": number,
		"beasts": beasts,
		"progress": _progress(ticks, time),
		"route": band["route"],
		"state": state,
	}


## How far along its route a band is. It moves evenly between arrivals.
static func _progress(ticks: Array[int], time: float) -> float:
	for index: int in ticks.size() - 1:
		if time < ticks[index]:
			return float(index)
		if time < ticks[index + 1]:
			return index + (time - ticks[index]) / (ticks[index + 1] - ticks[index])
	return float(ticks.size() - 1)


func _money_at(time: float) -> int:
	var money := 0
	for entry: Dictionary in _money:
		if entry["tick"] <= time:
			money = entry["money"]
	return money


func _mark(event: Dictionary, kind: String, time: float) -> Dictionary:
	return {
		"age": time - event["tick"],
		"band": event["band"],
		"beasts": event.get("beasts", 1),
		"kind": kind,
		"segment": event.get("segment", ""),
	}


func _defence_name(defence_id: String) -> String:
	var defence: DefenceType = _setup.defences[defence_id]
	return defence.display_name


static func _pretty(segment_id: String) -> String:
	return segment_id.replace("_", " ")
