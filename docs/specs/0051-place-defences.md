# Spec 0051: Place defences in the season viewer

- **Issue:** #51
- **Status:** Approved (2026-11-05)
- **Pillar:** Steer the herd
- **Milestone:** M1

## Problem and why it matters

The season viewer replays a fixed plan, so the player watches a night and decides nothing. A fence cannot feel like a decision if nobody can place one. M1 asks whether committing under uncertainty creates interesting choices, and that question has not yet been put to a person.

This step turns the viewer into a small playable run: prepare, release the herd, watch the night, then prepare again with the money left. It also shows up what is wrong with the current map and numbers, which is the input the bots in step 6 and any new valley need.

## Scope

- **A prepare phase before each season.** The player picks a defence, clicks a segment, and sees the money and route odds change straight away. A defence placed this season can be taken back until the herd is released.
- **Release the herd.** The choices go to the simulation as ordinary `build` commands through `SeasonRun.play_season`, one season at a time. The night then replays as it does today.
- **A five-season run.** After each night the player sees the result and moves on to the next prepare phase. After season 5 the run shows its final money and offers a new run.
- **The harvest on screen (covers #49).** The log says what was sold and for how much, and the season's result shows income, because money now drives the next choice.
- **Controls adjust to fit.** Played seasons can be watched again. Later seasons cannot be picked. A new seed, or the new run button, starts again from season 1.

## Out of scope

- Any change to `game/src/sim/` or `game/data/`, so the rules version and the golden seeds stay as they are. The only exception is a note in `game/data/README.md`, which does not count towards the rules version.
- Selling, moving or repairing a defence that has stood through a night. The simulation has no such command.
- Acting during the night, and any forecast or other new source of uncertainty.
- A new valley, or any balance change, including the shared-segment question in #46.
- Previewing the odds on hover. Placing and taking back is free, so a click does the same job.
- Saving a run, recording a player's run as telemetry, sound, final art and 3D.

## Acceptance criteria

- **AC1:** Given the viewer opens, then it shows the prepare phase for season 1 of seed 42, with the starting money, the herd's size range, the current odds, and each defence's name, cost, threat, kill chance and nightly capacity. No beasts are on the map.
- **AC2:** Given a defence is picked and an empty segment is clicked, then a marker appears on that segment, the money falls by the defence's cost, and the odds on the map and in the panel change. A click within 12 map units of a segment's line selects that segment, at any window size.
- **AC3:** Given a defence placed this season is clicked, then it is removed and its cost is returned. Given a defence that stood through an earlier night is clicked, then nothing changes.
- **AC4:** Given a segment that already holds a defence, or a defence the player cannot afford, then that placement is not made, the panel says why, and the money and odds do not change.
- **AC5:** Given any set of placements, when the herd is released, then the season's `route_options` shares equal the odds shown just before release, and the money on its last `command_applied` equals the money shown.
- **AC6:** Given a seed and the same choices each season, then the viewer's events equal those of a `SeasonRun` played directly with that seed and those commands.
- **AC7:** Given a released season, then the night replays with the existing play, pause, restart, speed and slider controls, and the placement controls cannot change it. When it ends, the panel shows the kills, breaches, income, breach costs and closing money, and a button leads to the next prepare phase.
- **AC8:** Given a new prepare phase, then the money and standing defences are those the simulation carried over, and the odds reflect them.
- **AC9:** Given season 5 has ended, then the panel shows the final money and a new run button, and no next prepare phase is offered.
- **AC10:** Given the season picker, then a played season can be watched again and a season not yet played cannot be picked. Going back to a past season during a prepare phase keeps the placements made so far.
- **AC11:** Given a new seed or the new run button, then the run goes back to season 1 prepare with the starting money and no defences.
- **AC12:** Given a `harvest` event, then the log line gives the goods sold and the income, at that event's tick. Given an event type the viewer does not know, then nothing changes and no error is raised.
- **AC13:** Given the default 1152 by 648 window, then every control in each phase fits on screen. Given the web build, then a full season can be prepared, released and watched with a mouse in a browser.

## Verification

| Criterion | How it is verified |
|---|---|
| AC2 (hit test), AC3, AC4, AC5 | gdUnit4 tests on `DefenceDraft` and `ValleyLayout` over the `grey_box` valley, including every defence on every segment for AC5 |
| AC6 | gdUnit4 scene test comparing the viewer's events with a direct `SeasonRun` |
| AC1, AC2 (mouse), AC7 to AC11 | gdUnit4 scene tests driven through the real signals and mouse events, reading what the panel shows |
| AC12 | gdUnit4 tests on `SeasonReplay` |
| AC13 | Scene test on minimum size at the default window; web build played in a browser, recorded on the PR with screenshots |

## Telemetry

None. The commands go through the simulation as usual, so `command_applied` and `command_rejected` are unchanged, and the viewer writes no files.

## Design notes

- **No rules in the viewer (ADR-0002, rule 4).** A new `DefenceDraft` in `game/src/viewer/` holds a private copy of `RunState`. Placing calls `RunState.build` on the copy, so a rejection carries the simulation's reason. The odds come from `threat_by_segment`, `RouteChoice.utilities` and `RouteChoice.probabilities_ppm`, the same calls `SeasonRun` makes. Taking a defence back rebuilds the copy from the remaining commands, so the viewer does no refund arithmetic. The live state is read and never written.
- **The levy.** It is paid before commands, so the draft starts from the state's money plus `season_levy`. The levy is 0 today. AC5 fails if this drifts from the simulation.
- **The run is played one season at a time.** The viewer keeps one `SeasonRun` and appends each season's events, so `SeasonReplay` works unchanged for any played season. The `demo` plan stays for the headless runner and tests, but the viewer no longer uses it.
- **Same seed, same herd.** Herd and band sizes come from their own random stream, so replaying a seed with different defences meets the same herds. That makes two plans fair to compare, and is why the new run button keeps the seed.
- **What the player does not know.** The herd's size, how the bands split, which route each band draws and each kill roll are all drawn after release. The player sees odds, not outcomes.
- **Clicking the map.** `ValleyLayout` finds the nearest segment line to a point on the sheet. `RouteMap` turns a mouse click into a signal carrying a segment id, and changes nothing itself. The map draws from a frame in both phases, so odds from the draft and from a replay reach the screen the same way.
- **Terms.** A *phase* is one stage of the season loop. The GDD's intended loop is forecast, prepare, migration night, harvest, trade and spend; this step builds prepare, night and harvest.

## Open questions

- **Should the shared segments stay buildable?** Issue #46 found that a tower on `neck_pass` and one on `town_approach` beat the best steering plan by 817 on average over 500 seeds. This spec leaves them buildable: blocking them in the viewer would be a rule outside the simulation, and playing it is useful evidence for #46.
