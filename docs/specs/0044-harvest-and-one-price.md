# Spec 0044: Harvest and one price

- **Issue:** #44
- **Status:** Approved (2026-11-05)
- **Pillar:** Steer the herd
- **Milestone:** M1

## Problem and why it matters

Kills earn nothing today. A pit or tower kills 3 to 6 beasts of a herd of about 24, and each kill only saves a 10 breach cost, so on seed 42 the demo plan ends on −530 against −460 for building nothing. Defending is a losing choice, which leaves the M1 question with nothing to measure. This step turns each kill into goods and each good into money. A defence now pays for itself, and step 6's bots get an economy worth playing.

## Scope

- **Harvest phase.** After the night, every beast killed that season becomes goods, and the goods sell at once at one price. This changes the money in `RunState`.
- **Data.** Two new fields in `game/data/run_rules.json`: `goods_per_beast` and `price_per_good`, checked by the loader.
- **The levy goes.** `season_levy` is set to 0 and `start_money` rises from 300 to 600 (see Design notes). The rule and the `season_started.levy` field stay, so the schema does not change.
- **A better plan to compare with.** `game/data/plans/chokepoints.json`: a harpoon tower on each of the two segments every route shares.
- **A balance sanity test** in CI, over many seeds, for the numbers below.
- **Telemetry and the data dictionary** for the new record.
- **From #42:** the data dictionary's wording for the tick of `season_ended`.

## Out of scope

- Any market model: supply moving the price, storage, spoilage or forward contracts. The exchange is M3. Goods never carry over, because nothing here makes holding them a choice.
- Harvest crews, tools and capacity, yield by how a beast died, and spending on harvest (GDD section 7). Every kill is harvested in full.
- Changing defence numbers, the valley or the herd. Kills, breaches and routes stay exactly as they are.
- Bots, full sweeps and the GDD section 16 contracts (step 6).
- The other #42 items.

## Acceptance criteria

- **AC1:** Given a season with kills, when the night ends, then one `harvest` event gives the beasts killed, goods of beasts × `goods_per_beast`, the price, income of goods × `price_per_good`, and the money after sale, and the state's money rises by that income.
- **AC2:** Given a season with no kills, then the `harvest` event still appears, with 0 beasts, 0 goods and 0 income, and the money is unchanged.
- **AC3:** Given any season, then `harvest` comes after every night event and directly before `season_ended`, on the same tick.
- **AC4:** Given any seed and plan, then each `harvest.beasts` equals that season's `beast_killed` events, and each season's end money equals its start money plus the levy, minus build costs, minus breach costs, plus harvest income.
- **AC5:** Given two runs that differ only in price, with every build affordable in both, then their routes, kills and breaches are identical: the harvest draws no random numbers.
- **AC6:** Given seed 42, 5 seasons and the demo plan, when the run is repeated, then the events are identical and match pinned golden values for the season 1 harvest and the final money.
- **AC7:** Given the same 200 seeds, 5 seasons and each plan, then the demo plan and the chokepoints plan each end with more money than no defences on at least 95% of seeds, and every build in both plans is applied on every seed.
- **AC8:** Given run rules with `goods_per_beast` or `price_per_good` missing, mistyped or negative, then loading fails with a message naming the problem.
- **AC9:** Given the headless runner with `--plan chokepoints`, then `check_run` accepts the file, the schema version is still 1, and the data dictionary lists every record and field written.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1, AC2, AC3 | gdUnit4 unit tests on the harvest and the season's events |
| AC4 | gdUnit4 invariant tests over many seeds and plans |
| AC5 | gdUnit4 test comparing two runs |
| AC6 | gdUnit4 golden-seed test |
| AC7 | gdUnit4 balance test |
| AC8 | gdUnit4 tests on the run-rules check with bad values |
| AC9 | CI smoke job plus a runner test; review of the data dictionary |

## Telemetry

Schema version stays 1: one new record type, nothing renamed or removed.

