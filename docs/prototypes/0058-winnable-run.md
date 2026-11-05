# Prototype report: a winnable run

Issue #58. Code: `prototypes/winnable-run/`.

## Verdict: keep

The maintainer played the build at commit `4d79774` and chose to keep it. Asked directly about the issue's two tests, wanting another run and seasons 2 to 5 feeling like decisions, the maintainer said that was fine for now. So neither test is recorded as met or failed: the keep is a judgement on that build as a whole.

The code in this PR is not exactly that build, and has not been replayed. After the keep call, a review led to changes: runners now really ignore fences, two hill pads and one other pad moved, and hills lost some range.

Tallow's season should play as a tower defence: spaced-out beasts, visible combat, a few distinct defences, and herds you steer rather than only shoot.

The prototype code is not promoted. Whatever is kept is rebuilt through the full loop.

## The question moved

- The issue asked whether a winnable run with a night action makes a season fun.
- That is not what ended up being tested. The maintainer found the first build too complex and short on feedback, so the prototype was rebuilt twice.
- Signal fires, the night action in the issue, were cut. Building during a herd took their place.
- The question it answered in the end: does a season work as a 3D tower defence in which beasts choose their own roads? On the build played, the maintainer's answer was yes. Whether choosing roads adds real strategy is still open, as set out below.
- The five-route valley also went, replaced by a new road network. The score became the town and money left, shown on the win screen.

## What was built

Three builds, each playable:

| Build | Change | Maintainer's response |
|---|---|---|
| 1 | Five-route map with bands of beasts, odds on screen, signal fires | Too complex, too little feedback |
| 2 | 3D tower defence on three roads, with each beast its own unit and visible shots | Getting there; wanted more route strategy, a better build menu and more entrances |
| 3 | Sixteen roads with twelve to choose from, three entrances, beast types, mortar, hills, build menu with selling | Keep |

## What worked

- **Each beast as its own unit.** Spacing them out made every fight readable. Bands moved as one marker gave nothing to watch.
- **Visible cause and effect.** Shots, health bars, kills, floating rewards and breaches replaced the dice roll, the event log and the odds panel.
- **Hiding the odds.** Steering can be read without numbers: the player sees it in where beasts walk and in the bright tracks left behind. Whether it is worth doing is a separate question, covered under the tuning.
- **Entrances with a warning.** A changing start point adds a new question each season, and the warning gives the player time to answer it.
- **Counters instead of panels.** Runners ignore fences and ironhides ignore pits. That adds variety without adding a number to the screen.
- **A menu on the ring.** Building where you are looking, with a preview of range before paying, is much clearer than arming a tool first.

## What the tuning showed

Win rates over 2,000 runs of `tune.mjs`, using scripted players:

| Player | Wins |
|---|---|
| Builds nothing | 0% |
| Careless | 9% |
| Sensible: guns where the herd walks, no fences | 84% |
| Funnels herds with fences | 93% |

The sensible bot reads the hidden odds, which a person cannot, and the funnelling bot follows one fixed plan. They say more about the rules than about how a person plays. No person's win rate was measured, and no bot builds or sells during a herd.

Steering is the design's core idea, and it leads here, but that lead proved fragile. Four findings matter for the real game:

1. **Steering must be stronger than shooting's side effect.** With towers scary enough to matter, stacked scare drove herds off the defended roads and the funnelling bot won 0% of runs. Towers now scare a third as much, and fences do the steering.
2. **Firepower has to be scarce.** With a tower reaching two roads, or money for every pad, plain spreading beat steering. One road per tower and tight money reversed that on the earlier map. The final map dropped that limit: a tower pad reaches 1 to 6 roads, so spreading stays strong.
3. **Stretches every beast must walk defeat steering.** Build spots stay out of reach of the last stretch and the fork areas of the early maps. This is the same problem as #46.
4. **Steering's lead moves with small changes.** The build played had a bug: runners were meant to ignore fences, but were still slowed and partly turned by them. Fixing it took funnelling level with sensible play, 88% to 89%. Moving three pads and cutting hill range restored the lead, 93% to 84%. So the lead depends on map details, and the funnelling bot is crude. Treat steering as not yet proven.

## What is not proven

- Whether the fun lasts past a few runs. A run is five seasons, with no longer game around it.
- Whether steering is worth doing, given finding 4 above.
- Whether the final numbers feel the same as the build played. Nobody has played them.
- Whether selling can bypass a pit's limit. A spent pit can be sold and rebought during a herd, which refills it for slightly less than the extra kills earn. No bot does this, and the rebuild should not inherit it.
- Whether building during a herd, which replaced the night action, adds anything. The bots never do it.
- Harvest, trade, the exchange and walking the town. None of them are in this prototype.
- Sound was built but never checked by ear during development.
- Season length and difficulty at real play. Only the maintainer has played it, and there is no playtest data.

## What this changes

- **The simulation design.** `game/src/sim/` picks a route for a whole band at the start of a night. The prototype has individual beasts choosing at each fork from the way ahead. Keeping the feel needs a new spec, and an ADR if it changes how the route model works.
- **#54 and PR #55, braided valley.** Both were designed around the old season and need rethinking against this result.
- **#46 and #56.** The findings above bear directly on both.
- **The Python route-model fit.** It assumes the current route choice, so it should wait until the choice model is settled.
