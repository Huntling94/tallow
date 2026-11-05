// Plays the prototype's rules with simple players, to set the numbers.
// Run: node prototypes/winnable-run/tune.mjs
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const rules = html.slice(html.indexOf('// RULES-START'), html.indexOf('// RULES-END'));
const api = new Function(`${rules}; return { TUNE, DEFENCES, ROADS, SPOTS, newRun, place, startNight, stepNight, nextSeason, oddsOf };`)();
const { TUNE, DEFENCES, ROADS, SPOTS, newRun, place, startNight, stepNight, nextSeason, oddsOf } = api;

const PADS = SPOTS.filter((s) => s.kind === 'pad');
const MARKS = SPOTS.filter((s) => s.kind === 'road');
const free = (run, list) => list.filter((s) => !run.built[s.id]).sort((a, b) => (b.reach.length - a.reach.length));

// Share of the herd a spot can touch at today's odds.
function traffic(run, spot) {
  const odds = oddsOf(run);
  return spot.reach.reduce((sum, r) => sum + odds[r], 0);
}

function busiest(run, list) {
  return free(run, list).sort((a, b) => traffic(run, b) - traffic(run, a))[0];
}

const PLAYERS = {
  // Builds nothing.
  idle() {},
  // Buys whatever it can afford, anywhere.
  careless(run) {
    for (let tries = 0; tries < 16; tries++) {
      const type = Object.keys(DEFENCES)[Math.floor(run.rng() * 3)];
      const list = DEFENCES[type].spot === 'pad' ? PADS : MARKS;
      const spot = list[Math.floor(run.rng() * list.length)];
      place(run, type, spot.id);
    }
  },
  // A first-timer who has learned the basics: towers where the herd walks,
  // spare money on pits, never a fence.
  sensible(run) {
    for (;;) {
      const pad = busiest(run, PADS);
      if (pad && !place(run, 'tower', pad.id)) continue;
      const mark = busiest(run, MARKS);
      if (mark && !place(run, 'pit', mark.id)) continue;
      return;
    }
  },
  // Steers: fences the outer roads so the herd walks past every tower on the middle road.
  steerer(run) {
    const count = (type) => Object.values(run.built).filter((d) => d.type === type).length;
    for (;;) {
      const fencesWanted = Math.min(Math.ceil(count('tower') * 0.6), 3) * 2;
      if (count('fence') < fencesWanted) {
        const r = count('fence') % 2 ? 2 : 0;
        const s = free(run, MARKS).find((m) => m.road === r);
        if (s && !place(run, 'fence', s.id)) continue;
      }
      const pad = free(run, PADS).find((s) => s.reach.includes(1));
      if (pad && !place(run, 'tower', pad.id)) continue;
      const mark = free(run, MARKS).find((s) => s.road === 1);
      if (mark && !place(run, 'pit', mark.id)) continue;
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
  const base = { ...TUNE }, reload = DEFENCES.tower.reload;
  for (const set of JSON.parse(process.env.SWEEP)) {
    Object.assign(TUNE, base, set);
    DEFENCES.tower.reload = set.reload || reload;
    console.log(JSON.stringify(set), report());
  }
} else {
  console.log(report());
  console.log('road lengths', ROADS.map((r) => r.len.toFixed(0)).join(' '));
  console.log('default odds', oddsOf(newRun(1)).map((o) => o.toFixed(2)).join(' '));
  console.log('pads reach', PADS.map((s) => s.reach.join('')).join(' '));
}
