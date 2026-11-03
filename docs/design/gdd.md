# Game design document

> **Status: skeleton.** This document is living. Each section fills in as its system is specced and built; rules are written here only once a spec is approved. Until then, sections hold the intent from the [concept](../vision/concept.md) and the open questions to answer.

Every rule in this document should be testable: a unit test, an invariant, a design contract or a playtest step can show whether the game follows it.

## 1. Overview

See [concept](../vision/concept.md), [pillars](../vision/pillars.md) and [non-goals](../vision/non-goals.md).

## 2. The run

**Intent:** 12 seasons, win if the Lamphouse stands after the season 12 finale, loss if it falls, with a score so a win can be bettered.

**Open questions**
- What makes up the score, and how are its parts weighted?
- How does difficulty scale across the 12 seasons?
- What are the target win rates by bot type? (Proposed: a greedy bot wins about 30% of standard runs and a good bot about 70%.)
- Which unlocks exist, and how are they earned?

## 3. Seasons and phases

**Intent:** each season runs forecast → prepare → migration night → harvest → trade → spend.

**Open questions**
- Is preparation time limited, or does the player end it?
- Can the player act during migration night from the command view, or only on the wall?
- What carries over between seasons, and what resets?

## 4. Herds and beasts

**Intent:** colossal beasts migrate in herds with a personality. Big bulls drive both danger and value. Herds evolve under hunting pressure.

**Open questions**
- Which beast attributes matter (size, speed, health, temperament, hide quality)?
- How do herds hold together, split and panic?
- How is inheritance modelled across generations?
- What does the second species change?

## 5. Route choice

**Intent:** herds choose routes from terrain, noise, scent and defences through a visible probability model. The headline statistical model.

**Open questions**
- Which factors enter the model, and in what form?
- How is the model shown to the player?
- How do herds move along a chosen route (flow fields), and can they re-route mid-night?

## 6. Defences

**Intent:** layered defences that steer, stop and harvest. Clean kills are worth more; safer defences wreck the harvest.

**Open questions**
- Stats and costs for fence, pit, harpoon tower, wall, ballista and great gate.
- How does each defence affect route odds and hide quality?
- Repair, upkeep and destruction rules.
- How is "no single tower type dominates" measured?

## 7. Harvest

**Intent:** the town's people do the harvest. After a migration, crews go out to render fallen beasts into oil, bone and hide. Yield and quality depend on how each beast died, and how much is recovered depends on harvest capability: crews, tools, transport and rendering capacity. Money spent on harvest is money not spent on defence, and that split is one of the run's central decisions.

**Open questions**
- Yield formulas and quality tiers.
- The spoilage clock: how fast carcasses lose value, and how distance from town affects it.
- The harvest ladder: what each step (tools, carts, rendering yard, wagons, field camps) adds.
- Are crews drawn from the same workers who build and repair defences? If so, harvest and repair compete for labour after a bad night.
- Danger to crews: wounded stragglers, predators, bad weather. Can crews be lost?
- How to keep crew decisions few and meaningful (how many crews, which carcasses first) rather than individual worker admin.
- What happens to beasts that are wounded but not killed? (Link to the dawn hunt.)

## 8. Economy and the exchange

**Intent:** supply moves price; storage and forward contracts smooth it at a cost.

**Open questions**
- The price model for each good, and how fast it recovers.
- Storage costs (spoilage, warehouse fees, a rival flooding the market) that stop "store everything and sell at the spike".
- How forward contracts work and how they can go wrong.

## 9. Town

**Intent:** the town is more than a shop menu. Its people build the defences and do the harvest; their numbers, wages and morale feed back into both.

**Open questions**
- Buildings, costs and effects along the town ladder.
- Districts: how they are laid out, damaged and repaired.
- The Lamphouse: health, protection and what it stores.
- Workers, wages and morale.

## 10. Garrison and the breach

**Intent:** when the herd breaks through, the garrison, militia and barricades are the last line before the Lamphouse.

**Open questions**
- Unit types, strength and upkeep.
- How morale sets militia strength.
- How breach damage is decided and carried over.

## 11. The almanac

**Intent:** forecasts herd size, route and temperament with confidence bands, and scores itself against what happened.

**Open questions**
- How forecasts are generated from the true parameters plus noise.
- How the survey office and rumours tighten the bands.
- How forecast accuracy is scored.
- How uncertainty keeps rising faster than forecasting improves, so late runs stay uncertain.
- How rare-event odds are shown alongside the forecast.

## 11a. Rare events

**Intent:** most seasons follow the forecast, but rare events happen, as they do in real life. Their odds are always visible; their timing never is. Preparing for them is a cost the player chooses to pay or not.

**Proposed model:** two separate layers of randomness.
- **Everyday variation:** herd size, route and price move within the almanac's confidence bands.
- **Rare events:** arrive at a low, known rate per season (a Poisson process). Event sizes can be heavy-tailed, so the occasional event is far larger than the average one.

**Candidate events:** a stampede, a titan out of season, sickness in the herd, a hard frost that spoils the harvest, a market crash, a rival town's collapse that floods the exchange.

**Open questions**
- Which events, their rates, and their size distributions.
- How the almanac shows rare odds so players can read them (for example "about 1 season in 20").
- What preparation looks like for each event (reserves, stockpiles, insurance contracts, spare crews) and what it costs.
- Fairness in a 12-season run: should rare-event rates be capped, or should well-prepared towns always survive any single event? (Proposed design contract below.)
- Do rare events affect score, so surviving one is rewarded?

## 12. First person

**Intent:** walk the wall and fire the harpoon, walk the town, enter your house, buy kit, and hunt stragglers at dawn. Walking must change a decision.

**Open questions**
- Controls and switching between the command view and first person.
- Which decisions can only be made in person (rumours, exchange-floor deals)?
- The harpoon: aiming, damage and how it compares with towers.

## 13. Your house and kit

**Intent:** the house ladder shows your wealth; the workshop makes trap parts and personal kit.

**Open questions**
- What does each house level unlock?
- What kit exists, and what does it change?

## 14. Valleys, personalities and modifiers

**Intent:** a generated valley, a herd personality and one modifier make each run different.

**Open questions**
- What valley generation must guarantee (fairness, more than one viable route).
- The list of personalities and modifiers and their effects.

## 15. Presentation

**Intent:** fully 3D. An angled command camera over the same world as first person. A dusk cold open that impresses in five seconds.

**Open questions**
- Art direction and the visual target for the desktop and web builds.
- Camera behaviour and controls.
- Audio direction.
- The interface and its theme.

## 16. Balance targets and design contracts

Rules that run as tests in CI from M1 onwards. Proposed:

- A sensible defence survives season 1 on 95% of seeds.
- No single tower type dominates.
- Flooding the exchange crashes the price.
- Sustained culling of big bulls lowers mean size within N generations.
- The route model recovers the true preferences within tolerance.
- Neither all-defence nor all-harvest spending is the best strategy; the best bots split their spending.
- A well-prepared town survives any single rare event; an unprepared one may not.
- Rare events occur at their stated rates across many seeded runs.

Each will move into a dedicated balance document with exact thresholds once specced.
