# Prototype: a winnable run

Issue #58. Throwaway, and never promoted: anything kept is rebuilt through the full loop. It shares no code with `game/`.

Open `index.html` in a browser. `tune.mjs` plays the rules with simple players, to set the numbers:

```bash
node prototypes/winnable-run/tune.mjs
```

The current numbers give these win rates over 2,000 runs: building nothing 0%, careless 11%, sensible with no fires 75%, skilled with fires 99%.
