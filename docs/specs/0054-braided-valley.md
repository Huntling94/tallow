# Spec 0054: A braided valley with closed ends and a tighter budget

- **Issue:** #54
- **Status:** Approved (2026-11-05)
- **Pillar:** Steer the herd
- **Milestone:** M1

## Problem and why it matters

Placing defences made the season a decision, but not a hard one. Two towers on the segments every route shares score far above any other plan, and they never need the odds read (#46). The rest of the map offers one fork and three separate branches, so a defence covers either one route or all of them.

A search of season 1 plans showed that no single change fixes this:

| Change | Best plan found | Final money | Steering plan |
|---|---|---|---|
| Today: `grey_box`, 600 to spend | Towers on both ends | 581 | Not close |
| Five routes only | Towers on both ends | 581 | Not close |
| Five routes, ends closed | A pit on every segment | 662 | Never chosen |
| Five routes, ends closed, 300 to spend, pit 2 a night, tower 8 a night | Pits on two segments, tower on a third | -447 | -485 |

So this step changes all three together. A *braided* valley is one whose routes split and rejoin, so that neighbouring routes share some segments.

## Scope

- **A new valley, `braided`,** with five routes and 11 segments. Neighbouring routes share a segment, so a defence can cover two routes but not all of them. It is the valley played in the viewer and the default for the headless runner.
- **Closed segments.** A valley can mark a segment as closed to building. `RunState.build` refuses it with `segment_closed`. In `braided`, `neck_pass` and `town_approach` are closed.
- **A tighter budget.** `start_money` goes from 600 to 300, pit capacity from 3 to 2 a night, and tower capacity from 6 to 8 a night.
- **The `demo` plan moves** so it still works: all three builds land in season 1, and the pit moves from `neck_pass` to `ridge_drop`.
- **The map reads the new valley.** Each of the five routes has its own colour, a segment on two routes shows both, and closed segments have no ring.
- **Herd through a segment.** While preparing, hovering a segment shows the share of the herd expected to pass it, added up from the current odds. This is what makes coverage and steering readable.

## Out of scope

- Forecasts, herds that learn, a loss condition, and other new sources of uncertainty.
- Upkeep, selling defences, or changing fence threat, kill chances, costs or the harvest.
- Tuning the numbers for a final balance. These are still placeholders until step 6's bots measure them, which is why #46 stays open.
- Changing `grey_box`. It stays as a test valley with nothing closed, so its tests and the `chokepoints` plan keep working.

## Acceptance criteria

- **AC1:** Given the `braided` file, then it loads with no graph errors, has five routes, every route shares at least one segment with another route besides the two ends, and no segment other than the two ends is on more than two routes.
- **AC2:** Given `braided` with no defences, then every route has at least a 12% chance and none has more than 28%.
- **AC3:** Given a valley that marks a segment closed, when a build targets it, then the command is rejected with `segment_closed`, money and defences do not change, and a `command_rejected` event records it. A valley that marks nothing closed behaves as before.
- **AC4:** Given a valley file with a closed flag that is not true or false, then loading fails with a clear error naming the segment.
- **AC5:** Given the viewer, then it plays `braided`, every segment has a path joined end to end for every route, and five routes have five different colours. A segment on exactly two routes shows both colours.
- **AC6:** Given the prepare phase, then a closed segment has no ring, and clicking it with a defence picked changes nothing and the panel says the ground cannot be built on.
- **AC7:** Given the prepare phase and the mouse over a segment, then the map shows the sum of the current odds of the routes through it, and that number changes when a placement changes the odds.
- **AC8:** Given the measured plans over 200 seeds on `braided` (a coverage plan, a steering plan and a mixed plan, each buying in season 1 only), then no plan's mean final money is more than 150 above the second best. The result is recorded on the PR. It does not run in CI: step 6's bots are the real measure.
- **AC9:** Given the changed numbers, then every test and golden seed passes, each changed golden value is listed on the PR with the reason, and the telemetry dictionary lists `segment_closed`.
- **AC10:** Given the web build, then `braided` is in the pack, and a full run can be played with a mouse in a browser.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1, AC2, AC4 | gdUnit4 tests on the loaded valley and on bad data |
| AC3 | gdUnit4 tests on `RunState` and `SeasonRun`, written first |
| AC5 | gdUnit4 tests on `ValleyLayout` |
| AC6, AC7 | gdUnit4 tests on the scene; hover checked by hand |
| AC8 | A throwaway run of the three plans, with the results on the PR |
| AC9 | Full test suite and CI |
| AC10 | Web job checks the pack; web build played in a browser, recorded on the PR |

## Telemetry

`command_rejected.reason` gains the value `segment_closed`. No events or fields are added.

## Design notes

- **The valley.** The five routes, west to east, with all but the ends shown:

| Route | Segments between the ends | Shares with |
|---|---|---|
| Cairn Pass | `cairn_west`, `cairn_south` | The Saddle |
| The Saddle | `cairn_west`, `saddle`, `ridge_drop` | Cairn Pass, Split Ridge |
| Split Ridge | `ridge_climb`, `ridge_drop` | The Saddle, The Spur |
| The Spur | `ridge_climb`, `spur`, `ford_flats` | Split Ridge, Low Ford |
| Low Ford | `ford_bank`, `ford_crossing`, `ford_flats` | The Spur |

- **New segments.** `saddle` runs from `cairn` to `ridge_top`, 300 m with roughness 0.1. `spur` runs from `ridge_top` to `flats`, 700 m with roughness 0.4. Every other segment keeps its `grey_box` id, length and roughness.
- **Base odds, from the candidate file:** about 20% Cairn Pass, 15% The Saddle, 21% Split Ridge, and the rest on The Spur and Low Ford.
- **Why closed, not removed.** The herd still walks those segments, so they keep their length and roughness in the route model. Only building is refused. The Neck is too wide to hold and the approach is the town's own ground, so the reason fits the world.
- **The rule stays in the simulation (ADR-0002).** `RouteGraph` holds the flag and `RunState.build` applies it. `DefenceDraft` gets the same refusal through `build`, so the viewer adds no rule.
- **The same paths draw both valleys.** `braided` keeps `grey_box`'s ids, so `ValleyLayout.PATHS` gains two entries and the map draws only segments in the loaded graph. Map layout stays out of `game/data/`, as in spec 0043.
- **Rules version.** It changes, as a new valley and new numbers should.
- **The search behind the table.** 40 seeds, plans bought in season 1 only, by hand and by adding the best next defence. It is a rough guide, not a balance result. Money is negative on these plans because nothing is reinvested in later seasons.

## Open questions

- **Should these numbers change in this step?** They change `grey_box` tests and golden values too. The alternative is to ship the map and closed ends first, but then a pit on every segment wins and fences go unused, so this spec includes them.
