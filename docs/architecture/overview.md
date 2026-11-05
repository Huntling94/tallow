# Architecture overview

> Living document. Updated whenever an ADR or a milestone changes the shape of the system.
>
> **Status: design.** This page describes the target architecture. As of M0 step 6, the Godot project exists with its lint and test setup; the containers and components below are built from step 7 onwards (see the [roadmap](../milestones/roadmap.md)). Elements marked *planned* come after the vertical slice.

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

**Notation used in every diagram.** Each box shows its name, its type in square brackets with the technology, and a one-line responsibility. The C4 types are person, software system, container, component and data store; the deployment and data-flow views also use device, CI job, CI test and check result. Arrows are labelled with what flows and, where it matters, how. Dashed boxes and outlines are external to Tallow; dashed arrows are planned links. The same element keeps the same name in every view.

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

    player -- "plays in a browser or on desktop" --> tallow
    maintainer -- "directs and approves work in" --> claude
    claude -- "reads and writes code and docs for" --> tallow
    maintainer -- "reviews, plays and merges" --> tallow
    tallow -- "is built, tested and hosted by" --> github
    tallow -. "publishes desktop builds to (planned)" .-> itch

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
    player["<b>Player</b><br/>[Person]<br/>Plays runs in a browser or on desktop"]
    maintainer["<b>Maintainer</b><br/>[Person]<br/>Starts bot runs and reads the reports"]

    subgraph tallow["Tallow [Software system]"]
        client["<b>Game client</b><br/>[Container: Godot 4, GDScript]<br/>Desktop and web builds; runs the<br/>simulation and shows it in 3D"]
        runner["<b>Headless runner</b><br/>[Container: Godot 4 headless]<br/>Runs thousands of seeded seasons,<br/>played by built-in bot strategies"]
        data[("<b>Game data</b><br/>[Data store: versioned JSON]<br/>Balance tables, true parameters,<br/>fitted coefficients")]
        telemetry[("<b>Telemetry</b><br/>[Data store: JSON Lines files]<br/>One file per run")]
        analysis["<b>Analysis</b><br/>[Container: Python, uv]<br/>Validates telemetry, fits and<br/>calibrates models"]
        tables[("<b>Analysis tables</b><br/>[Data store: Parquet]<br/>Typed, compressed run data")]
        reports[("<b>Reports</b><br/>[Data store: Markdown, plots]<br/>Model cards, calibration reports")]
    end

    player -- "plays" --> client
    maintainer -- "starts bot runs (command line, CI)" --> runner
    maintainer -- "reads" --> reports
    client -- "loads at start" --> data
    runner -- "loads at start" --> data
    runner -- "writes events (JSON Lines)" --> telemetry
    client -. "writes events (planned, opt-in)" .-> telemetry
    telemetry -- "validated and converted by" --> analysis
    analysis -- "writes" --> tables
    analysis -- "publishes" --> reports
    analysis -- "writes fitted coefficients to" --> data

    classDef person fill:#08427b,color:#fff,stroke:#052e56
    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef store fill:#438dd5,color:#fff,stroke:#2e6295
    class player,maintainer person
    class client,runner,analysis container
    class data,telemetry,tables,reports store
```

The game client and the headless runner share the same simulation code ([ADR-0002](../adr/0002-sim-render-separation.md)). The telemetry format is set by [ADR-0003](../adr/0003-telemetry-format.md).

## 3. Components: game client

**Shows:** the main building blocks inside the game client and the rule that separates them: the simulation side never depends on the presentation side. **Leaves out:** classes and functions, and the individual game systems' connections to each other. Components firm up during M1.

```mermaid
flowchart TB
    data[("<b>Game data</b><br/>[Data store: versioned JSON]<br/>Balance tables, true parameters,<br/>fitted coefficients")]

    subgraph pres["Presentation (game/src/world, camera, player, ui, viewer)"]
        input["<b>Input and UI</b><br/>[Component: GDScript, Godot UI]<br/>Turns player actions into commands"]
        world["<b>World view</b><br/>[Component: GDScript, Godot 3D]<br/>Draws herds, defences and town;<br/>animates between ticks"]
        camera["<b>Cameras</b><br/>[Component: GDScript, Godot 3D]<br/>Command view and first person"]
    end

    loader["<b>Data loader</b><br/>[Component: GDScript, game/src/data]<br/>Reads game data files and hands them<br/>to the simulation at the start of a run"]

    subgraph sim["Simulation (game/src/sim: pure, seeded, deterministic)"]
        commands["<b>Command queue</b><br/>[Component: GDScript]<br/>Applies commands at tick boundaries"]
        run["<b>Run and seasons</b><br/>[Component: GDScript]<br/>Season phases, win, loss, score"]
        rng["<b>Random streams</b><br/>[Component: GDScript]<br/>One stream per system from the run seed"]
        systems["<b>Game systems</b><br/>[Components: GDScript]<br/>Herd and routes, defence, harvest, economy,<br/>town and garrison, almanac and rare events"]
        events["<b>Event stream</b><br/>[Component: GDScript]<br/>Ordered record of what happened"]
    end

    writer["<b>Telemetry writer</b><br/>[Component: GDScript, game/src/telemetry]<br/>Writes events as JSON Lines"]

    data -- "files" --> loader
    loader -- "parameters and coefficients, as plain data" --> run
    input -- "commands (build, assign crews, sell)" --> commands
    commands -- "validated commands, applied each tick" --> run
    run -- "advances each phase and tick" --> systems
    run -- "run seed" --> rng
    rng -- "seeded random numbers" --> systems
    systems -- "emit events" --> events
    systems -- "read-only state" --> world
    world -- "scene to frame" --> camera
    events -- "events in order" --> writer

    classDef component fill:#85bbf0,color:#000,stroke:#5d82a8
    classDef store fill:#438dd5,color:#fff,stroke:#2e6295
    class input,world,camera,loader,commands,run,rng,systems,events,writer component
    class data store
