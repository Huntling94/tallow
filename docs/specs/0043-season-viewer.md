# Spec 0043: Top-down 2D season viewer

- **Issue:** #43
- **Status:** Approved (2026-11-05)
- **Pillar:** Read the odds
- **Milestone:** M1

## Problem and why it matters

The simulation can now play a whole 5-season mini-run, but its only output is a telemetry file. Nobody can watch a night, so nobody can judge whether placing a fence and hoping feels like a decision. This step puts one season on screen: the three routes, the defences on them, the odds, and the bands walking towards the gate, losing beasts on the way. It is also the first check that the event stream carries everything a presentation needs, ahead of the 3D valley in M2.

## Scope

- **A new scene,** `game/scenes/season_viewer.tscn`, in the look of the maintainer's route mock-up: a map of the route graph with coloured routes and beasts as moving ellipses, and a side panel.
- **It replays a seeded run.** It loads the setup through `GameData`, runs `SeasonRun` over 5 seasons with the `demo` plan, and keeps the events. Everything shown comes from those events, the valley data and `Night.arrivals`.
- **On the map:** segments and routes, the defences on their segments, every beast in every band moving tick by tick with interpolation between ticks, and kills and breaches at the moment they happen.
- **In the panel:** route odds, money, season totals (beasts killed, beasts breached, bands on each route), and a running log of what has happened so far.
- **Controls:** season picker (1 to 5), seed, play and pause, restart, speed, and a slider to move through the season.
- **Web build:** `data/*.json` joins the export, and the web job fails if it goes missing. A button in the dusk valley opens the viewer and a button in the viewer goes back. The dusk valley stays the first scene.

## Out of scope

- Any change to `game/src/sim/` or to the balance files in `game/data/`. No read-only additions to the simulation are needed.
- Placing defences or giving commands from the viewer. It only watches; the plan is fixed to `demo`.
- Reading telemetry files. The viewer runs the simulation itself.
- Showing harvest and prices. Those events arrive in step 5, and the viewer ignores them until a later change teaches it to show them.
- Sound, final art, and 3D.

## Acceptance criteria

- **AC1:** Given the `grey_box` valley, then every segment on every route has a path on the map, each route's paths join end to end from The Neck to the town gate, segments used by every route are drawn in a neutral colour, and the others in their route's colour.
- **AC2:** Given a band, then at the tick `Night.arrivals` gives for entering a segment it is at the start of that segment. Halfway between that tick and the next arrival it is halfway along the segment. Before it sets off it waits at the entry.
- **AC3:** Given a season's events, then a band's beast count drops by one at the tick of each of its `beast_killed` events, and the band leaves the map at the tick of its `breach` or when its last beast dies. Each kill and breach is marked on the map at that tick.
- **AC4:** Given a tick, then the money shown is the `money` of the latest event carrying the season's money at or before that tick, the totals count the kills and breaches so far, and the odds are the season's `route_options` shares. At the end of the season the money and totals equal `season_ended`.
- **AC5:** Given a season, then the defences drawn are those from every `command_applied` up to that season, so season 3 of the demo plan shows the fence, tower and pit. A `command_rejected` draws nothing.
- **AC6:** Given an event type the viewer does not know, then nothing drawn or shown changes and no error is raised.
- **AC7:** Given seed 42 and the demo plan, then the events the viewer replays equal those of a `SeasonRun` run directly with the same seed and plan. Moving to any point in the season, forwards or backwards, gives the same picture as playing to it, and the same tick never gives a different picture.
- **AC8:** Given the web export, then the pack holds `data/valleys/grey_box.json`, the viewer opens from the dusk valley and replays a season in a browser, and the dusk valley still plays its shot.
- **AC9:** Given the viewer, then each control does what its name says: the season picker changes the season, a new seed changes the run, and play, pause, restart, speed and the slider change only what is on screen.

## Verification

| Criterion | How it is verified |
|---|---|
| AC1 | gdUnit4 test on the map layout against the loaded valley |
| AC2, AC3, AC4, AC5, AC6 | gdUnit4 tests on the replay model, with hand-built events and over seed 42 |
| AC7 | gdUnit4 test comparing runs, and comparing frames reached in different orders |
| AC8 | Web job checks the pack; web build played in a browser, recorded on the PR with screenshots |
| AC9 | gdUnit4 test on the scene for season and seed; the rest played by hand |

## Telemetry

None. The viewer reads events and writes nothing.

## Design notes

- **Replay model.** `SeasonReplay` takes the setup and a run's events, and answers one question: what does the season look like at time *t*? It holds no clock and changes nothing, so any moment can be asked for in any order. The scene holds the playhead, a decimal number of ticks. This is ADR-0002 rule 7: the picture moves smoothly and nothing flows back into the rules.
- **Where a band is.** `Night.arrivals` gives the tick each band enters each segment and reaches the gate. Between two arrivals the band moves evenly along that segment. The viewer never works out speed or spacing, so it cannot disagree with the simulation.
- **The map layout is presentation, not rules.** The valley data has no coordinates, so a new `ValleyLayout` holds a hand-placed path for each segment, on the mock-up's 600 by 440 sheet. It lives in GDScript beside the viewer rather than in `game/data/`, because every file there counts towards the rules version, and redrawing a line must not mark runs as coming from different rules. A beast's distance along a path is a share of the segment, not metres, so a segment's drawn length can differ from its `length_m`.
- **Kills land where the rules put them.** A defence acts when a band enters its segment, so the marker sits just inside the start of the segment, not at its midpoint.
- **Spread within a band.** Each beast has a fixed offset to the side and behind, worked out from its number, so a band reads as a group. This is a viewer-only look and draws no random numbers.
- **Known events only.** The replay reads `season_started`, `command_applied`, `route_options`, `route_chosen`, `herd_arrived`, `beast_killed`, `breach` and `season_ended`. The harvest step is adding events at the same time; they are skipped, so money from sales will show only when a known event next reports it, until a follow-up adds them.
- **Season end.** `season_ended` carries the tick the replay stops on. Every surviving beast has breached by then.
- **Reaching it on the web.** A button is the smallest change, and it takes the click before the dusk camera's click-to-replay does.

## Open questions

- None blocking. The maintainer may want a plan picker or a no-defences run in the viewer later; both are small additions once there is more than one plan.
