// Plays the prototype's rules with simple players, to set the numbers.
// Run: node prototypes/winnable-run/tune.mjs
import { readFileSync } from 'node:fs';

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf8');
const rules = html.slice(html.indexOf('// RULES-START'), html.indexOf('// RULES-END'));
const api = new Function(`${rules}; return { TUNE, DEFENCES, SEGMENTS, ROUTES, newRun, place, startNight, stepNight, nextSeason, score, lightFire, fireable, oddsOf };`)();
const { TUNE, DEFENCES, SEGMENTS, ROUTES, newRun, place, startNight, stepNight, nextSeason, score, lightFire, fireable, oddsOf } = api;

const OPEN = Object.keys(SEGMENTS).filter((s) => !SEGMENTS[s].closed);

function share(run, seg) {
  const odds = oddsOf(ROUTES, run.defences);
  return ROUTES.reduce((sum, r, i) => sum + (r.segs.includes(seg) ? odds[i] : 0), 0);
}

const PLAYERS = {
  // Builds nothing and lights no fires.
  idle: { build() {}, fire: false },
  // Buys whatever it can afford in random places.
  careless: {
    build(run) {
      for (let tries = 0; tries < 12; tries++) {
        const types = Object.keys(DEFENCES);
        place(run, types[Math.floor(run.rng() * 3)], OPEN[Math.floor(run.rng() * OPEN.length)]);
      }
    },
    fire: false,
  },
  // A sensible first-time player: killers on the busiest open ground, no fires.
  sensible: {
    build(run) {
      for (;;) {
        const free = OPEN.filter((s) => !run.defences[s]).sort((a, b) => share(run, b) - share(run, a));
        if (!free.length) return;
        const type = run.money >= 120 && Object.values(run.defences).filter((d) => d === 'tower').length < 2 ? 'tower' : 'pit';
        if (place(run, type, free[0])) return;
      }
    },
    fire: false,
  },
  // The same, and it turns bands away from empty ground during the night.
  skilled: {
    build(run) { PLAYERS.sensible.build(run); },
    fire: true,
  },
};

// Kills still available along a route from a point on it.
function killsAhead(run, route, from) {
  const n = run.night;
  let total = 0;
  for (const seg of route.segs.slice(from)) total += n.capacity[seg] || 0;
  return total;
}

// Near a junction, burn the way ahead if another way has more kills left.
function fires(run) {
  const n = run.night;
  for (const band of n.bands) {
    if (band.gone || n.time < band.starts || n.firesLeft <= 0) continue;
    const route = ROUTES[band.route];
    const next = route.segs[band.at + 1];
    if (!next || !fireable(next)) continue;
    if (band.metres < SEGMENTS[route.segs[band.at]].len * 0.5) continue;
    const walked = route.segs.slice(0, band.at + 1);
    const here = killsAhead(run, route, band.at + 1);
    const best = Math.max(0, ...ROUTES.filter((r) => walked.every((s, i) => r.segs[i] === s) && r.segs[band.at + 1] !== next).map((r) => killsAhead(run, r, band.at + 1)));
    if (best >= here + 2) lightFire(run, next);
  }
}

function play(seed, player) {
  const run = newRun(seed);
  const money = [];
  for (;;) {
    player.build(run);
    money.push(run.money);
    startNight(run);
    while (!run.night.done) {
      if (player.fire) fires(run);
      stepNight(run, 0.05);
    }
    if (run.over) break;
    nextSeason(run);
  }
  return { won: run.over === 'won', town: run.town, score: score(run), season: run.season, money };
}

const RUNS = Number(process.env.RUNS || 2000);

function report() {
  const parts = [];
  for (const name of Object.keys(PLAYERS)) {
    let wins = 0, town = 0;
    for (let seed = 1; seed <= RUNS; seed++) {
      const r = play(seed, PLAYERS[name]);
      wins += r.won ? 1 : 0;
      town += r.won ? r.town : 0;
    }
    parts.push(`${name} ${(wins / RUNS * 100).toFixed(0)}%` + (wins ? ` (town ${(town / wins).toFixed(0)})` : ''));
  }
  return parts.join('  ');
}

if (process.env.SWEEP) {
  for (const [town, herds, cap] of [[60, [10, 13, 16, 19, 22], 2], [55, [10, 13, 16, 19, 22], 2], [60, [11, 14, 17, 20, 23], 2], [60, [11, 14, 17, 20, 23], 3], [55, [11, 14, 17, 20, 23], 3]]) {
    TUNE.town = town; TUNE.herds = herds; DEFENCES.pit.cap = cap;
    console.log(`town ${town} herds ${herds.join(',')} pit ${cap}: ${report()}`);
  }
} else {
  console.log(report());
  console.log('odds', oddsOf(ROUTES, {}).map((o) => o.toFixed(2)).join(' '), 'night seconds about', ((5000 / TUNE.metresPerSecond) + 5 * TUNE.bandSpacing).toFixed(0));
}