```

**The dependency rule:** arrows into the simulation carry only commands and plain data. The simulation never loads files itself: the data loader, outside `game/src/sim/`, reads them and passes the values in. Presentation reads simulation state but never changes it, and nothing in `game/src/sim/` refers to presentation.

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
    S-->>T: Events (harvest recovered)
    P->>S: Commands: sell, store, contract
    S-->>T: Events (trade made, price moved)
    P->>S: Commands: spend on defences, harvest capability, town, house and kit
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
        editor["<b>Godot editor and Claude Code</b><br/>[Container host: Godot 4, Claude Code]<br/>Builds and reviews changes"]
        localpy["<b>Analysis</b><br/>[Container: Python, uv]<br/>Local model work"]
    end
    subgraph gha["GitHub Actions [External: Linux runners]"]
        checks["<b>Checks</b><br/>[CI job: Python, Godot headless]<br/>Language guard, review check,<br/>lint, tests, golden seeds"]
        headless["<b>Headless runner</b><br/>[Container: Godot 4 headless]<br/>Seeded bot runs"]
        ci_analysis["<b>Analysis</b><br/>[Container: Python, uv]<br/>Model checks on run telemetry"]
        export["<b>Export</b><br/>[CI job: Godot export templates]<br/>Web and desktop builds"]
    end
    subgraph pages["GitHub Pages [External: static hosting]"]
        web["<b>Game client: web build</b><br/>[Container: Godot Compatibility renderer]<br/>The easy-access version"]
    end
    subgraph releases["GitHub Releases [External: file hosting]"]
        desktop["<b>Game client: desktop builds</b><br/>[Container: Godot export]<br/>Attached to each version tag"]
    end
    browser["<b>Player's browser</b><br/>[Device]<br/>Runs the web build"]
    pc["<b>Player's desktop</b><br/>[Device: Windows, macOS, Linux]<br/>Runs a downloaded build"]

    dev -- "pushes a branch and opens a pull request" --> gha
    headless -- "telemetry files" --> ci_analysis
    export -- "deploys on merge to main" --> web
    export -- "attaches on version tag" --> desktop
    web -- "served over HTTPS" --> browser
    desktop -- "downloaded" --> pc

    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef device fill:#08427b,color:#fff,stroke:#052e56
    class editor,localpy,checks,headless,ci_analysis,export,web,desktop container
    class browser,pc device
    style gha stroke-dasharray:4 3
    style pages stroke-dasharray:4 3
    style releases stroke-dasharray:4 3
```

## 7. The statistical loop

**Shows:** how the project proves its models work. **Leaves out:** the models themselves (see `docs/models/` once they exist). Every telemetry record and field is listed in the [telemetry data dictionary](telemetry.md).

```mermaid
flowchart LR
    truth[("<b>Game data: true parameters</b><br/>[Data store: versioned JSON, game/data]<br/>What the simulation really uses")] -- "loaded into" --> sim["<b>Headless runner</b><br/>[Container: Godot 4 headless]<br/>Bots play many seeds"]
    sim -- "writes" --> tel[("<b>Telemetry</b><br/>[Data store: JSON Lines]<br/>What happened in each run")]
    tel -- "read by" --> fit["<b>Analysis: fit model</b><br/>[Container: Python, uv]<br/>Never sees the true parameters"]
    fit -- "recovered values" --> check{"<b>Recovery test</b><br/>[CI test: Python]<br/>Recovered values match<br/>the truth within tolerance?"}
    truth -- "true values" --> check
    check -- "yes" --> ship[("<b>Published model</b><br/>[Data store: Markdown, JSON]<br/>Model card, calibration report,<br/>coefficients for the game")]
    check -- "no" --> fail["<b>CI fails</b><br/>[Check result]<br/>The pull request cannot merge"]

    classDef container fill:#438dd5,color:#fff,stroke:#2e6295
    classDef store fill:#438dd5,color:#fff,stroke:#2e6295
    classDef test fill:#85bbf0,color:#000,stroke:#5d82a8
    class sim,fit container
    class truth,tel,ship store
    class check,fail test
```

Because the simulation knows the truth, every model in the repository can be checked against it.

## Layers at a glance

| Layer | Where | Does | Never does |
|---|---|---|---|
| Simulation | `game/src/sim/` | Owns every game rule and all game state. Advances in fixed ticks from commands and a seed. Emits events. | Touch scenes, nodes, rendering, input, files or the wall clock. Use unseeded randomness. |
| Presentation | `game/src/world/`, `camera/`, `player/`, `ui/`, `viewer/` | Shows simulation state in 3D, animates between ticks, turns player input into commands. | Change simulation state directly. |
| Headless runner | `game/tools/` | Runs seeded seasons with bots and no window. | Contain rules of its own. |
| Data loader | `game/src/data/` | Reads game data files and passes the values to the simulation at the start of a run. | Hold or change game state. |
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
  src/viewer/            top-down 2D replay of a season
  src/telemetry/         telemetry writer
  src/data/              data loader: reads game/data/ and passes values to the simulation
  scenes/                Godot scenes
  assets/                models, textures, audio, fonts (each listed in CREDITS.md)
  data/                  balance tables and fitted coefficients (versioned JSON)
  tools/                 headless runner
  tests/                 gdUnit4: unit/, invariants/, golden/, plus support/ helpers and fixtures/
analysis/                Python, managed with uv
  src/tallow_analysis/   telemetry (loading and checks), later features, models, calibration, reports
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
