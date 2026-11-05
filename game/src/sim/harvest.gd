class_name Harvest
extends RefCounted
## The harvest after the night (spec 0044). Every beast killed becomes goods,
## and the goods sell at once at one price. Whole-number arithmetic with no
## random draws, so it changes money and nothing else.


## Adds the season's income to the state's money and returns the `harvest`
## event, with `type`, `tick` and its own fields (the season run adds `season`
## and `seq`). `beasts` is how many were killed this season.
static func resolve(rules: RunRules, state: RunState, beasts: int, tick: int) -> Dictionary:
	var goods := beasts * rules.goods_per_beast
	var income := goods * rules.price_per_good
	state.money += income
	return {
		"type": "harvest",
		"tick": tick,
		"beasts": beasts,
		"goods": goods,
		"price": rules.price_per_good,
		"income": income,
		"money": state.money,
	}
