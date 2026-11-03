# Architecture overview

> Living document. Updated whenever an ADR or a milestone changes the shape of the system. Components marked *planned* do not exist yet.

Tallow has one authoritative simulation, a 3D presentation that shows it, and a Python analysis layer that learns from it. Fitted models flow back into the game as data, never as code.

This page follows the [C4 model](https://c4model.com/) ([ADR-0004](../adr/0004-architecture-documentation-c4.md)): each level zooms in on the one above.

| View | Question it answers | Section |
|---|---|---|
| Level 1: System context | Who uses Tallow, and what does it depend on? | [1](#1-system-context) |
| Level 2: Containers | What are the separately runnable parts and data stores, and how do they talk? | [2](#2-containers) |
| Level 3: Components | What are the main building blocks inside the game? | [3](#3-components-game-client) |
| Level 4: Code | How is a component implemented? | Not drawn; the code is the source of truth |
| Dynamic | What happens, in what order, during one season? | [4](#4-dynamic-view-one-season) |
| State | What phases does a run move through? | [5](#5-state-view-the-run) |
| Deployment | Where does each container run? | [6](#6-deployment-view) |
| Data flow | How does telemetry become a model the game uses? | [7](#7-the-statistical-loop) |

**Notation used in every diagram.** Each box shows its name, its type in square brackets (person, software system, container, component) with the technology, and a one-line responsibility. Arrows are labelled with what flows and, where it matters, how. Dashed boxes are external to Tallow.

## 1. System context

**Shows:** Tallow as one box, the people who use it and the outside systems it relies on. **Leaves out:** everything inside Tallow.

```mermaid
flowchart TB
    player["<b>Player</b><br/>[Person]<br/>Plays runs in a browser or on desktop"]
    maintainer["<b>Maintainer</b><br/>[Person]<br/>Directs the design, approves every change"]

    tallow["<b>Tallow</b><br/>[Software system]<br/>3D strategy game with a seeded simulation<br/>and a statistical analysis pipeline"]

    claude["<b>Claude Code</b><br/>[External system]<br/>AI assistant that drafts specs, code,<br/>tests and reviews"]
    github["<b>GitHub</b><br/>[External system]<br/>Source, issues, CI (Actions),<br/>web hosting (Pages), releases"]
    itch["<b>itch.io</b><br/>[External system, planned]<br/>Desktop downloads"]

    player -- "plays the web build" --> github
    player -- "downloads desktop builds" --> itch
    maintainer -- "directs and approves work in" --> claude
    claude -- "reads and writes code and docs for" --> tallow
    maintainer -- "reviews, plays and merges" --> tallow
    tallow -- "is built, tested and published by" --> github

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef system fill:#1168bd,color:#fff,stroke:#0b4884
    classDef external fill:#999,color:#fff,stroke:#6b6b6b,stroke-dasharray:4 3
    class player,maintainer person
    class tallow system
    class claude,github,itch external
```

## 2. Containers

**Shows:** the separately runnable applications and data stores inside Tallow, their technology, and how data moves between them. **Leaves out:** the internals of each container.

```mermaid
flowchart TB
    player["<b>Player</b><br/>[Person]"]
    bots["<b>Bot strategies</b><br/>[Component of the runner]<br/>Greedy, turtle, random"]

    subgraph tallow["Tallow [Software system]"]
        client["<b>Game client</b><br/>[Container: Godot 4, GDScript]<br/>Desktop and web builds; runs the<br/>simulation and shows it in 3D"]
        runner["<b>Headless runner</b><br/>[Container: Godot 4 headless]<br/>Runs thousands of seeded seasons<br/>with bots, no window"]
        data[("<b>Game data</b><br/>[Data store: versioned JSON]<br/>Balance tables, true parameters,<br/>fitted coefficients")]
        telemetry[("<b>Telemetry</b><br/>[Data store: JSON Lines files]<br/>One file per run")]
        analysis["<b>Analysis</b><br/>[Container: Python, uv]<br/>Validates telemetry, fits and<br/>calibrates models"]
        tables[("<b>Analysis tables</b><br/>[Data store: Parquet]<br/>Typed, compressed run data")]
        reports[("<b>Reports</b><br/>[Data store: Markdown, plots]<br/>Model cards, calibration reports")]
    end

    player -- "plays" --> client
    bots -- "send commands to" --> runner
    client -- "reads" --> data
    runner -- "reads" --> data
    runner -- "writes events (JSON Lines)" --> telemetry
    client -. "writes events (planned, opt-in)" .-> telemetry
    telemetry -- "validated and converted by" --> analysis
    analysis -- "writes" --> tables
    analysis -- "publishes" --> reports
    analysis -- "writes fitted coefficients to" --> data

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef store fill:#438dd5,color:#fff,stroke:#2e6295
    class player person
    class client,runner,analysis,bots container
    class data,telemetry,tables,reports store
```

The game client and the headless runner share the same simulation code ([ADR-0002](../adr/0002-sim-render-separation.md)). The telemetry format is set by [ADR-0003](../adr/0003-telemetry-format.md).

## 3. Components: game client

**Shows:** the main building blocks inside the game client and the rule that separates them: the simulation side never depends on the presentation side. **Leaves out:** classes and functions. Components are *planned* and will firm up during M1.

```mermaid
flowchart TB
    subgraph pres["Presentation [src/world, camera, player, ui]"]
        input["<b>Input and UI</b><br/>[Component]<br/>Turns player actions into commands"]
        world["<b>World view</b><br/>[Component]<br/>Draws herds, defences and town;<br/>animates between ticks"]
        camera["<b>Cameras</b><br/>[Component]<br/>Command view and first person"]
    end

    subgraph sim["Simulation [src/sim: pure, seeded, deterministic]"]
        commands["<b>Command queue</b><br/>[Component]<br/>Applies commands at tick boundaries"]
        run["<b>Run and seasons</b><br/>[Component]<br/>Season phases, win, loss, score"]
        rng["<b>Random streams</b><br/>[Component]<br/>One stream per system from the run seed"]
        herd["<b>Herd and routes</b><br/>[Component]<br/>Beasts, route choice, movement"]
        defence["<b>Defence</b><br/>[Component]<br/>Fences, pits, towers, walls"]
        harvest["<b>Harvest</b><br/>[Component]<br/>Crews, yield, spoilage"]
        economy["<b>Economy</b><br/>[Component]<br/>Exchange, prices, storage, contracts"]
        town["<b>Town and garrison</b><br/>[Component]<br/>Buildings, workers, districts, Lamphouse"]
        almanac["<b>Almanac and rare events</b><br/>[Component]<br/>Forecasts, rare-event odds and arrivals"]
        events["<b>Event stream</b><br/>[Component]<br/>Ordered record of what happened"]
    end

    writer["<b>Telemetry writer</b><br/>[Component: src/telemetry]<br/>Writes events as JSON Lines"]
    data[("Game data<br/>[Data store]")]

    input -- "commands" --> commands
    commands --> run
    run --> herd & defence & harvest & economy & town & almanac
    rng -. "random numbers" .-> herd & harvest & economy & almanac
    herd & defence & harvest & economy & town & almanac -- "emit" --> events
    sim -- "read-only state" --> world
    world --> camera
    events --> writer
    data -- "parameters and coefficients" --> sim
```

**The dependency rule:** arrows into the simulation carry only commands and data. Presentation reads simulation state but never changes it, and nothing in `src/sim/` refers to presentation.

## 4. Dynamic view: one season

**Shows:** the order of interactions during one season. **Leaves out:** the detail of each rule.

```mermaid
sequenceDiagram
    participant P as Player or bot
    participant S as Simulation
    participant V as Presentation
    participant T as Telemetry writer

    S->>V: Forecast (almanac, rare-event odds)
    P->>S: Commands: build defences, fund harvest capability
    loop Each tick of migration night
        S->>S: Herd chooses routes, moves, meets defences
        S-->>V: State for this tick
        S-->>T: Events (route chosen, beast killed, breach)
    end
    P->>S: Commands: assign harvest crews
    S->>S: Harvest: crews recover what they can before spoilage
    P->>S: Commands: sell, store, contract
    S-->>T: Season summary
```

## 5. State view: the run

**Shows:** the phases a run moves through and what ends it. **Leaves out:** what happens inside each phase.

```mermaid
stateDiagram-v2
    [*] --> Forecast: new run (seed, valley, personality, modifier)
    Forecast --> Prepare
    Prepare --> MigrationNight
    MigrationNight --> Harvest: Lamphouse stands
    MigrationNight --> Lost: Lamphouse falls
    Harvest --> Trade
    Trade --> Spend
    Spend --> Forecast: seasons left
    Spend --> Won: season 12 complete
    Won --> [*]
    Lost --> [*]
```

## 6. Deployment view

**Shows:** where each container runs and how builds reach players. **Leaves out:** CI job detail.

```mermaid
flowchart LR
    subgraph dev["Maintainer's machine [Windows]"]
        editor["Godot editor<br/>+ Claude Code"]
        localpy["Python (uv)"]
    end
    subgraph gha["GitHub Actions [Linux runners]"]
        checks["Checks: language guard, review check,<br/>lint, tests, golden seeds"]
        headless["Headless runner<br/>[Godot headless]"]
        ci_analysis["Analysis<br/>[Python]"]
        export["Web and desktop export"]
    end
    subgraph pages["GitHub Pages"]
        web["Web build<br/>[Godot Compatibility renderer]"]
    end
    subgraph releases["GitHub Releases"]
        desktop["Desktop builds"]
    end
    browser["Player's browser"]
    pc["Player's desktop"]

    dev -- "pull request" --> gha
    headless -- "telemetry" --> ci_analysis
    export -- "on merge to main" --> web
    export -- "on version tag" --> desktop
    web --> browser
    desktop --> pc
```

## 7. The statistical loop

**Shows:** how the project proves its models work. **Leaves out:** the models themselves (see `docs/models/` once they exist).

```mermaid
flowchart LR
    truth["True parameters<br/>(game/data)"] --> sim["Simulation<br/>(bots, many seeds)"]
    sim --> tel["Telemetry"]
    tel --> fit["Fit model<br/>(blind to the truth)"]
    fit --> check{"Recovered values<br/>match the truth<br/>within tolerance?"}
    truth --> check
    check -- "yes" --> ship["Model card, calibration report,<br/>coefficients shipped as JSON"]
    check -- "no" --> fail["CI fails"]
```

Because the simulation knows the truth, every model in the repository can be checked against it.

## Layers at a glance

| Layer | Where | Does | Never does |
|---|---|---|---|
| Simulation | `game/src/sim/` | Owns every game rule and all game state. Advances in fixed ticks from commands and a seed. Emits events. | Touch scenes, nodes, rendering, input, files or the wall clock. Use unseeded randomness. |
| Presentation | `game/src/world/`, `camera/`, `player/`, `ui/` | Shows simulation state in 3D, animates between ticks, turns player input into commands. | Change simulation state directly. |
| Headless runner | `game/tools/` | Runs seeded seasons with bots and no window. | Contain rules of its own. |
| Telemetry writer | `game/src/telemetry/` | Turns simulation events into JSON Lines files. | Decide what happens in the game. |
| Data | `game/data/` | Balance tables and fitted coefficients, versioned. | Contain logic. |
| Analysis | `analysis/` | Validates telemetry, fits and calibrates models, writes reports and coefficients. | Re-implement game rules. |

## Folder layout

```text
game/                    Godot 4 project
  src/sim/               simulation: herd, routes, defence, harvest, economy, town, run, events
  src/world/             3D presentation of simulation state
  src/camera/            command view and first person
  src/player/            first-person controller and harpoon
  src/ui/                menus, HUD and theme
  src/telemetry/         telemetry writer
  scenes/                Godot scenes
  assets/                models, textures, audio, fonts (each listed in CREDITS.md)
  data/                  balance tables and fitted coefficients (versioned JSON)
  tools/                 headless runner
  tests/                 gdUnit4: unit/, invariants/, golden/
analysis/                Python, managed with uv
  src/tallow_analysis/   io, features, models, calibration, reports
  tests/
  notebooks/             exploratory only; outputs stripped
  fixtures/              small sample telemetry
telemetry/               local run output (git-ignored)
```

Folders are created as each part lands during M0.

## Keeping this page true

- A PR that adds or removes a container, a component or a dependency between them updates the matching diagram in the same PR. The reviewer checks this.
- Diagrams are Mermaid in Markdown, so they are reviewed and diffed like code.
- If a diagram and the code disagree, the code wins and the diagram is fixed.
