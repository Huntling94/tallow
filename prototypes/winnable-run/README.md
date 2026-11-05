# Prototype: a winnable run

Issue #58. Throwaway, and never promoted: anything kept is rebuilt through the full loop. It shares no code with `game/`.

A small 3D tower defence. Open `index.html` in a browser that supports WebGL2. It is one file with no libraries.

- **Goal:** hold the town through five seasons. A beast at the gate costs town: 1 for most, 2 for an ironhide, 5 for the Old Bull in the last season.
- **Entrances:** herds come from the west, north or south, and from more of them as seasons pass. The top bar and a marker on the map warn you where the next one starts, and what is in it.
- **Roads:** a network with forks. At every fork a beast weighs the whole way to the town. Longer and scarier roads put it off. Rocks line the north cutting, for looks only, and the shallows in the south slow beasts down.
- **Building:** click a ring for a menu, or pick a card and click rings. Rings beside roads take towers and mortars, and pale rings on hills add range. Rings on roads take pits and fences. Click something built to sell it: full price if it was built since the last herd, half otherwise. You can build during a herd.
- **Beasts:** runners are fast and ignore fences. Ironhides are slow, tough and too heavy for pits, and so is the Old Bull.
- **Steering:** fences scare a lot, towers and mortars a little, pits not at all. The odds are never shown: you read them from where the herd walks, and from the bright tracks it leaves.
- **Keys:** 1 to 4 pick a card. Space releases the herd or pauses. Escape cancels.

`tune.mjs` plays the rules with simple players, to set the numbers. It reads them from between `// RULES-START` and `// RULES-END`, and the 3D view sits outside that block.

```bash
node prototypes/winnable-run/tune.mjs
```

Win rates over 2,000 runs: building nothing 0%, careless 9%, sensible (guns where the herd walks, no fences) 84%, funnelling with fences 93%.
