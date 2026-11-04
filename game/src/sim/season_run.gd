class_name SeasonRun
extends RefCounted
## A run of seasons on the route graph (spec 0037). Each season a herd arrives,
## splits into bands, and each band chooses a route by multinomial logit.
## Defences, the night and money arrive in the next step.


## The events of a run of `seasons` seasons, in order. Each event has `type`,
## `season`, `tick` and `seq` plus its own fields. The caller creates the
## streams from the run seed; the run never makes its own.
func run(
	streams: RandomStreams, graph: RouteGraph, herd: HerdPersonality, seasons: int
) -> Array[Dictionary]:
	var herd_stream := streams.for_system("herd")
	var route_stream := streams.for_system("routes")
	var events: Array[Dictionary] = []
	for season: int in range(1, seasons + 1):
		var herd_size := herd_stream.randi_range(herd.herd_min, herd.herd_max)
		var bands := _band_sizes(herd_size, herd, herd_stream)
		var utilities := RouteChoice.utilities(graph, herd)
		var shares := RouteChoice.probabilities_ppm(utilities)
		var tick := 0
		var seq := 0
		events.append(
			_event(
				"herd_arrived", season, tick, seq, {"herd_size": herd_size, "bands": bands.size()}
			)
		)
		seq += 1
		events.append(
			_event(
				"route_options", season, tick, seq, {"routes": _options(graph, utilities, shares)}
			)
		)
		for band: int in bands.size():
			seq += 1
			var choice := RouteChoice.choose(
				shares, route_stream.randi_range(0, RouteChoice.PPM - 1)
			)
			(
				events
				. append(
					_event(
						"route_chosen",
						season,
						tick,
						seq,
						{"band": band + 1, "beasts": bands[band], "route": graph.route_ids[choice]},
					)
				)
			)
		seq += 1
		events.append(_event("season_ended", season, tick, seq, {}))
	return events


## Splits the herd into bands of band_min to band_max beasts. A remainder too
## small to be a band joins the last band, so a band can reach
## band_max + band_min - 1.
func _band_sizes(
	herd_size: int, herd: HerdPersonality, stream: RandomNumberGenerator
) -> Array[int]:
	var sizes: Array[int] = []
	var left := herd_size
	while left > 0:
		var size := mini(left, stream.randi_range(herd.band_min, herd.band_max))
		if left - size < herd.band_min:
			size = left
		sizes.append(size)
		left -= size
	return sizes


func _options(
	graph: RouteGraph, utilities: PackedFloat64Array, shares: PackedInt64Array
) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for index: int in graph.route_ids.size():
		var route_id := graph.route_ids[index]
		var features := graph.features(route_id)
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


func _event(type: String, season: int, tick: int, seq: int, fields: Dictionary) -> Dictionary:
	var event := {"type": type, "season": season, "tick": tick, "seq": seq}
	event.merge(fields)
	return event