| Record | Tick | Fields (beyond the common event fields) |
|---|---|---|
| `harvest` (new) | the night's last event | `beasts`, `goods`, `price`, `income`, `money` (after the sale) |

`season_started.levy` keeps its meaning and is now 0 in the shipped data.

## Design notes

- **One record, not two.** With no storage, harvesting and selling can't come apart, so a single `harvest` record is enough. M3 can add its own records when selling becomes a decision.
- **One `harvest` every season,** even with no kills, so anything reading the file can count on it, as with `season_ended`.
- **No randomness.** The harvest is whole-number arithmetic with no draws, so adding it leaves every random stream alone. Golden routes and kills don't move; only money does.
- **Code shape.** A new pure `Harvest.resolve` in `game/src/sim/harvest.gd`, called by `SeasonRun` after the night, with the same shape as `Night.resolve`: it changes the state's money and returns its event.
- **The numbers.** Placeholders: 4 goods per beast at 5 each, so a kill earns 20, twice the 10 it saves by not breaching. The two values are separate because later work moves them separately: yield with how the beast died (GDD section 7), price with the exchange (M3).
- **Why the levy goes.** It added the same money to every plan, so it never told plans apart, and it was only ever a stand-in for this income. It did one real job: paying for season 2 builds. At start 300 and levy 0, the demo plan's season 2 pit is rejected on nearly every seed, because season 1's breaches empty the purse. Moving the money to the start fixes that and suits the milestone better, because it is one lump to commit up front rather than a steady drip. At 500 the pit is still rejected on about 1 seed in 5; at 600 it is always built.
- **The rule stays at 0 rather than being deleted,** because removing `season_started.levy` would raise the schema version for no gain, and the viewer's lane shares that contract.

### Evidence

500 seeds, 5 seasons, measured on the finished code. Start 600, levy 0, a kill worth 20. The balance test re-checks the first three rows in CI over 200 seeds.

| Plan | Spent | Kills | Breaches | Mean final money | 10th to 90th percentile | Beats no defences |
|---|---|---|---|---|---|---|
| No defences | 0 | 0 | 120 | −600 | −700 to −500 | n/a |
| Demo (poor by design) | 240 | 16 | 104 | −348 | −490 to −210 | 100% |
| Chokepoints: tower on each shared segment | 240 | 47 | 73 | 574 | 410 to 730 | 100% |
| Tower and pit on shared segments | 200 | 40 | 80 | 405 | 270 to 530 | 100% |
| Two pits on shared segments | 160 | 30 | 90 | 137 | 40 to 240 | 100% |
| Tower and pit on shared, plus two fences | 280 | 40 | 80 | 325 | 190 to 450 | 100% |
| Build up over three seasons | 479 | 52 | 68 | 471 | 290 to 660 | 100% |
| Towers everywhere as money allows | 733 | 62 | 58 | 516 | 270 to 720 | 100% |
| Steering: fences on two routes, tower on Cairn Pass | 200 | 19 | 101 | −243 | −400 to −80 | 100% |
| Steering: as above plus a pit | 280 | 18 | 103 | −356 | −570 to −160 | 94% |
| Fence on Split Ridge, kill on Low Ford | 240 | 4 | 117 | −732 | −880 to −570 | 7% |

The last row is a plan that loses on purpose: its own threat pushes the herd off the route where it kills. A bad placement should cost money, and it does.

## Open questions

- **Steering loses to not steering, and this step does not fix it.** Two towers on `neck_pass` and `town_approach`, the segments every route shares, catch every beast whatever route it picks. That plan ends on 574, 817 above the best steering plan's −243. It ignores the odds entirely, which is the opposite of what M1 is testing. It is true at every price tried from 0 to 30, so no price can fix it: the cause is shared segments, not this economy. Proposal: leave it visible for step 6's bots to measure, then decide there. The likely fix is that the shared segments take fences only, or are removed from the valley's defence spots. The maintainer may prefer to fix it sooner.
- **No plan here ends above its starting 600.** The best comes close at 574, so a run is still a fight to hold on to money rather than to get rich. That is fine for a sanity check, and real tuning is step 6.
