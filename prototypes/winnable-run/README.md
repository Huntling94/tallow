# Prototype: a winnable run

Issue #58. Throwaway, and never promoted: anything kept is rebuilt through the full loop. It shares no code with `game/`.

A small 3D tower defence. Open `index.html` in a browser that supports WebGL2. It is one file with no libraries.

- **Goal:** hold the town through five seasons. Each beast that reaches the gate costs 1 town; the Old Bull in the last season costs 5.
- **Building:** towers go on rings beside a road. Pits and fences go on rings on the road. You can build during a herd, and take back anything built since the last herd.
- **Steering:** at the fork each beast picks a road. Longer roads and scarier roads put it off. Fences scare a lot, towers a little, pits not at all. The odds are never shown: you read them from where the herd walks, and from the bright tracks it leaves.
- **Keys:** 1, 2, 3 pick a tool. Space releases the herd or pauses.

`tune.mjs` plays the rules with simple players, to set the numbers. It reads them from between `// RULES-START` and `// RULES-END`, and the 3D view sits outside that block.

```bash
node prototypes/winnable-run/tune.mjs
```

Win rates over 2,000 runs: building nothing 0%, careless 6%, sensible (towers where the herd walks, no fences) 87%, steering with fences 94%.
