class_name RouteChoice
extends RefCounted
## Multinomial logit route choice (spec 0037, GDD section 5). Each route gets a
## utility from its features and the herd's weights; its chance of being chosen
## is exp(utility) over the sum for all routes. Chances are kept as whole parts
## per million so the draw is exact on every platform.

const PPM := 1_000_000


## One utility per route, in the graph's route order, with threat from the
## defences on each segment (segment id -> threat units).
static func utilities(
	graph: RouteGraph, herd: HerdPersonality, threat_by_segment: Dictionary = {}
) -> PackedFloat64Array:
	var result: PackedFloat64Array = []
	for route_id: String in graph.route_ids:
		var features := graph.features(route_id, threat_by_segment)
		result.append(
			(
				herd.weight_length_per_km * features["length_m"] / 1000.0
				+ herd.weight_rough_per_km * features["rough_m"] / 1000.0
				+ herd.weight_threat * features["threat"]
			)
		)
	return result


## Each route's chance in whole parts per million, summing to exactly PPM.
## The largest utility is subtracted first so nothing overflows. Every share
## but the last is rounded down, so the last one, which takes the remainder,
## is never negative.
static func probabilities_ppm(route_utilities: PackedFloat64Array) -> PackedInt64Array:
	var top := route_utilities[0]
	for value: float in route_utilities:
		top = maxf(top, value)
	var weights: PackedFloat64Array = []
	var total := 0.0
	for value: float in route_utilities:
		weights.append(exp(value - top))
		total += weights[-1]
	var shares: PackedInt64Array = []
	var assigned := 0
	for index: int in weights.size() - 1:
		shares.append(floori(weights[index] / total * PPM))
		assigned += shares[-1]
	shares.append(PPM - assigned)
	return shares


## The route index that a draw from 0 to PPM - 1 falls in.
static func choose(shares: PackedInt64Array, draw: int) -> int:
	var running := 0
	for index: int in shares.size():
		running += shares[index]
		if draw < running:
			return index
	return shares.size() - 1
