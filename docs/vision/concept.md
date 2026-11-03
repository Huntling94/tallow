# Concept

> Status: pre-production. This concept is fixed once the game is greenlit; until then it changes by pull request.

## Pitch

A lamp-lit boomtown sits on the migration route of colossal beasts. You build defences that steer and stop the herds from a 3D command view, send your townspeople out to harvest what falls, sell what they bring in on the town exchange, and walk your own streets in first person to spend what you have earned. If the herd breaks through, the town and its standing army are the last line. Lose too often and the lamps go out for good.

## Core loop (one season)

1. **Forecast.** The almanac predicts herd size, route and temperament, with confidence bands.
2. **Prepare.** Build and adjust defences in the command view.
3. **Migration night.** The herd arrives. Watch, adjust, or take the wall in first person.
4. **Harvest.** Your townspeople go out at dawn to render the fallen beasts into oil, bone and hide. Crews, tools and rendering capacity set how much they recover before it spoils.
5. **Trade.** Sell on the exchange, store, or take forward contracts.
6. **Spend.** Defences, harvest capability, town buildings, your house and your kit.

Then a bigger herd next season.

## Layers of defence

Drive fences, pits and lures → a kill corridor of harpoon towers → the wall and gates → the town (garrison, militia, barricades) → **the Lamphouse**, the town's central oil store.

Breaches damage districts, and the damage carries into the next season. If the Lamphouse falls, the town is destroyed and the run ends.

## The run

- **One run is 12 seasons**, about 2 to 3 hours: two migrations a year for six years.
- **Win:** the Lamphouse still stands after season 12, whose migration is led by a titan-class beast.
- **Loss:** the Lamphouse falls.
- **Score:** wealth, what you built, damage taken and forecast accuracy, so a win can be bettered.
- **Variety:** each run has a generated valley, a herd personality (skittish, migratory, led by a matriarch) and one modifier (drought, rival town, hard winter).
- **Escalation:** herds grow, a second species arrives around season 5, and a titan leads the finale.
- **Between runs:** unlocks widen choice (new buildings, species, almanac techniques, starting perks) rather than adding raw power.
- **Seeds:** any run can be replayed from its seed.

## Signature mechanics

- **Defence or harvest.** Defences stop the herd; your townspeople turn the fallen into wealth. Every coin goes to one or the other: more towers, or more crews, tools, wagons and rendering sheds. Over-invest in harvest and the herd breaks through; over-invest in defence and carcasses rot in the field.
- **Clean kills are worth more.** Pits and harpoons keep hides whole; fire and blunt towers are safer but wreck the harvest.
- **Herds choose routes.** Terrain, noise, scent and your defences feed a visible route-choice model. Placing a pit redraws the odds live.
- **The almanac.** Forecasts with confidence bands, scored against what actually happened. A survey office tightens the bands.
- **Rare events happen.** Most seasons follow the forecast, but stampedes, titans out of season, sickness in the herd and market crashes arrive at low, known rates. The almanac shows their odds but never their timing, and some events are far larger than the usual run of seasons suggests. Preparing for a rare event costs money in every season it does not come.
- **Supply moves price.** Flood the exchange and the price crashes; storage and forward contracts smooth it, at a cost.
- **Evolving herds.** Take the big bulls and average size falls over generations, so big hides get rarer and dearer.
- **The dawn hunt (optional, first person).** Finish wounded stragglers before they spoil, for bonus parts.

## Arc

Outpost (palisade, rendering shed, a rented room) → Boomtown (stone wall, exchange, your own house) → Lamp city (bone bridge, grand exchange, a mansion on the ridge).

## Build ladders

- **Defences:** drive fence → pit trap → harpoon tower → stone wall → ballista → great gate.
- **Harvest:** hand crews → flensing tools → carts → rendering yard → draught-beast wagons → field rendering camps.
- **Town:** rendering shed → exchange → barracks → survey office → bone bridge → grand exchange.
- **Your house:** rented room → cottage → townhouse → merchant's house → mansion on the ridge.

## Vertical slice (about 30 minutes of play)

One valley, one town, one beast species, three seasons. Four defence pieces (fence, pit, harpoon tower, wall). Five town buildings (rendering shed, exchange, barracks, your house, one shop). One garrison unit. Three goods (oil, bone, hide). An almanac forecast of size and route. In first person: walk the town, enter your house, buy one item, walk the wall and fire the harpoon. One fail state (the Lamphouse falls). The dusk cold open. And one statistical model done properly: herd route choice, fitted from bot runs and shown to recover the true parameters.

## The statistics underneath

The simulation knows the true probabilities behind every beast, buyer and rival, including the rates of rare events. Everyday variation and rare shocks are modelled separately: rare events arrive at a set rate (a Poisson process), and their sizes can be heavy-tailed, so the occasional event is far larger than the average. That lets the project prove its models work: fit a model on telemetry from headless runs, then show it recovers the parameters the simulation actually used. Model cards and calibration reports are published with each release. Players feel the models through tension and prices; the maths lives in the almanac and in this repository.

## Directions explored and set aside

- **Life on a walking titan:** the most original frame, but moving-platform physics at that scale is too risky for a small team.
- **Ice Age monument building:** feasible, but without money it loses the trading game.
- **Sci-fi gold rush:** a crowded genre.
- **Vertical cavern city:** needs diggable terrain, which is heavy technology.
- **Volcano settlement:** the disaster loop risks swamping the trading.
- **Selective breeding:** real quantitative genetics, but a weaker fit with trade.
- **First-person big-beast hunting:** close melee with huge beasts is hard to make feel good, so the idea was reshaped into defence-led play.
