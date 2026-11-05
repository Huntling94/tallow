# Prototype report: a winnable run

Issue #58. Code: `prototypes/winnable-run/`.

## Verdict: keep

The maintainer played the final build and chose to keep it. Tallow's season should play as a tower defence: spaced-out beasts, visible combat, a few distinct defences, and herds you steer rather than only shoot.

The prototype code is not promoted. Whatever is kept is rebuilt through the full loop.

## The question moved

- The issue asked whether a winnable run with a night action makes a season fun.
- That is not what ended up being tested. The maintainer found the first build too complex and short on feedback, so the prototype was rebuilt twice.
- Signal fires, the night action in the issue, were cut. Building during a herd took their place.
- The question it answered in the end: does a season work as a 3D tower defence in which beasts choose their own roads? Yes.
- The issue's second keep test, that seasons 2 to 5 feel like decisions, was not asked separately. The maintainer's answer covers the build as a whole.

## What was built

Three builds, each playable:

| Build | Change | Maintainer's response |
|---|---|---|
| 1 | Five-route map with bands of beasts, odds on screen, signal fires | Too complex, too little feedback |
| 2 | 3D tower defence on three roads, with each beast its own unit and visible shots | Getting there; wanted more route strategy, a better build menu and more entrances |
| 3 | Eleven roads, three entrances, beast types, mortar, hills, build menu with selling | Keep |

## What worked

- **Each beast as its own unit.** Spacing them out made every fight readable. Bands moved as one marker gave nothing to watch.
- **Visible cause and effect.** Shots, health bars, kills, floating rewards and breaches replaced the dice roll, the event log and the odds panel.
- **Hiding the odds.** Steering survives without numbers. The player reads it from where beasts walk and from the bright tracks left behind.
- **Entrances with a warning.** A changing start point adds a new question each season, and the warning makes it a decision rather than a surprise.
- **Counters instead of panels.** Runners ignore fences and ironhides ignore pits. That adds variety without adding a number to the screen.
- **A menu on the ring.** Building where you are looking, with a preview of range before paying, is much clearer than arming a tool first.

## What the tuning showed

Win rates over 2,000 runs of `tune.mjs`, using scripted players:

| Player | Wins |
|---|---|
| Builds nothing | 0% |
| Careless | 6% |
| Sensible: guns where the herd walks, no fences | 83% |
| Funnels herds with fences | 92% |

These are bots with perfect knowledge of the odds, so they say more about the rules than about how a person plays. No person's win rate was measured.

Steering only pays under certain conditions. Three findings matter for the real game:

1. **Steering must be stronger than shooting's side effect.** With towers scary enough to matter, stacked scare drove herds off the defended roads and the funnelling bot won 0% of runs. Towers now scare a third as much, and fences do the steering.
2. **Firepower has to be scarce.** With a tower reaching two roads, or money for every pad, plain spreading beat steering. One road per tower and tight money reversed that on the earlier map.
3. **Stretches every beast must walk defeat steering.** Build spots stay out of reach of the last stretch and the fork areas of the early maps. This is the same problem as #46.

## What is not proven

- Whether the fun lasts past a few runs. Tuned run length is about five seasons, with no longer game around it.
- Harvest, trade, the exchange and walking the town. None of them are in this prototype.
- Sound was built but never checked by ear during development.
- Season length and difficulty at real play. Only the maintainer has played it, and there is no playtest data.

## What this changes

- **The simulation design.** `game/src/sim/` picks a route for a whole band at the start of a night. The prototype has individual beasts choosing at each fork from the way ahead. Keeping the feel needs a new spec, and an ADR if it changes how the route model works.
- **#54 and PR #55, braided valley.** Both were designed around the old season and need rethinking against this result.
- **#46 and #56.** The findings above bear directly on both.
- **The Python route-model fit.** It assumes the current route choice, so it should wait until the choice model is settled.
