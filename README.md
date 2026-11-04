# Tallow

An open-source 3D strategy game made in the open, with its full design, architecture and decision history, built with an AI-assisted workflow using Claude Code.

> **Status: pre-production.** We are laying foundations (milestone M0). There is no game to play yet, but the first grey-box shot runs in your browser: [huntling94.github.io/tallow](https://huntling94.github.io/tallow/). It is rebuilt on every change to `main`.

## The game

A lamp-lit boomtown sits on the migration route of colossal beasts. You build defences that steer and stop the herds from a 3D command view, send your townspeople out to harvest what falls, sell what they bring in on the town exchange, and walk your own streets in first person to spend what you have earned. If the herd breaks through, the town and its standing army are the last line. Lose too often and the lamps go out for good.

"Tallow" is the project's codename. The game's final name is still to be decided.

## How it is made

- **Engine:** Godot 4, with typed GDScript.
- **Simulation first:** one seeded, deterministic simulation that runs headless, separate from rendering.
- **Analysis:** Python reads telemetry from headless runs to fit and check the game's statistical models. It never duplicates game rules.
- **Process:** every change after the first commit arrives by pull request, with a written spec, an independent review and passing checks. Decisions are recorded as ADRs (architecture decision records).
- **AI-assisted:** Claude Code drafts specs, plans, code, tests and reviews. A human approves every spec, plan and merge, and each pull request records how AI was used.

Design documents, decision records and process docs will live in [`docs/`](docs/) as they land.

## Licence

Code is released under the [MIT licence](LICENSE). Third-party assets will be listed with their sources and licences in `CREDITS.md`.
