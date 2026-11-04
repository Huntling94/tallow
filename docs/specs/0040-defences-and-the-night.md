# Spec 0040: Defences, the night and the 5-season mini-run

- **Issue:** #40
- **Status:** Approved (2026-11-05)
- **Pillar:** Steer the herd
- **Milestone:** M1

## Problem and why it matters

The herd now chooses routes, but nothing the player does changes that choice or what happens next. This step gives the player the first real decision: where to put a few defences before the herd arrives, knowing only the odds. Defences do two separate jobs. Threat steers the herd away from a route, and killing stops beasts on it. A fence steers but kills nothing. A pit or a tower kills, but only on the route it sits on. Beasts that get through cost money, and money and defences carry over, so a choice in season 1 shapes season 5. This answers the M1 question directly: does committing under uncertainty create interesting choices?

## Scope

- **Defence types** as data in `game/data/defences.json`: fence, pit and harpoon tower, each with a cost, a threat, a chance per passing beast to kill it, and a capacity (most kills per night).
- **Run rules** as data in `game/data/run_rules.json`: starting money, a fixed levy each season (placeholder income until harvest in step 5), the cost per beast that breaches, beast speed and the spacing between bands.
- **Commands.** Before the herd arrives, the run applies a season's commands in order. M1 has one command: build a defence on a segment. A command is rejected, with a reason, if the defence or segment is unknown, the segment already has a defence, or there is not enough money.
- **Threat steers.** A defence's threat counts towards every route that uses its segment, through the existing threat term in the route utility. The odds in `route_options` now reflect the defences.
- **The night.** After the bands choose, they walk their routes in fixed ticks. When a band enters a segment with a pit or tower, each beast in it may be killed, until the defence's capacity for the night is used up. Beasts that reach the gate breach, and their cost is taken from the money.
- **The mini-run.** Money and defences carry over between seasons. A run is 5 seasons by default.
- **A scripted plan** for the headless runner: `game/data/plans/demo.json` lists commands by season, chosen with `--plan demo`. Without `--plan`, no commands are given, as today. Real bots are step 6.
- **From #39:** the rules version also hashes `game/src/loading/`. The herd file is checked fully (every key present and of the right type, `min <= max`, `band_min >= 1`), and so are the new data files.
- **Telemetry and the data dictionary** for the new events and fields.

## Out of scope

- Defence damage, repair, upkeep, selling or moving defences.
- Harvest, goods, prices and any income other than the levy (step 5).
- Running out of money ending the run. Money can go below zero in M1; a loss condition comes with the town in M4.
- Re-routing during the night, beasts attacking defences, and partial damage to beasts.
- Bots and their strategies (step 6), and the viewer (step 4).
- The other #39 items (duplicate ids, roughness range, wording and test folders) stay in #39.

## Acceptance criteria

- **AC1:** Given a fence on a segment of Low Ford only, then Low Ford's share in `route_options` falls and the other routes' shares rise. Given a fence on a segment every route shares, then the shares do not change.
- **AC2:** Given enough money and a free segment, when a build command is applied, then the money falls by the defence's cost and the defence is on the segment for this season and every later one. Given an unknown defence or segment, a segment already used, or too little money, then the command is rejected with that reason, and the money and defences are unchanged.
- **AC3:** Given a fence, then it never kills. Given a pit or tower, then it kills no more beasts in a night than its capacity.
- **AC4:** Given many beasts passing a pit or tower whose capacity is never reached, then the share killed is within 0.02 of its kill chance.
- **AC5:** Given any band, then its beasts killed plus its beasts breaching equal its size. Given any season, then the end money equals the start money plus the levy, minus build costs, minus breach costs.
- **AC6:** Given seed 42, 5 seasons and the demo plan, when the run is repeated, then the events are identical and match pinned golden values for season 1 (choices, kills and breaches) and the final money.
- **AC7:** Given a run, then events are ordered by (`season`, `tick`, `seq`), all prepare and choice events are at tick 0, and night events are at tick 1 or later.
- **AC8:** Given a change to a file in `game/src/loading/`, then the rules version changes. Given a herd file with a missing or mistyped key, `min > max` or `band_min < 1`, then loading fails with a message naming the problem.
- **AC9:** Given the headless runner with and without `--plan demo`, then `check_run` accepts both files, and the data dictionary lists every record and field written.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1 | gdUnit4 test on the odds with defences placed |
| AC2 | gdUnit4 tests on command handling |
| AC3, AC4 | gdUnit4 tests on night resolution over fixed seeds |
| AC5 | gdUnit4 invariant tests over many seeds |
| AC6 | gdUnit4 golden-seed test |
| AC7 | gdUnit4 test over a run's events |
| AC8 | gdUnit4 tests on `RulesVersion` and the herd loader with bad fixtures |
| AC9 | CI smoke job plus a runner test with the demo plan; review of the data dictionary |

