# Game data

Balance tables and fitted coefficients as versioned JSON, read by the data loader and passed to the simulation. Every file here counts towards the rules version in each telemetry file (ADR-0003), so a change to any of them marks runs as coming from different rules.

| Folder | What it holds | Read by |
|---|---|---|
| `valleys/` | One route graph per valley: points, segments (length in metres, roughness from 0 to 1) and named routes as segment lists from the entry to the gate (spec 0037) | `GameData.load_valley` |
| `herds/` | One herd personality per file: route-choice weights and herd and band sizes (spec 0037) | `GameData.load_herd` |
| `defences.json` | Fence, pit and harpoon tower: cost, threat, kill chance in parts per million, and capacity per night (spec 0040) | `GameData.load_defences` |
| `run_rules.json` | Starting money, the season levy, breach cost per beast, beast speed and band spacing (spec 0040) | `GameData.load_run_rules` |
| `plans/` | Scripted commands by season for the headless runner's `--plan` option (spec 0040) | `GameData.load_plan` |

The numbers in these files are placeholders until the balance work in M1 step 6.
