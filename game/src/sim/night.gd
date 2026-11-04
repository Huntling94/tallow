class_name Night
extends RefCounted
## Migration night (spec 0040). Bands walk their chosen routes in fixed ticks.
## When a band enters a segment with a pit or tower, each beast in it may be
## killed until the defence's capacity for the night is used. Beasts that
## reach the gate breach and cost money.

const PPM := 1_000_000


## Night events in order, each with `type`, `tick` and its own fields (the
## season run adds `season` and `seq`). Takes breach costs from the state's
## money. `bands` holds {band, beasts, route} in band order.
static func resolve(
	setup: RunSetup, state: RunState, bands: Array[Dictionary], stream: RandomNumberGenerator
) -> Array[Dictionary]:
	var ordered := arrivals(setup, bands)
	var alive := {}
	for band: Dictionary in bands:
		alive[band["band"]] = band["beasts"]
	var capacity_left := {}
	for segment_id: String in state.defences:
		var defence: DefenceType = setup.defences[state.defences[segment_id]]
		capacity_left[segment_id] = defence.capacity
	var events: Array[Dictionary] = []
	for arrival: Array in ordered:
		var tick: int = arrival[0]
		var band: int = arrival[1]
		var segment_id: String = arrival[3]
		if segment_id == "":
			_breach(setup, state, events, tick, band, alive[band])
			continue
		if not state.defences.has(segment_id):
			continue
		var defence: DefenceType = setup.defences[state.defences[segment_id]]
		var beasts: int = alive[band]
		for _beast: int in beasts:
			if capacity_left[segment_id] <= 0 or defence.kill_ppm <= 0:
				break
			if stream.randi_range(0, PPM - 1) < defence.kill_ppm:
				alive[band] -= 1
				capacity_left[segment_id] -= 1
				(
					events
					. append(
						{
							"type": "beast_killed",
							"tick": tick,
							"band": band,
							"segment": segment_id,
							"defence": defence.id,
						}
					)
				)
	return events


## Every moment a band enters a segment or reaches the gate, as
## [tick, band, position on route, segment id or "" for the gate], sorted.
## Ticks are whole. A band enters a segment once it has covered every segment
## before it, and reaches the gate once it has covered the whole route, both
## rounded up to whole ticks (spec 0040). Distances are whole metres, far
## below the size where float division stops being exact. Public so the
## viewer can place bands between events.
static func arrivals(setup: RunSetup, bands: Array[Dictionary]) -> Array[Array]:
	var speed := setup.rules.speed_m_per_tick
	var found: Array[Array] = []
	for band: Dictionary in bands:
		var number: int = band["band"]
		var start := 1 + (number - 1) * setup.rules.band_spacing_ticks
		var walked := 0
		var segments := setup.graph.route_segments(band["route"])
		for position: int in segments.size():
			var entered := start + ceili(float(walked) / speed)
			found.append([entered, number, position, segments[position]])
			walked += setup.graph.segment_length(segments[position])
		found.append([start + ceili(float(walked) / speed), number, segments.size(), ""])
	found.sort_custom(_earlier)
	return found


static func _earlier(left: Array, right: Array) -> bool:
	for index: int in 3:
		if left[index] != right[index]:
			return left[index] < right[index]
	return false


static func _breach(
	setup: RunSetup, state: RunState, events: Array[Dictionary], tick: int, band: int, beasts: int
) -> void:
	if beasts <= 0:
		return
	var cost := beasts * setup.rules.breach_cost_per_beast
	state.money -= cost
	(
		events
		. append(
			{
				"type": "breach",
				"tick": tick,
				"band": band,
				"beasts": beasts,
				"cost": cost,
				"money": state.money,
			}
		)
	)