## Telemetry

Schema version stays 1: new record types and new optional fields only.

| Record | Tick | Fields (beyond the common event fields) |
|---|---|---|
| `season_started` (new) | 0 | `money` (after the levy), `levy` |
| `command_applied` (new) | 0 | `command` (`"build"`), `defence`, `segment`, `cost`, `money` (after) |
| `command_rejected` (new) | 0 | `command`, `defence`, `segment`, `reason` (`unknown_command`, `unknown_defence`, `unknown_segment`, `segment_taken`, `not_enough_money`) |
| `herd_arrived`, `route_options`, `route_chosen` | 0 | As in spec 0037; `route_options[].threat` is now the sum of the defences' threat |
| `beast_killed` (new) | 1+ | `band`, `segment`, `defence` |
| `breach` (new) | 1+ | `band`, `beasts`, `cost`, `money` (after) |
| `season_ended` | last | new optional fields `money`, `killed`, `breached` |
| `run_end` | — | new optional field `money` |

## Design notes

- **One defence per segment.** It keeps placement a clear choice and makes `segment_taken` a real constraint. Shared segments can take defences too: a pit at The Neck cannot steer, but every band passes it, so it is a reliable killer with a small capacity.
- **Threat is whole units.** Placeholders: fence 2, pit 1, tower 1. With the `steady` weight of −1.5 per unit, a fence on Low Ford cuts its share from about 36% to about 3%, and a pit or tower to about 11%.
- **Kill chances in parts per million**, drawn with whole numbers from a `defences` stream, as route choice does. Placeholders: pit 400,000 per beast with capacity 3; tower 250,000 with capacity 6; fence 0 with capacity 0. Capacity resets every night.
- **Ticks.** Beasts move a fixed number of metres per tick (placeholder 400). Band *b* sets off at tick 1 + (*b* − 1) × spacing (placeholder 1). A band enters a segment at its start tick plus the whole ticks needed to cover the segments before it, and reaches the gate at its start tick plus the ticks for the whole route, rounded up. Defences act when the band enters their segment. All arrivals are ordered by tick, then band, then position on the route, and the draws happen in that order, so a run is the same on every platform.
- **Money is whole units.** Placeholders: start 300, levy 100 a season, fence 40, pit 80, tower 120, breach 10 per beast. A season with no defences and a herd of 24 costs 240, more than the levy, so doing nothing loses money.
- **Commands** are plain dictionaries, for example `{"command": "build", "defence": "pit", "segment": "ford_bank"}`. They are applied after the levy, in the order given.
- **The demo plan** builds a fence on Low Ford and a tower on Cairn Pass in season 1, and a pit at The Neck in season 2. It exists so the runner and the step 4 viewer have something to show, not to be good.
- **Code shape.** `RunState` (money, defences by segment) carries between seasons. `SeasonRun` plays one season on a state with that season's commands. The headless run loops over the seasons. Route features take the defences' threat by segment, so `RouteGraph` stays pure geometry.

## Open questions

- None blocking. Two defaults the maintainer may want to change: money can go negative with no consequence in M1, and defences cost nothing to keep. Both can change later; they are data and rules that only later steps depend on.
