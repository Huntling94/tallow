class_name HerdPersonality
extends RefCounted
## How a herd weighs its routes, and how big it and its bands are (spec 0037).
## A different personality is a different set of numbers, not different rules.

var id: String
## Utility per kilometre of route.
var weight_length_per_km: float
## Utility per rough kilometre (length × roughness).
var weight_rough_per_km: float
## Utility per unit of threat on the route (from defences, step 3).
var weight_threat: float
var herd_min: int
var herd_max: int
var band_min: int
var band_max: int


func _init(
	personality_id: String,
	length_per_km: float,
	rough_per_km: float,
	threat: float,
	herd_size_min: int,
	herd_size_max: int,
	band_size_min: int,
	band_size_max: int
) -> void:
	id = personality_id
	weight_length_per_km = length_per_km
	weight_rough_per_km = rough_per_km
	weight_threat = threat
	herd_min = herd_size_min
	herd_max = herd_size_max
	band_min = band_size_min
	band_max = band_size_max
