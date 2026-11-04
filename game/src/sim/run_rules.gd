class_name RunRules
extends RefCounted
## The numbers that govern a run's money and the night (spec 0040).

var start_money: int
## Fixed income each season; a placeholder until harvest (M1 step 5).
var season_levy: int
var breach_cost_per_beast: int
var speed_m_per_tick: int
## Ticks between one band setting off and the next.
var band_spacing_ticks: int


func _init(start: int, levy: int, breach_cost: int, speed: int, spacing: int) -> void:
	start_money = start
	season_levy = levy
	breach_cost_per_beast = breach_cost
	speed_m_per_tick = speed
	band_spacing_ticks = spacing
