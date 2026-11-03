# Documentation

Everything about how Tallow is designed, built and decided lives here, reviewed in pull requests like the code.

| Folder | What it holds | Living or fixed |
|---|---|---|
| [`vision/`](vision/) | Concept, pillars and non-goals | Fixed after greenlight; non-goals living |
| [`design/`](design/) | Game design document (GDD), run structure, balance targets, one page per system | Living |
| [`architecture/`](architecture/) | Overview; later a simulation page, the telemetry data dictionary and the testing strategy | Living |
| [`adr/`](adr/) | Architecture decision records: one per significant decision | Fixed; superseded, never edited |
| [`specs/`](specs/) | One spec per feature, numbered to match its issue | Fixed once approved |
| `models/` | One model card per statistical model, with calibration reports | Versioned |
| `prototypes/` | Prototype reports and the greenlight record | Fixed |
| `playtests/` | Playtest plans and reports | Fixed |
| [`milestones/`](milestones/) | Roadmap, risk register, one review per milestone | Living (reviews fixed) |
| [`devlog/`](devlog/) | The story of the build, including where AI got things wrong and what caught it | Append-only |
| [`process/`](process/) | How we work: workflow, definitions of ready and done, coding standards, AI collaboration | Living |

Folders without a link do not exist yet; they appear as their first document lands.

## Start here

- New to the project: [`vision/concept.md`](vision/concept.md), then [`milestones/roadmap.md`](milestones/roadmap.md).
- Want to know how it is built: [`process/workflow.md`](process/workflow.md) and [`process/ai-collaboration.md`](process/ai-collaboration.md).
- Want to know why something is the way it is: [`adr/`](adr/).
