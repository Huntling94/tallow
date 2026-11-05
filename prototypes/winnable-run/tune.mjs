// Plays the prototype's rules with simple players, to set the numbers.
// Run: node prototypes/winnable-run/tune.mjs
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const rules = html.slice(html.indexOf('// RULES-START'), html.indexOf('// RULES-END'));
const api = new Function(`${rules}; return { TUNE, DEFENCES, ROADS, SPOTS, SPOT, OUT, newRun, place, startNight, stepNight, nextSeason, oddsAt };`)();
const { TUNE, DEFENCES, ROADS, SPOTS, SPOT, OUT, newRun, place, startNight, stepNight, nextSeason, oddsAt } = api;

const PADS = SPOTS.filter((s) => s.kind === 'pad');
const MARKS = SPOTS.filter((s) => s.kind === 'road');
const free = (run, list) => list.filter((s) => !run.built[s.id]);
const FLOW_ORDER = ['west', 'north', 'south', 'a', 'c', 'b', 'd', 'f', 'e', 'm'];

// Share of the coming herd expected on each road at today's odds.
function traffic(run) {
  const at = { west: 0, north: 0, south: 0, a: 0, b: 0, c: 0, d: 0, e: 0, f: 0, m: 0 };
  for (const way of run.plan.ways) at[way] = 1 / run.plan.ways.length;
  const roads = ROADS.map(() => 0);
  for (const node of FLOW_ORDER) {
    const odds = oddsAt(run, node, 1);
    OUT[node].forEach((r, i) => { roads[r] = at[node] * odds[i]; at[ROADS[r].to] += roads[r]; });
  }
  return roads;
}

function busiest(run, list, type) {
  const roads = traffic(run);
  const score = (s) => s.reach[type].reduce((sum, r) => sum + (ROADS[r].fixed ? 0 : roads[r]), 0);
  return free(run, list).sort((a, b) => score(b) - score(a))[0];
}

function count(run, type) { return Object.values(run.built).filter((d) => d.type === type).length; }

const PLAYERS = {
  // Builds nothing.
  idle() {},
  // Buys whatever it can afford, anywhere.
  careless(run) {
    for (let tries = 0; tries < 16; tries++) {
      const type = Object.keys(DEFENCES)[Math.floor(run.rng() * 4)];
      const list = DEFENCES[type].spot === 'pad' ? PADS : MARKS;
      place(run, type, list[Math.floor(run.rng() * list.length)].id);
    }
  },
  // A first-timer who has learned the basics: towers where the herd walks,
  // the odd mortar, spare money on pits, never a fence.
  sensible(run) {
    for (;;) {
      const type = count(run, 'tower') >= (count(run, 'mortar') + 1) * 4 ? 'mortar' : 'tower';
      const pad = busiest(run, PADS, type);
      if (pad && !place(run, type, pad.id)) continue;
      const mark = busiest(run, MARKS, 'pit');
      if (mark && run.money < DEFENCES.tower.cost && !place(run, 'pit', mark.id)) continue;
      return;
    }
  },
  // Steers: fences the two outer roads so every herd funnels through the middle, then guns the hub.
  steerer(run) {
    const hub = [4, 7, 8, 10, 11, 12];
    const worth = (s, type) => s.reach[type].filter((r) => hub.includes(r)).length;
    for (;;) {
      if (count(run, 'tower') >= 2) {
        for (const s of free(run, MARKS)) if (s.road === 6 || s.road === 9) place(run, 'fence', s.id);
      }
      const type = count(run, 'tower') >= (count(run, 'mortar') + 1) * 4 ? 'mortar' : 'tower';
      const pad = free(run, PADS).sort((a, b) => worth(b, type) - worth(a, type))[0];
      if (pad && !place(run, type, pad.id)) continue;
      const mark = free(run, MARKS).find((s) => hub.includes(s.road));
      if (mark && run.money < DEFENCES.tower.cost && !place(run, 'pit', mark.id)) continue;
      return;
    }
  },
};

function play(seed, player) {
  const run = newRun(seed);
  for (;;) {
    player(run);
    startNight(run);
    while (!run.night.done) stepNight(run, 1 / 30);
    if (run.over) break;
    nextSeason(run);
  }
  return { won: run.over === 'won', town: run.town, season: run.season };
}

const RUNS = Number(process.env.RUNS || 1000);

function report() {
  const parts = [];
  for (const name of Object.keys(PLAYERS)) {
    let wins = 0, town = 0, season = 0;
    for (let seed = 1; seed <= RUNS; seed++) {
      const r = play(seed, PLAYERS[name]);
      wins += r.won ? 1 : 0;
      town += r.won ? r.town : 0;
      season += r.season;
    }
    parts.push(`${name} ${(wins / RUNS * 100).toFixed(0)}%` + (wins ? ` (town ${(town / wins).toFixed(0)})` : ` (falls season ${(season / RUNS).toFixed(1)})`));
  }
  return parts.join('  ');
}

if (process.env.SWEEP) {
  const base = { ...TUNE }, towerScare = DEFENCES.tower.scare, mortarScare = DEFENCES.mortar.scare, fenceScare = DEFENCES.fence.scare;
  for (const set of JSON.parse(process.env.SWEEP)) {
    Object.assign(TUNE, base, set);
    DEFENCES.tower.scare = set.towerScare ?? towerScare;
    DEFENCES.mortar.scare = set.mortarScare ?? mortarScare;
    DEFENCES.fence.scare = set.fenceScare ?? fenceScare;
    console.log(JSON.stringify(set), report());
  }
} else {
  console.log(report());
  console.log('pads reach', PADS.map((s) => s.reach.tower.length).join(' '));
}
