class_name RunRules
extends RefCounted
## The numbers that govern a run's money, the night and the harvest (specs 0040
## and 0044).

var start_money: int
## Fixed income each season. 0 in the shipped data since harvest arrived.
var season_levy: int
var breach_cost_per_beast: int
var speed_m_per_tick: int
## Ticks between one band setting off and the next.
var band_spacing_ticks: int
## Goods from each beast killed.
var goods_per_beast: int
## The one price a good sells for.
var price_per_good: int


func _init(
	start: int, levy: int, breach_cost: int, speed: int, spacing: int, goods: int, price: int
) -> void:
	start_money = start
	season_levy = levy
	breach_cost_per_beast = breach_cost
	speed_m_per_tick = speed
	band_spacing_ticks = spacing
	goods_per_beast = goods
	price_per_good = price
